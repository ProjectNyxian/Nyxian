/*
 SPDX-License-Identifier: AGPL-3.0-or-later

 Copyright (C) 2025 - 2026 cr4zyengineer

 This file is part of Nyxian.

 Nyxian is free software: you can redistribute it and/or modify
 it under the terms of the GNU Affero General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.

 Nyxian is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 GNU Affero General Public License for more details.

 You should have received a copy of the GNU Affero General Public License
 along with Nyxian. If not, see <https://www.gnu.org/licenses/>.
*/

import Foundation
import UIKit

extension CCDiagnosticType: Codable {}
extension CCDiagnosticLevel: Codable {}

/*
 * Debug "tile" in UI
 *
 */
class DebugItem: Codable {
    let severity: CCDiagnosticLevel
    let message: String     // in case of it being a file it contains the error, in case of it being a message it contains the message it self
    let line: UInt64        // in case of it being a file it contains at what line the error is
    let column: UInt64      // in case of it being a file it contains at what column the error is, this and the previous variable is ignored in case of it being a DebugMessage
    
    init(severity: CCDiagnosticLevel, message: String, line: UInt64, column: UInt64) {
        self.severity = severity
        self.message = message
        self.line = line
        self.column = column
    }
}

/*
 * Content of one thing (i.e file/blah)
 *
 */
class DebugObject: Codable {
    enum DebugObjectType: Codable {
        case DebugFile
        case DebugMessage
    }
    
    let title: String       // in case of it being a file it contains the last path component, in case of it being a message it contains "Internal"
    let type: DebugObject.DebugObjectType
    var debugItems: [DebugItem] = []
    
    init(title: String, type: DebugObject.DebugObjectType) {
        self.title = title
        self.type = type
    }
}

/*
 * Content of debug file (i.e `debug.json`)
 *
 */
class DebugDatabase: Codable {
    var debugObjects: [String:DebugObject] = [:]
    let lock = NSLock()
    
    enum CodingKeys: String, CodingKey {
        case debugObjects
    }
    
    /*
     * Function that gets the database of a filepath
     */
    static func getDatabase(ofPath path: String) -> DebugDatabase {
        do {
            let data = try Data(contentsOf: URL(fileURLWithPath: path))
            let decoder = JSONDecoder()
            let blob = try decoder.decode(DebugDatabase.self, from: data)
            return blob
        } catch {
            print("Failed to decode certblob:", error)
            // MARK: If it doesnt exist we create one
            let debugDatabase: DebugDatabase = DebugDatabase()
            
            debugDatabase.debugObjects["Internal"] = DebugObject(title: "Internal", type: .DebugMessage)
            
            // First object is reserved for internal
            return debugDatabase
        }
    }
    
