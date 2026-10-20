/*
 SPDX-License-Identifier: LicenseRef-EPSL-1.1

 Copyright (C) 2025 - 2026 emexlab

 This file is part of Nyxian.

 Licensed under the emexLabs Public Source License, version 1.1
 (EPSL 1.1).

 Private use and modification are permitted under the license.
 Redistribution of source or binaries, modified or unmodified,
 requires prior written permission from emexLabs.

 External deployment is subject to the source-availability
 requirements and other conditions of the license.

 Provided "AS IS", without warranty, to the extent permitted by law.

 See LICENSE for the full license terms.
*/

import Foundation
import SwiftUI
import UIKit

@objc class ContentViewController: NXUITableViewController, UIDocumentPickerDelegate, UIAdaptivePresentationControllerDelegate {
    var sessionIndex: IndexPath? = nil
    var projectsList: [String:[NXProject]] = [:]
    
    @objc init() {
        super.init(style: .insetGrouped)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func reloadProjectsFromDisk() {
        let rawProjectsList = NXProject.listProjects(at: NXBootstrap.shared().rootURL.appendingPathComponent("Projects")) as! [String: [NXProject]]
        var buckets: [String: [NXProject]] = [:]
        
        for project in rawProjectsList.values.flatMap({ $0 }) {
            let key = Self.sectionKey(for: project)
            buckets[key, default: []].append(project)
        }
        
        self.projectsList = buckets
        self.tableView.reloadData()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.tableView.register(ProjectTableCell.self, forCellReuseIdentifier: ProjectTableCell.reuseIdentifier)
        self.tableView.register(UITableViewCell.self, forCellReuseIdentifier: "Cell")
        self.title = "Projects"

        let createItem = UIBarButtonItem(
            barButtonSystemItem: .add,
            target: self,
            action: #selector(presentProjectCreationSheet)
        )
        let importItem = UIBarButtonItem(
            image: UIImage(systemName: "square.and.arrow.down.fill"),
            style: .plain,
            target: self,
            action: #selector(presentImportPicker)
        )
        self.navigationItem.setRightBarButtonItems([createItem, importItem], animated: false)
        
        reloadProjectsFromDisk()
    }

    @objc private func presentProjectCreationSheet() {
        let model = ProjectTemplateOptionsModel(schemeKind: .app)
        let view = ProjectCreationSheetView(
            model: model,
            onCancel: { [weak self] in
                self?.dismiss(animated: true)
            },
            onCreate: { [weak self] in
                guard let self = self else { return }
                if self.createProject(from: model) {
                    self.dismiss(animated: true)
                }
            }
        )
        
        _ = view.presentationBackground(Color(uiColor: LDETheme.currentTheme!.backgroundColor))

        let hostingController = UIHostingController(rootView: view)
        hostingController.modalPresentationStyle = .pageSheet
        if let sheet = hostingController.sheetPresentationController {
            sheet.detents = [.medium(), .large()]
            sheet.prefersGrabberVisible = true
        }
        hostingController.view.backgroundColor = LDETheme.currentTheme!.backgroundColor;
        present(hostingController, animated: true)
    }

    @objc private func presentImportPicker() {
        let documentPicker = UIDocumentPickerViewController(forOpeningContentTypes: [.zip], asCopy: true)
        documentPicker.delegate = self
        documentPicker.modalPresentationStyle = .formSheet
        self.present(documentPicker, animated: true)
    }
    
    func addProject(_ project: NXProject) {
        let key = {
            switch project.projectConfig.schemeKind {
            case .app: return "applications"
            case .utility: return "utilities"
            case .kSurfaceKext: return "kernel extension"
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
            switch project.projectConfig.schemeKind {
            case .app: return "applications"
            case .utility: return "utilities"
            case .kSurfaceKext: return "kernel extension"
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
        if keyA == "utilities" { return true }
        if keyB == "utilities" { return false }
        if keyA == "unknown" { return false }
        if keyB == "unknown" { return true }
        return keyA < keyB
    }
    
    private func createProject(from optionsModel: ProjectTemplateOptionsModel) -> Bool {
        let name = optionsModel.productName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else {
            NXAlertDiagnosticPresenter.notifyUser(with: .error, withMessage: "Product name is required", withDelay: 0.0)
            return false
        }
        
        optionsModel.saveOrganizationIdentifier()
        
        guard let project = NXProject.createProject(
            at: NXBootstrap.shared().rootURL.appendingPathComponent("Projects"),
            withName: name,
            withOrganizationIdentifier: optionsModel.normalizedOrganizationIdentifier,
            withBundleIdentifier: optionsModel.bundleIdentifier,
            withSchemeKind: optionsModel.schemeKind,
            withLanguageKind: optionsModel.selectedLanguage,
            withInterfaceKind: optionsModel.selectedInterface) else
        {
            NXAlertDiagnosticPresenter.notifyUser(with: .error, withMessage: "Failed to create project", withDelay: 0.0)
            return false
        }
        
        addProject(project)
        return true
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if sessionIndex != nil {
            reloadProjectsFromDisk()
        }
    }
    
    private var sortedSectionKeys: [String] {
        projectsList.keys.sorted(by: sortKeys)
    }
    
    private static func sectionKey(for project: NXProject) -> String {
        switch project.projectConfig.schemeKind {
        case .app: return "applications"
        case .utility: return "utilities"
        case .kSurfaceKext: return "kernel extension"
        default: return "unknown"
        }
    }
    
    private func sectionTitle(for key: String) -> String {
        switch key {
        case "applications": return "Applications"
        case "utilities": return "Utilities"
        case "kernel extension": return "Kernel Extensions"
        default: return key.capitalized
        }
    }
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        let key = sortedSectionKeys[section]
        let sectionProjects = self.projectsList[key] ?? []
        return "\(sectionTitle(for: key)) (\(sectionProjects.count))"
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        let key = sortedSectionKeys[section]
        let sectionProjects = self.projectsList[key] ?? []
        return sectionProjects.count
    }
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return self.projectsList.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let key = sortedSectionKeys[indexPath.section]
        let sectionProjects = self.projectsList[key] ?? []
        let project: NXProject = sectionProjects[indexPath.row]
        let cell: ProjectTableCell = self.tableView.dequeueReusableCell(withIdentifier: ProjectTableCell.reuseIdentifier) as! ProjectTableCell
        let icon: UIImage? = {
            switch project.projectConfig.schemeKind {
            case .app: return nil
            case .kSurfaceKext: return UIImage(systemName: "puzzlepiece.extension.fill")
            default: return UIImage(named: "UtilityIcon")
            }
        }()
        cell.configure(displayName: project.projectConfig.displayName, bundleIdentifier: project.projectConfig.bundleid, appIcon: icon, showArrow: UIDevice.current.userInterfaceIdiom != .pad)
        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        sessionIndex = indexPath
        
        let key = sortedSectionKeys[indexPath.section]
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
            let export: UIAction = UIAction(title: "Export", image: UIImage(systemName: "square.and.arrow.up.fill")) { _ in
                DispatchQueue.global().async {
                    let key = self.sortedSectionKeys[indexPath.section]
                    let sectionProjects = self.projectsList[key] ?? []
                    let project: NXProject = sectionProjects[indexPath.row]
                    
                    let zipPath: String = "\(NSTemporaryDirectory())/\(project.projectConfig.displayName!).zip"
                    zipDirectoryAtPath(project.url.path, zipPath, true)
                    share(url: URL(fileURLWithPath: zipPath), remove: true)
                }
            }
            
            let item: UIAction = UIAction(title: "Remove", image: UIImage(systemName: "trash.fill"), attributes: .destructive) { _ in
                let key = self.sortedSectionKeys[indexPath.section]
                let sectionProjects = self.projectsList[key] ?? []
                let project = sectionProjects[indexPath.row]
                
                self.presentConfirmationAlert(
                    title: "Warning",
                    message: "Are you sure you want to remove \"\(project.projectConfig.displayName!)\"?",
                    confirmTitle: "Remove",
                    confirmStyle: .destructive)
                {
                    self.removeProject(project)
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
            NXAlertDiagnosticPresenter.notifyUser(with: .error, withMessage: error.localizedDescription, withDelay: 0.0)
        }
    }
    
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        if #available(iOS 26.0, *) {
            return 80
        } else {
            return 70
        }
    }
}

final class ProjectTemplateOptionsModel: ObservableObject {
    private static let organizationIdentifierDefaultsKey = "LDEOrganizationPrefix"
    private static let defaultOrganizationIdentifier = "com.example"
    private static let allowedIdentifierCharacters = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-")

