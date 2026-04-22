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

@objc class ContentViewController: UIThemedTableViewController, UIDocumentPickerDelegate, UIAdaptivePresentationControllerDelegate {
    var sessionIndex: IndexPath? = nil
    var projectsList: [String:[NXProject]] = [:]
    var path: String
    
    @objc init(path: String) {
        RevertUI()
        self.path = path
        super.init(style: .insetGrouped)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.tableView.register(NXProjectTableCell.self, forCellReuseIdentifier: NXProjectTableCell.reuseIdentifier())
        
        self.title = "Projects"
        
        /* application menu */
        let ObjCApp: UIAction = UIAction(title: "Objc") { [weak self] _ in
            guard let self = self else { return }
            self.createProject(mode: .app, withLanguage: .objC)
        }
        
        let applicationMenu: UIMenu = UIMenu(title: "App", image: UIImage(systemName: "app.gift.fill"), children: [ObjCApp])
        
        /* utility menu */
        let CUtility: UIAction = UIAction(title: "C") { [weak self] _ in
            guard let self = self else { return }
            self.createProject(mode: .utility, withLanguage: .C)
        }
        
        let CPPCUtility: UIAction = UIAction(title: "C++") { [weak self] _ in
            guard let self = self else { return }
            self.createProject(mode: .utility, withLanguage: .cpp)
        }
        
        let ObjCCUtility: UIAction = UIAction(title: "ObjC") { [weak self] _ in
            guard let self = self else { return }
            self.createProject(mode: .utility, withLanguage: .objC)
        }
        
        let utilityMenu: UIMenu = UIMenu(title: "Utility", image: UIImage(systemName: "wrench.adjustable.fill"), children: [CUtility, CPPCUtility, ObjCCUtility])
        
        let createMenu: UIMenu = UIMenu(title: "Create Project", image: UIImage(systemName: "folder.fill"), children: [applicationMenu, utilityMenu])
        
        let importItem: UIAction = UIAction(title: "Import", image: UIImage(systemName: "square.and.arrow.down.fill")) { [weak self] _ in
            guard let self = self else { return }
            let documentPicker = UIDocumentPickerViewController(forOpeningContentTypes: [.zip], asCopy: true)
            documentPicker.delegate = self
            documentPicker.modalPresentationStyle = .formSheet
            self.present(documentPicker, animated: true)
        }
        let menu: UIMenu = UIMenu(children: [createMenu, importItem])
        
        let barbutton: UIBarButtonItem = UIBarButtonItem()
        barbutton.menu = menu
        barbutton.image = UIImage(systemName: "plus")
        self.navigationItem.setRightBarButton(barbutton, animated: false)
        
        self.tableView.register(UITableViewCell.self, forCellReuseIdentifier: "Cell")
        
        let rawProjectsList = NXProject.listProjects(atPath: self.path) as! [String:[NXProject]]
        let filtered = rawProjectsList.filter { !$0.value.isEmpty }

        let sorted = filtered.sorted { a, b in
            let keyA = a.key.lowercased()
            let keyB = b.key.lowercased()
            return sortKeys(keyA, keyB)
        }

        self.projectsList = Dictionary(uniqueKeysWithValues: sorted)
        
        self.tableView.reloadData()
    }
    
    func addProject(_ project: NXProject) {
        let key = {
            switch project.projectConfig.type {
            case .app: return "applications"
            case .utility: return "utilities"
            default: return "unknown"
            }
        }()
        
        let oldSections = projectsList.keys.sorted { sortKeys($0, $1) }
        let oldSectionForKey = oldSections.firstIndex(of: key)
        
        if var list = self.projectsList[key] {
            list.append(project)
            self.projectsList[key] = list
        } else {
            self.projectsList[key] = [project]
        }
        
        let newSections = updateSections()
        let newSectionForKey = newSections.firstIndex(of: key)
        
        tableView.performBatchUpdates({
            if let oldIndex = oldSectionForKey, let newIndex = newSectionForKey {
                if oldIndex != newIndex {
                    tableView.deleteSections(IndexSet(integer: oldIndex), with: .fade)
                    tableView.insertSections(IndexSet(integer: newIndex), with: .fade)
                }
            } else if let newIndex = newSectionForKey {
                tableView.insertSections(IndexSet(integer: newIndex), with: .fade)
            }
            
            if let newIndex = newSectionForKey, let count = self.projectsList[key]?.count {
                let rowIndex = count - 1
                tableView.insertRows(at: [IndexPath(row: rowIndex, section: newIndex)], with: .automatic)
            }
        }, completion: { _ in
            if let newIndex = newSectionForKey {
                self.tableView.reloadSections(IndexSet(integer: newIndex), with: .none)
            }
        })
    }

