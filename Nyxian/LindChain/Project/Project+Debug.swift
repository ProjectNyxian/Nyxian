/*
 SPDX-License-Identifier: AGPL-3.0-or-later

 Copyright (C) 2025 - 2026 mach-port-t

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
import MobileDevelopmentKit

class DebugItem: Codable {
    let severity: CCDiagnosticLevel
    let message: String
    
    // TODO: make CCSourceLocation conforming to codable
    private var isValid: Bool = false
    private var line: CFIndex = 0
    private var column: CFIndex = 0
    
    var sourceLocation: CCSourceLocation {
        get {
            return CCSourceLocation(isValid: DarwinBoolean(booleanLiteral: self.isValid), line: self.line, column: self.column)
        }
        set {
            self.isValid = newValue.isValid.boolValue
            self.line = newValue.line
            self.column = newValue.column
        }
    }
    
    init(severity: CCDiagnosticLevel, message: String, sourceLocation: CCSourceLocation = CCSourceLocationZero) {
        self.severity = severity
        self.message = message
        self.sourceLocation = sourceLocation
    }
}

class DebugObject: Codable {
    enum Flavour: Codable {
        case File
        case Message
    }
    
    let title: String
    let flavour: Flavour
    var debugItems: [DebugItem] = []
    
    init(title: String, flavour: Flavour) {
        self.title = title
        self.flavour = flavour
    }
}

class DebugDatabase: Codable {
    var debugObjects: [String:DebugObject] = [:]
    var lock: os_unfair_lock = os_unfair_lock()
    
    enum CodingKeys: String, CodingKey {
        case debugObjects
    }
    
    static func getDatabase(ofPath path: String) -> DebugDatabase {
        do {
            let data = try Data(contentsOf: URL(fileURLWithPath: path))
            let decoder = JSONDecoder()
            let blob = try decoder.decode(DebugDatabase.self, from: data)
            return blob
        } catch {
            print("Failed to decode certblob:", error)
            let debugDatabase: DebugDatabase = DebugDatabase()
            debugDatabase.debugObjects["Internal"] = DebugObject(title: "Internal", flavour: .Message)
            return debugDatabase
        }
    }
    
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
    
    func addMessage(message: String, title: String = "Internal", severity: CCDiagnosticLevel) {
        os_unfair_lock_lock(&self.lock)
        let item = DebugItem(severity: severity, message: message)
        
        guard let internalObject = self.debugObjects[title] else {
            let object = DebugObject(title: title, flavour: .Message)
            object.debugItems.append(item)
            self.debugObjects[title] = object
            os_unfair_lock_unlock(&self.lock)
            return
        }
        
        internalObject.debugItems.append(item)
        
        os_unfair_lock_unlock(&self.lock)
    }
    
    func addDiagnosticMessages(title: String = "Internal", items: [MDKDiagnostic], clearPrevious: Bool = false) {
        os_unfair_lock_lock(&self.lock)
        
        if items.count > 0 {
            var debugItems: [DebugItem] = []
            for item in items {
                debugItems.append(DebugItem(severity: item.level, message: item.message, sourceLocation: item.fileSourceLocation?.location ?? CCSourceLocationZero))
            }
            
            guard let internalObject = self.debugObjects[title] else {
                let object = DebugObject(title: title, flavour: .Message)
                object.debugItems.append(contentsOf: debugItems)
                self.debugObjects[title] = object
                os_unfair_lock_unlock(&self.lock)
                return
            }
            
            if clearPrevious {
                internalObject.debugItems.removeAll()
            }
            
            internalObject.debugItems.append(contentsOf: debugItems)
        } else if clearPrevious {
            self.debugObjects.removeValue(forKey: title)
        }
        
        os_unfair_lock_unlock(&self.lock)
    }
    
    func setFileDebug(ofPath path: String, synItems: [MDKDiagnostic]) {
        guard let relPath: String = NXBootstrap.shared().relativeToBootstrap(withAbsolutePath: path) else {
            return
        }
        
        os_unfair_lock_lock(&self.lock)
        let fileObject: DebugObject = DebugObject(title: relPath, flavour: .File)
        
        for item in synItems {
            let debugItem: DebugItem = DebugItem(severity: item.level, message: item.message, sourceLocation: item.fileSourceLocation?.location ?? CCSourceLocationZero)
            fileObject.debugItems.append(debugItem)
        }
        
        self.debugObjects[relPath] = (synItems.count > 0) ? fileObject : nil
        os_unfair_lock_unlock(&self.lock)
    }
    
    func removeFileDebug(ofPath path: String) {
        let lastPathComponent: String = URL(fileURLWithPath: path).lastPathComponent
        self.debugObjects[lastPathComponent] = nil
    }
    
    func clearDatabase() {
        self.debugObjects = [:]
        self.debugObjects["Internal"] = DebugObject(title: "Internal", flavour: .Message)
    }
    
    func reuseDatabase() {
        self.debugObjects["Internal"] = DebugObject(title: "Internal", flavour: .Message)
    }
}

class UIDebugViewController: UITableViewController {
    let file: String
    var project: NXProject
    var debugDatabase: DebugDatabase
    
    var sortedDebugObjects: [DebugObject] = []
    
    init(project: NXProject) {
        self.project = project
        self.file = project.cacheURL.appendingPathComponent("debug.json").path
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
        let item = (items.count > 0) ? items[indexPath.row] : DebugItem(severity: .note, message: "Contains no messages")
        
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
        
        let object: DebugObject = sortedDebugObjects[indexPath.section]
        if object.flavour != .File {
            // It's not a file
            return
        }
        
        let item: DebugItem = object.debugItems[indexPath.row]
        if !item.sourceLocation.isValid.boolValue {
            // It's not a file location
            return
        }
        
        let fileURL: URL = NXBootstrap.shared().rootURL.appendingPathComponent(object.title)
        
        if UIDevice.current.userInterfaceIdiom == .pad {
            NotificationCenter.default.post(name: Notification.Name("FileListAct"), object: ["open",fileURL.path,"\(item.sourceLocation.line)","\(item.sourceLocation.column)"])
            self.dismiss(animated: true)
        } else {
            guard let codeEditor = CodeEditorViewController(
                project: project,
                url: fileURL,
                line: item.sourceLocation.line,
                column: item.sourceLocation.column
            ) else {
                return
            }
            
            let fileVC = UINavigationController(rootViewController: codeEditor)
            fileVC.modalPresentationStyle = .overFullScreen
            self.present(fileVC, animated: true)
        }
    }
    
    @objc func reloadTableData() {
        os_unfair_lock_lock(&debugDatabase.lock)
        self.sortedDebugObjects = debugDatabase.debugObjects.values.sorted {
            if $0.title == "Internal" && $1.title != "Internal" {
                return true
            }
            if $1.title == "Internal" && $0.title != "Internal" {
                return false
            }
            if $0.flavour == .Message && $1.flavour != .Message {
                return true
            }
            if $1.flavour == .Message && $0.flavour != .Message {
                return false
            }
            return $0.title > $1.title
        }
        os_unfair_lock_unlock(&debugDatabase.lock)
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