    @Published var step: ProjectCreationStep = .template
    @Published private(set) var schemeKind: NXProjectSchemeKind
    private let appLanguages: [ProjectTemplatePickerOption] = [
        ProjectTemplatePickerOption(id: "Swift", title: "Swift"),
        ProjectTemplatePickerOption(id: "ObjC", title: "Objective-C")
    ]
    private let utilityLanguages: [ProjectTemplatePickerOption] = [
        ProjectTemplatePickerOption(id: "Swift", title: "Swift"),
        ProjectTemplatePickerOption(id: "ObjC", title: "Objective-C"),
        ProjectTemplatePickerOption(id: "C++", title: "C++"),
        ProjectTemplatePickerOption(id: "C", title: "C")
    ]
    private let kextLanguages: [ProjectTemplatePickerOption] = [
        ProjectTemplatePickerOption(id: "C", title: "C")
    ]
    private let interfaces: [ProjectTemplatePickerOption] = [
        ProjectTemplatePickerOption(id: "SwiftUI", title: "SwiftUI"),
        ProjectTemplatePickerOption(id: "UIKit", title: "UIKit")
    ]

    @Published var productName = ""
    @Published var organizationIdentifier: String
    @Published private var selectedLanguageID = "Swift"
    @Published private var selectedInterfaceID = "SwiftUI"