    func removeProject(_ project: NXProject) {
        project.remove()
        let key = {
            switch project.projectConfig.type {
            case .app: return "applications"
            case .utility: return "utilities"
            default: return "unknown"
            }
        }()
        
        guard var list = self.projectsList[key] else { return }
        
        let oldSections = projectsList.keys.sorted { sortKeys($0, $1) }
        let oldSectionForKey = oldSections.firstIndex(of: key)
        let oldRow = list.firstIndex { $0.url == project.url }
        
        list.removeAll { $0.url == project.url }
        
        if list.isEmpty {
            self.projectsList.removeValue(forKey: key)
        } else {
            self.projectsList[key] = list
        }
        
        let newSections = updateSections()
        let newSectionForKey = newSections.firstIndex(of: key)
        
        tableView.performBatchUpdates({
            if let oldIndex = oldSectionForKey, let oldRow = oldRow {
                tableView.deleteRows(at: [IndexPath(row: oldRow, section: oldIndex)], with: .automatic)
            }
            
            if let oldIndex = oldSectionForKey, let newIndex = newSectionForKey, oldIndex != newIndex {
                tableView.deleteSections(IndexSet(integer: oldIndex), with: .fade)
                tableView.insertSections(IndexSet(integer: newIndex), with: .fade)
            } else if oldSectionForKey != nil && newSectionForKey == nil {
                tableView.deleteSections(IndexSet(integer: oldSectionForKey!), with: .fade)
            }
        }, completion: { _ in
            if let newIndex = newSectionForKey {
                self.tableView.reloadSections(IndexSet(integer: newIndex), with: .none)
            }
        })
    }

    private func updateSections() -> [String] {
        return projectsList
            .filter { !$0.value.isEmpty }
            .sorted { sortKeys($0.key, $1.key) }
            .map { $0.key }
    }

    private func sortKeys(_ a: String, _ b: String) -> Bool {
        let keyA = a.lowercased()
        let keyB = b.lowercased()
        if keyA == "applications" { return true }
        if keyB == "applications" { return false }
        if keyA == "unknown" { return false }
        if keyB == "unknown" { return true }
        return keyA < keyB
    }
    