    /*
     * Function that saves the database to a filepath
     */
    func saveDatabase(toPath path: String) {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            if let jsonData = try? encoder.encode(self) {
                try jsonData.write(to: URL(fileURLWithPath: path))
            }
        } catch {
            // TODO: Handle error
        }
    }
    
    /*
     * Functions to manage object entries
     */
    func addInternalMessage(message: String, severity: CCDiagnosticLevel) {
        self.lock.lock()
        guard let internalObject = self.debugObjects["Internal"] else {
            self.lock.unlock()
            return
        }
        internalObject.debugItems.append(DebugItem(severity: severity, message: message, line: 0, column: 0))
        self.lock.unlock()
    }
    
    func setFileDebug(ofPath path: String, synItems: [Syndiag]) {
        guard let relPath: String = Bootstrap.shared.relativeToBootstrapSafe(path) else {
            return
        }
        
        self.lock.lock()
        let fileObject: DebugObject = DebugObject(title: relPath, type: .DebugFile)
        
        for item in synItems {
            let debugItem: DebugItem = DebugItem(severity: item.level, message: item.message, line: item.line, column: item.column)
            fileObject.debugItems.append(debugItem)
        }
        
        self.debugObjects[relPath] = (synItems.count > 0) ? fileObject : nil
        self.lock.unlock()
    }
    
    func getFileDebug(ofPath path: String) -> [Syndiag] {
        var synItems: [Syndiag] = []
        
        guard let relPath: String = Bootstrap.shared.relativeToBootstrapSafe(path) else {
            return synItems
        }
        
        self.lock.lock()
        guard let fileObject: DebugObject = self.debugObjects[relPath] else {
            self.lock.unlock()
            return []
        }
        
        for item in fileObject.debugItems {
            let synItem: Syndiag = Syndiag()
            synItem.level = item.severity
            synItem.type = .file
            synItem.message = item.message
            synItem.line = item.line
            synItem.column = item.column
            synItems.append(synItem)
        }
        self.lock.unlock()
        
        return synItems
    }
    
    func removeFileDebug(ofPath path: String) {
        let lastPathComponent: String = URL(fileURLWithPath: path).lastPathComponent
        self.debugObjects[lastPathComponent] = nil
    }
    
    func clearDatabase() {
        self.debugObjects = [:]
        self.debugObjects["Internal"] = DebugObject(title: "Internal", type: .DebugMessage)
    }
    
    func reuseDatabase() {
        self.debugObjects["Internal"] = DebugObject(title: "Internal", type: .DebugMessage)
    }
}

/*
 * Debug UI: Issue Navigator and Database at the same time that will be shared over the entire project :3
 *
 */
class UIDebugViewController: UITableViewController {
    let file: String
    var project: NXProject
    var debugDatabase: DebugDatabase
    
    var sortedDebugObjects: [DebugObject] = []
    