    init(schemeKind: NXProjectSchemeKind) {
        self.schemeKind = schemeKind
        self.organizationIdentifier = UserDefaults.standard.string(forKey: Self.organizationIdentifierDefaultsKey) ?? Self.defaultOrganizationIdentifier
    }

    var showsAppOptions: Bool {
        return schemeKind == .app
    }
    
    var showLanguageOptions: Bool {
        return schemeKind != .kSurfaceKext
    }

    var normalizedOrganizationIdentifier: String {
        return Self.organizationIdentifier(from: organizationIdentifier)
    }

    var bundleIdentifier: String {
        let productIdentifier = Self.productIdentifier(from: productName)
        return [normalizedOrganizationIdentifier, productIdentifier]
            .filter { !$0.isEmpty }
            .joined(separator: ".")
    }

    var selectedLanguage: NXProjectLanguageKind {
        switch selectedLanguageID {
        case "ObjC": return .objectiveC
        case "C++": return .CXX
        case "C": return .C
        default: return .swift
        }
    }

    var selectedInterface: NXProjectInterfaceKind {
        guard schemeKind == .app else { return .unknown }
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

    var languageOptions: [ProjectTemplatePickerOption] {
        if schemeKind == .utility {
            return utilityLanguages
        } else if schemeKind == .kSurfaceKext {
            return kextLanguages
        }
        return appLanguages
    }
    
    var interfaceDisabledIDs: Set<String> {
        selectedLanguageID == "ObjC" ? ["SwiftUI"] : []
    }

    var interfaceOptions: [ProjectTemplatePickerOption] {
        return interfaces
    }

    func selectProjectType(_ schemeKind: NXProjectSchemeKind) {
        self.schemeKind = schemeKind
        if schemeKind == .app {
            switch selectedLanguageID {
            case "Swift", "ObjC":
                break
            default:
                selectedLanguageID = "Swift"
            }
        }

        if selectedInterfaceID == "SwiftUI" {
            selectedLanguageID = "Swift"
        }
    }

    func saveOrganizationIdentifier() {
        let value = normalizedOrganizationIdentifier
        guard !value.isEmpty else { return }
        organizationIdentifier = value
        UserDefaults.standard.set(value, forKey: Self.organizationIdentifierDefaultsKey)
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

    private static func organizationIdentifier(from value: String) -> String {
        return value
            .split(separator: ".", omittingEmptySubsequences: true)
            .map { productIdentifier(from: String($0).lowercased()) }
            .filter { !$0.isEmpty }
            .joined(separator: ".")
    }

    private static func productIdentifier(from value: String) -> String {
        let source = value.trimmingCharacters(in: .whitespacesAndNewlines)
        var output = ""
        var lastWasReplacement = false

        for scalar in source.unicodeScalars {
            if allowedIdentifierCharacters.contains(scalar) {
                output.unicodeScalars.append(scalar)
                lastWasReplacement = false
            } else if !lastWasReplacement {
                output.append("-")
                lastWasReplacement = true
            }
        }

        return output.trimmingCharacters(in: CharacterSet(charactersIn: "-"))
    }
}

struct ProjectTemplateOptionsView: View {
    @ObservedObject var model: ProjectTemplateOptionsModel
    
    private var textColor: Color { Color(uiColor: LDETheme.currentTheme!.textColor) }
    private var hairlineColor: Color { Color(uiColor: LDETheme.currentTheme!.gutterHairlineColor) }
    private var groupBackground: Color { textColor.opacity(0.05) }
    private var secondaryTextColor: Color { textColor.opacity(0.6) }
    
    var body: some View {
        VStack(spacing: 12) {
            VStack(spacing: 0) {
                templateTextField(
                    label: "Product Name",
                    placeholder: "Product Name",
                    text: $model.productName
                )
                themedDivider
                templateTextField(
                    label: "Organization Identifier",
                    placeholder: "com.example",
                    text: $model.organizationIdentifier,
                    keyboardType: .URL
                )
                themedDivider
                generatedIdentifierRow
            }
            .background(groupBackground)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            
            VStack(spacing: 8) {
                if model.showsAppOptions {
                    ProjectTemplatePickerRow(
                        title: "Interface:",
                        options: model.interfaceOptions,
                        disabledIDs: model.interfaceDisabledIDs,
                        selectionID: $model.interfaceSelection
                    )
                }
                
                if model.showLanguageOptions {
                    ProjectTemplatePickerRow(
                        title: "Language:",
                        options: model.languageOptions,
                        selectionID: $model.languageSelection
                    )
                }
            }
        }
        .padding(.top, 2)
        .padding(.horizontal, 18)
        .padding(.bottom, 6)
        .fixedSize(horizontal: false, vertical: true)
        .onAppear {
            if model.schemeKind == .kSurfaceKext {
                model.languageSelection = "C"
            }
        }
    }
    
    private var themedDivider: some View {
        Rectangle()
            .fill(hairlineColor)
            .frame(height: 1 / UIScreen.main.scale)
            .padding(.leading, 12)
    }
    
    private var generatedIdentifierRow: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("Bundle Identifier")
                .font(.caption)
                .foregroundStyle(secondaryTextColor)
            Text(model.bundleIdentifier.isEmpty ? " " : model.bundleIdentifier)
                .font(.callout)
                .foregroundStyle(secondaryTextColor)
                .lineLimit(2)
                .minimumScaleFactor(0.85)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private func templateTextField(label: String,
                                   placeholder: String,
                                   text: Binding<String>,
                                   keyboardType: UIKeyboardType = .default) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label)
                .font(.caption)
                .foregroundStyle(secondaryTextColor)
            TextField(placeholder, text: text)
                .textFieldStyle(.plain)
                .font(.callout)
                .foregroundStyle(textColor)
                .tint(textColor)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .keyboardType(keyboardType)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
}