    func createProject(mode: NXProjectType, withLanguage language: NXCodeTemplateLanguage) {
        let projectString: String
        
        switch(mode)
        {
        case .app:
            projectString = "App"
            break
        case .utility:
            projectString = "Utility"
            break
        default:
            projectString = "Unknown"
            break
        }
        
        let alert = UIAlertController(title: "Create \(projectString) Project",
                                      message: "",
                                      preferredStyle: .alert)
        
        alert.addTextField { (textField) -> Void in
            textField.placeholder = "Name"
        }
        
        if mode == .app {
            alert.addTextField { (textField) -> Void in
                textField.placeholder = "Bundle Identifier"
            }
        }
        
        let cancelAction: UIAlertAction = UIAlertAction(title: "Cancel", style: .cancel)
        
        let createAction: UIAlertAction = UIAlertAction(title: "Create", style: .default) { [weak self] action -> Void in
            guard let self = self else { return }
            let name = (alert.textFields![0]).text!
            var bundleid = ""
            if let textFieldArray = alert.textFields,
               textFieldArray.count > 1 {
                bundleid = textFieldArray[1].text!
            }
            
            if let project = NXProject.createProject(
                atPath: self.path,
                withName: name,
                withBundleIdentifier: bundleid,
                withType: mode,
                withLanguage: language
            ) {
                addProject(project)
            }
        }
        
        alert.addAction(cancelAction)
        alert.addAction(createAction)
        
        self.present(alert, animated: true)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        if let indexPath = sessionIndex {
            let keys = Array(self.projectsList.keys).sorted()
            let key = keys[indexPath.section]
            let sectionProjects = self.projectsList[key] ?? []
            let selectedProject: NXProject = sectionProjects[indexPath.row]
            selectedProject.reload()
            self.tableView.reloadRows(at: [indexPath], with: .none)
            sessionIndex = nil
        }
    }
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        let keys = Array(self.projectsList.keys).sorted()
        let key = keys[section]
        let sectionProjects = self.projectsList[key] ?? []
        return "\(key.capitalized) (\(sectionProjects.count))"
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        let keys = Array(self.projectsList.keys).sorted()
        let key = keys[section]
        let sectionProjects = self.projectsList[key] ?? []
        return sectionProjects.count
    }
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return self.projectsList.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let keys = Array(self.projectsList.keys).sorted()
        let key = keys[indexPath.section]
        let sectionProjects = self.projectsList[key] ?? []
        let project: NXProject = sectionProjects[indexPath.row];
        let cell: NXProjectTableCell = self.tableView.dequeueReusableCell(withIdentifier: NXProjectTableCell.reuseIdentifier()) as! NXProjectTableCell
        cell.configure(withDisplayName: project.projectConfig.displayName, withBundleIdentifier: project.projectConfig.bundleid, withAppIcon: nil, showAppIcon: project.projectConfig.type == .app, showBundleID: project.projectConfig.type == .app, showArrow: UIDevice.current.userInterfaceIdiom != .pad)
        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        sessionIndex = indexPath
        
        let keys = Array(self.projectsList.keys).sorted()
        let key = keys[indexPath.section]
        let sectionProjects = self.projectsList[key] ?? []
        
        let selectedProject: NXProject = sectionProjects[indexPath.row]
        
        if UIDevice.current.userInterfaceIdiom == .pad {
            let padFileVC: MainSplitViewController = MainSplitViewController(project: selectedProject)
            padFileVC.modalPresentationStyle = .fullScreen
            self.present(padFileVC, animated: true)
        } else {
            let fileVC = FileListViewController(project: selectedProject)
            self.navigationController?.pushViewController(fileVC, animated: true)
        }
    }
    
    override func tableView(_ tableView: UITableView, contextMenuConfigurationForRowAt indexPath: IndexPath, point: CGPoint) -> UIContextMenuConfiguration? {
        return UIContextMenuConfiguration(identifier: nil, previewProvider: nil) { suggestedActions in
            let export: UIAction = UIAction(title: "Export", image: UIImage(systemName: "square.and.arrow.up.fill")) { [weak self] _ in
                DispatchQueue.global().async {
                    guard let self = self else { return }
                    
                    let keys = Array(self.projectsList.keys).sorted()
                    let key = keys[indexPath.section]
                    let sectionProjects = self.projectsList[key] ?? []
                    let project: NXProject = sectionProjects[indexPath.row]
                    
                    let zipPath: String = "\(NSTemporaryDirectory())/\(project.projectConfig.displayName!).zip"
                    zipDirectoryAtPath(project.url.path, zipPath, true)
                    share(url: URL(fileURLWithPath: zipPath), remove: true)
                }
            }
            
            let item: UIAction = UIAction(title: "Remove", image: UIImage(systemName: "trash.fill"), attributes: .destructive) { _ in
                let keys = Array(self.projectsList.keys).sorted()
                let key = keys[indexPath.section]
                let sectionProjects = self.projectsList[key] ?? []
                let project = sectionProjects[indexPath.row]
                
                self.presentConfirmationAlert(
                    title: "Warning",
                    message: "Are you sure you want to remove \"\(project.projectConfig.displayName!)\"?",
                    confirmTitle: "Remove",
                    confirmStyle: .destructive)
                { [weak self] in
                    guard let self = self else { return }
                    removeProject(project)
                }
            }
            
            return UIMenu(children: [export, item])
        }
    }
    
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        do {
            guard let selectedURL = urls.first else { return }

            let extractFirst = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("Proj")
            
            if FileManager.default.fileExists(atPath: extractFirst.path) {
                try FileManager.default.removeItem(at: extractFirst)
            }
            try FileManager.default.createDirectory(at: extractFirst, withIntermediateDirectories: true)

            guard unzipArchiveAtPath(selectedURL.path, extractFirst.path) else {
                try? FileManager.default.removeItem(at: extractFirst)
                throw CocoaError(.fileReadCorruptFile)
            }

            // Removing the __MAXOSX shit
            let items = try FileManager.default.contentsOfDirectory(atPath: extractFirst.path).filter { !$0.hasPrefix("__") && !$0.hasPrefix(".") }

            guard let firstItem = items.first else {
                try? FileManager.default.removeItem(at: extractFirst)
                throw CocoaError(.fileReadNoSuchFile)
            }

            let projectPath = "\(Bootstrap.shared.bootstrapPath("/Projects"))/\(UUID().uuidString)"

            do {
                try FileManager.default.moveItem(
                    atPath: extractFirst.appendingPathComponent(firstItem).path,
                    toPath: projectPath
                )
            } catch {
                try? FileManager.default.removeItem(at: extractFirst)
                throw error
            }

            try? FileManager.default.removeItem(at: extractFirst)

            if let project = NXProject(path: projectPath) {
                addProject(project)
            }
        } catch {
            NotificationServer.NotifyUser(level: .error, notification: error.localizedDescription)
        }
    }
    
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        let keys = Array(self.projectsList.keys).sorted()
        let key = keys[indexPath.section]
        if #available(iOS 26.0, *) {
            return (key == "applications") ? 80 : UITableView.automaticDimension
        } else {
            return (key == "applications") ? 70 : UITableView.automaticDimension
        }
    }
}