    init(project: NXProject) {
        self.project = project
        self.file = "\(project.cachePath!)/debug.json"
        self.debugDatabase = DebugDatabase.getDatabase(ofPath: self.file)
        super.init(style: .insetGrouped)
        self.reloadTableData()
        NotificationCenter.default.addObserver(self, selector: #selector(refreshDebugDatabase), name: Notification.Name("CodeEditorDismissed"), object: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.title = "Issue Navigator"
        
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 60
        
        let testButton: UIBarButtonItem = UIBarButtonItem(image: UIImage(systemName: "trash.fill"), style: .plain, target: self, action: #selector(clearDatabase))
        testButton.tintColor = UIColor.systemRed
        self.navigationItem.rightBarButtonItem = testButton
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        let count = sortedDebugObjects[section].debugItems.count
        return (count > 0) ? count : 1
    }
    
    override func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        var title: String = sortedDebugObjects[section].title
        if section > 0 {
            title = (sortedDebugObjects[section].title as NSString).lastPathComponent
        }
        
        let headerView = UIView()
        headerView.backgroundColor = .clear

        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = "\(title) • \(sortedDebugObjects[section].debugItems.count)"
        label.font = UIFont.preferredFont(forTextStyle: .footnote)
        label.textColor = .label
        label.numberOfLines = 1

        headerView.addSubview(label)

        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: 16),
            label.trailingAnchor.constraint(equalTo: headerView.trailingAnchor, constant: -16),
            label.topAnchor.constraint(equalTo: headerView.topAnchor, constant: 8),
            label.bottomAnchor.constraint(equalTo: headerView.bottomAnchor, constant: -4)
        ])

        return headerView
    }

    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return UITableView.automaticDimension
    }
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return sortedDebugObjects.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let items = sortedDebugObjects[indexPath.section].debugItems
        let item = (items.count > 0) ? items[indexPath.row] : DebugItem(severity: .note, message: "Contains no messages", line: 0, column: 0)
        
        let cell = UITableViewCell()
        cell.textLabel?.text = item.message
        cell.textLabel?.numberOfLines = 0;
        cell.textLabel?.font = UIFont.systemFont(ofSize: 14.0, weight: .regular)
        cell.textLabel?.translatesAutoresizingMaskIntoConstraints = false
        
        let tintColor: UIColor = {
            switch item.severity {
            case .warning:
                return UIColor.systemOrange
            case .error:
                return UIColor.systemRed
            default:
                return UIColor.systemBlue
            }
        }()
        
        let symbolName: String = {
            switch item.severity {
            case .warning:
                return "exclamationmark.triangle.fill"
            case .error:
                return "xmark.octagon.fill"
            default:
                return "info.circle.fill"
            }
        }()
        
        cell.contentView.backgroundColor = tintColor.withAlphaComponent(0.6)
        
        // The stripe where we will place the SFSymbol later on
        let stripeView: UIView = UIView()
        stripeView.backgroundColor = tintColor
        stripeView.translatesAutoresizingMaskIntoConstraints = false
        
        // Image View
        let configuration: UIImage.SymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 8.0)
        let image: UIImage? = UIImage(systemName: symbolName, withConfiguration: configuration)
        let imageView: UIImageView = UIImageView(image: image)
        imageView.tintColor = .label
        imageView.translatesAutoresizingMaskIntoConstraints = false
        stripeView.addSubview(imageView)
        
        cell.contentView.addSubview(stripeView)
        
        // Setting the constraints how we wanna layout our views
        NSLayoutConstraint.activate([
            stripeView.topAnchor.constraint(equalTo: cell.contentView.topAnchor),
            stripeView.bottomAnchor.constraint(equalTo: cell.contentView.bottomAnchor),
            stripeView.leadingAnchor.constraint(equalTo: cell.contentView.leadingAnchor),
            stripeView.widthAnchor.constraint(equalToConstant: 20),
            
            cell.textLabel!.centerYAnchor.constraint(equalTo: cell.contentView.centerYAnchor),
            cell.textLabel!.leadingAnchor.constraint(equalTo: stripeView.trailingAnchor, constant: 10),
            cell.textLabel!.trailingAnchor.constraint(equalTo: cell.contentView.trailingAnchor, constant: -10),
            
            cell.contentView.heightAnchor.constraint(equalTo: cell.textLabel!.heightAnchor, constant: 20),
            
            imageView.centerYAnchor.constraint(equalTo: stripeView.centerYAnchor),
            imageView.centerXAnchor.constraint(equalTo: stripeView.centerXAnchor)
        ])
        
        cell.separatorInset = .zero
        cell.layoutMargins = .zero
        cell.preservesSuperviewLayoutMargins = false
        
        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        self.tableView.deselectRow(at: indexPath, animated: true)
        
        guard indexPath.section != 0 else { return }
        
        let object: DebugObject = sortedDebugObjects[indexPath.section]
        let item: DebugItem = object.debugItems[indexPath.row]
        
        let path: String = Bootstrap.shared.bootstrapPath(object.title)
        
        if UIDevice.current.userInterfaceIdiom == .pad {
            NotificationCenter.default.post(name: Notification.Name("FileListAct"), object: ["open",path,"\(item.line)","\(item.column)"])
            self.dismiss(animated: true)
        } else {
            let fileVC = UINavigationController(rootViewController: CodeEditorViewController(
                project: project,
                path: path,
                line: item.line,
                column: item.column
            ))
            fileVC.modalPresentationStyle = .overFullScreen
            self.present(fileVC, animated: true)
        }
    }
    
    @objc func reloadTableData() {
        debugDatabase.lock.lock()
        self.sortedDebugObjects = debugDatabase.debugObjects.values.sorted {
            if $0.title == "Internal" {
                return true
            } else if $1.title == "Internal" {
                return false
            } else {
                return $0.title < $1.title
            }
        }
        debugDatabase.lock.unlock()
        tableView.reloadData()
    }
    
    @objc func clearDatabase() {
        debugDatabase.clearDatabase()
        debugDatabase.saveDatabase(toPath: self.file)
        self.reloadTableData()
    }
    
    @objc func refreshDebugDatabase() {
        self.debugDatabase = DebugDatabase.getDatabase(ofPath: self.file)
        self.reloadTableData()
    }
}
