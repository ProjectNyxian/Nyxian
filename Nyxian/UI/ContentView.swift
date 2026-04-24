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
import SwiftUI
import UIKit

@objc class ContentViewController: UIThemedTableViewController, UIDocumentPickerDelegate, UIAdaptivePresentationControllerDelegate {
    var sessionIndex: IndexPath? = nil
    var projectsList: [String:[NXProject]] = [:]
    
    @objc init() {
        RevertUI()
        super.init(style: .insetGrouped)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.tableView.register(NXProjectTableCell.self, forCellReuseIdentifier: NXProjectTableCell.reuseIdentifier())
        
        self.title = "Projects"
        
        let application: UIAction = UIAction(title: "App", image: UIImage(systemName: "app.gift.fill")) { [weak self] _ in
            guard let self = self else { return }
            self.createProject(mode: .app)
        }
        
        /* utility menu */
        let swiftUtility: UIAction = UIAction(title: "Swift") { [weak self] _ in
            guard let self = self else { return }
            self.createProject(mode: .utility, withLanguage: .swift)
        }
        
        let ObjCCUtility: UIAction = UIAction(title: "ObjC") { [weak self] _ in
            guard let self = self else { return }
            self.createProject(mode: .utility, withLanguage: .objC)
        }
        
        let CPPCUtility: UIAction = UIAction(title: "C++") { [weak self] _ in
            guard let self = self else { return }
            self.createProject(mode: .utility, withLanguage: .cpp)
        }
        
        let CUtility: UIAction = UIAction(title: "C") { [weak self] _ in
            guard let self = self else { return }
            self.createProject(mode: .utility, withLanguage: .C)
        }
        
        let utilityMenu: UIMenu = UIMenu(title: "Utility", image: UIImage(systemName: "wrench.adjustable.fill"), children: [swiftUtility, ObjCCUtility, CPPCUtility, CUtility])
        
        let createMenu: UIMenu = UIMenu(title: "Create Project", image: UIImage(systemName: "folder.fill"), children: [application, utilityMenu])
        
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
        
        let rawProjectsList = NXProject.listProjects(at: NXBootstrap.shared().rootURL.appendingPathComponent("Projects")) as! [String:[NXProject]]
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
    
    func createProject(mode: NXProjectType, withLanguage language: NXCodeTemplateLanguage? = nil) {
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
                                      message: nil,
                                      preferredStyle: .alert)
        let appTemplateOptionsModel: AppTemplateOptionsModel?

        if mode == .app {
            let optionsModel = AppTemplateOptionsModel()
            let optionsController = AppTemplateOptionsHostingController(model: optionsModel)
            appTemplateOptionsModel = optionsModel
            alert.setValue(optionsController, forKey: "contentViewController")
        } else {
            appTemplateOptionsModel = nil
            alert.addTextField { (textField) -> Void in
                textField.placeholder = "Name"
            }
        }
        
        let cancelAction: UIAlertAction = UIAlertAction(title: "Cancel", style: .cancel)
        
        let createAction: UIAlertAction = UIAlertAction(title: "Create", style: .default) { [weak self] action -> Void in
            guard let self = self else { return }
            let name: String
            let bundleid: String
            let projectLanguage: NXCodeTemplateLanguage
            let projectInterface: NXCodeTemplateInterface

            if mode == .app, let appTemplateOptionsModel {
                name = appTemplateOptionsModel.projectName
                bundleid = appTemplateOptionsModel.bundleIdentifier
                projectLanguage = appTemplateOptionsModel.selectedLanguage
                projectInterface = appTemplateOptionsModel.selectedInterface
            } else if let language = language {
                name = alert.textFields?.first?.text ?? ""
                bundleid = ""
                projectLanguage = language
                projectInterface = .invalid
            } else {
                return
            }

            if let project = NXProject.createProject(
                at: NXBootstrap.shared().rootURL.appendingPathComponent("Projects"),
                withName: name,
                withBundleIdentifier: bundleid,
                withType: mode,
                withLanguage: projectLanguage,
                withInterface: projectInterface
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

            let projectPath = "\(NXBootstrap.shared().rootURL.appendingPathComponent("/Projects").path)/\(UUID().uuidString)"

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

            if let project = NXProject(url: URL(fileURLWithPath: projectPath)) {
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

private final class AppTemplateOptionsModel: ObservableObject {
    private struct Option: Identifiable {
        let id: String
        let title: String
    }

    private let languages: [Option] = [
        Option(id: "Swift", title: "Swift"),
        Option(id: "ObjC", title: "ObjC")
    ]
    private let interfaces: [Option] = [
        Option(id: "SwiftUI", title: "SwiftUI"),
        Option(id: "UIKit", title: "UIKit")
    ]

    @Published var projectName = ""
    @Published var bundleIdentifier = ""
    @Published private var selectedLanguageID = "Swift"
    @Published private var selectedInterfaceID = "UIKit"

    var selectedLanguage: NXCodeTemplateLanguage {
        return selectedLanguageID == "ObjC" ? .objC : .swift
    }

    var selectedInterface: NXCodeTemplateInterface {
        return selectedInterfaceID == "SwiftUI" ? .swiftUI : .uiKit
    }

    var languageSelection: String {
        get { selectedLanguageID }
        set { selectLanguage(id: newValue) }
    }

    var interfaceSelection: String {
        get { selectedInterfaceID }
        set { selectInterface(id: newValue) }
    }

    var languageOptions: [(id: String, title: String)] {
        let options = selectedInterfaceID == "SwiftUI" ? [languages[0]] : languages
        return options.map { (id: $0.id, title: $0.title) }
    }

    var interfaceOptions: [(id: String, title: String)] {
        return interfaces.map { (id: $0.id, title: $0.title) }
    }

    private func selectLanguage(id: String) {
        selectedLanguageID = id
        if selectedLanguageID == "ObjC" {
            selectedInterfaceID = "UIKit"
        }
    }

    private func selectInterface(id: String) {
        selectedInterfaceID = id
        if selectedInterfaceID == "SwiftUI" {
            selectedLanguageID = "Swift"
        }
    }
}

private struct AppTemplateOptionsView: View {
    @ObservedObject var model: AppTemplateOptionsModel

    var body: some View {
        VStack(spacing: 12) {
            VStack(spacing: 0) {
                templateTextField("Name", text: $model.projectName)
                Divider()
                    .padding(.leading, 12)
                templateTextField("Bundle Identifier", text: $model.bundleIdentifier)
                    .keyboardType(.URL)
            }
            .background(Color(uiColor: .secondarySystemFill))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            VStack(spacing: 8) {
                optionRow(
                    title: "Interface:",
                    value: title(for: model.interfaceSelection, in: model.interfaceOptions),
                    options: model.interfaceOptions,
                    selection: Binding(
                        get: { model.interfaceSelection },
                        set: { model.interfaceSelection = $0 }
                    )
                )

                optionRow(
                    title: "Language:",
                    value: title(for: model.languageSelection, in: model.languageOptions),
                    options: model.languageOptions,
                    selection: Binding(
                        get: { model.languageSelection },
                        set: { model.languageSelection = $0 }
                    )
                )
            }
            .font(.body)
        }
        .padding(.top, 2)
        .padding(.horizontal, 18)
        .padding(.bottom, 6)
        .fixedSize(horizontal: false, vertical: true)
    }

    private func templateTextField(_ placeholder: String, text: Binding<String>) -> some View {
        TextField(placeholder, text: text)
            .textFieldStyle(.plain)
            .font(.body)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .padding(.horizontal, 12)
            .frame(height: 40)
    }

    private func optionRow(title: String,
                           value: String,
                           options: [(id: String, title: String)],
                           selection: Binding<String>) -> some View {
        HStack {
            Text(title)
                .font(.body)
                .foregroundStyle(.primary)
            Spacer(minLength: 12)
            Menu {
                ForEach(options, id: \.id) { option in
                    Button {
                        selection.wrappedValue = option.id
                    } label: {
                        if option.id == selection.wrappedValue {
                            Label(option.title, systemImage: "checkmark")
                        } else {
                            Text(option.title)
                        }
                    }
                }
            } label: {
                HStack(spacing: 6) {
                    Text(value)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption.weight(.semibold))
                }
                .font(.body)
                .foregroundStyle(.primary)
                .padding(.horizontal, 10)
                .frame(minHeight: 32)
                .background(Color(uiColor: .secondarySystemFill))
                .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
            }
        }
    }

    private func title(for id: String, in options: [(id: String, title: String)]) -> String {
        return options.first { $0.id == id }?.title ?? id
    }
}

private final class AppTemplateOptionsHostingController: UIHostingController<AppTemplateOptionsView> {
    let model: AppTemplateOptionsModel

    init(model: AppTemplateOptionsModel) {
        self.model = model
        super.init(rootView: AppTemplateOptionsView(model: model))
        sizingOptions = [.preferredContentSize]
    }

    @MainActor @objc required dynamic init?(coder aDecoder: NSCoder) {
        let model = AppTemplateOptionsModel()
        self.model = model
        super.init(coder: aDecoder, rootView: AppTemplateOptionsView(model: model))
        sizingOptions = [.preferredContentSize]
    }
}
