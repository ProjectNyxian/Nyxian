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

import UIKit

enum FlagType {
    case clang, swift, linker
    
    var title: String {
        switch self {
            case .clang: return "Clang Flags"
            case .swift: return "Swift Flags"
            case .linker: return "Other Linker Flags"
        }
    }
}

class FlagsEditViewController: UIThemedTableViewController {
    let flagType: FlagType
    private var flags: [String]
    var onFlagsChanged: (([String]) -> Void)?

    private let addFlagCell = "AddFlagCell"
    private let flagCell = "FlagCell"

    init(flagType: FlagType, flags: [String]) {
        self.flagType = flagType
        self.flags = flags
        super.init(style: .insetGrouped)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        title = flagType.title

        tableView.register(UITableViewCell.self, forCellReuseIdentifier: flagCell)
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: addFlagCell)
        tableView.isEditing = true
        tableView.allowsSelectionDuringEditing = true
    }

    private enum Section: Int, CaseIterable {
        case flags, add
    }

    override func numberOfSections(in tableView: UITableView) -> Int {
        Section.allCases.count
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch Section(rawValue: section)! {
            case .flags: return flags.count
            case .add: return 1
        }
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch Section(rawValue: indexPath.section)! {
            case .flags:
                let cell = tableView.dequeueReusableCell(withIdentifier: flagCell, for: indexPath)
                cell.textLabel?.text = flags[indexPath.row]
                cell.textLabel?.font = .monospacedSystemFont(ofSize: 14, weight: .regular)
                cell.showsReorderControl = true
                return cell
            case .add:
                let cell = tableView.dequeueReusableCell(withIdentifier: addFlagCell, for: indexPath)
                cell.textLabel?.text = "Add Flag…"
                cell.textLabel?.textColor = view.tintColor
                return cell
        }
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        switch Section(rawValue: indexPath.section)! {
            case .flags: presentEditAlert(editing: indexPath.row)
            case .add: presentAddAlert()
        }
    }

    override func tableView(_ tableView: UITableView,
                            editingStyleForRowAt indexPath: IndexPath) -> UITableViewCell.EditingStyle {
        switch Section(rawValue: indexPath.section)! {
            case .flags: return .delete
            case .add: return .insert
        }
    }

    override func tableView(_ tableView: UITableView,
                            commit editingStyle: UITableViewCell.EditingStyle,
                            forRowAt indexPath: IndexPath) {
        switch editingStyle {
            case .delete:
                flags.remove(at: indexPath.row)
                tableView.deleteRows(at: [indexPath], with: .automatic)
                notifyChange()
            case .insert:
                presentAddAlert()
            default:
                break
        }
    }

    override func tableView(_ tableView: UITableView,
                            moveRowAt sourceIndexPath: IndexPath,
                            to destinationIndexPath: IndexPath) {
        let moved = flags.remove(at: sourceIndexPath.row)
        flags.insert(moved, at: destinationIndexPath.row)
        notifyChange()
    }

    override func tableView(_ tableView: UITableView,
                            canMoveRowAt indexPath: IndexPath) -> Bool {
        Section(rawValue: indexPath.section) == .flags
    }

    override func tableView(_ tableView: UITableView,
                            targetIndexPathForMoveFromRowAt sourceIndexPath: IndexPath,
                            toProposedIndexPath proposedDestinationIndexPath: IndexPath) -> IndexPath {
        if proposedDestinationIndexPath.section != Section.flags.rawValue {
            return IndexPath(row: flags.count - 1, section: Section.flags.rawValue)
        }
        return proposedDestinationIndexPath
    }

    override func tableView(_ tableView: UITableView,
                            shouldIndentWhileEditingRowAt indexPath: IndexPath) -> Bool {
        Section(rawValue: indexPath.section) == .flags
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        Section(rawValue: section) == .flags ? flagType.title : nil
    }

    private func presentAddAlert() {
        presentFlagAlert(title: "Add Flag", existingValue: nil) { [weak self] value in
            guard let self else { return }
            self.flags.append(value)
            let ip = IndexPath(row: self.flags.count - 1, section: Section.flags.rawValue)
            self.tableView.insertRows(at: [ip], with: .automatic)
            self.notifyChange()
        }
    }

    private func presentEditAlert(editing row: Int) {
        presentFlagAlert(title: "Edit Flag", existingValue: flags[row]) { [weak self] value in
            guard let self else { return }
            self.flags[row] = value
            let ip = IndexPath(row: row, section: Section.flags.rawValue)
            self.tableView.reloadRows(at: [ip], with: .automatic)
            self.notifyChange()
        }
    }

    private func presentFlagAlert(title: String, existingValue: String?, completion: @escaping (String) -> Void) {
        let alert = UIAlertController(title: title, message: nil, preferredStyle: .alert)

        alert.addTextField { field in
            field.text = existingValue
            field.placeholder = "-flag or -DKEY=VALUE"
            field.font = .monospacedSystemFont(ofSize: 14, weight: .regular)
            field.autocorrectionType = .no
            field.autocapitalizationType = .none
            field.clearButtonMode = .whileEditing
        }

        let confirm = UIAlertAction(title: existingValue == nil ? "Add" : "Save", style: .default) { _ in
            let value = alert.textFields?.first?.text?.trimmingCharacters(in: .whitespaces) ?? ""
            guard !value.isEmpty else { return }
            completion(value)
        }

        alert.addAction(confirm)
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.preferredAction = confirm

        present(alert, animated: true)
    }
    
    private func notifyChange() {
        onFlagsChanged?(flags)
    }
}

class ProjectConfigViewController: UIThemedTableViewController {
    let project: NXProject
    
    private var pendingDisplayName: String
    private var pendingExecutable: String
    private var pendingBundleIdentifier: String
    private var pendingBundleVersion: String
    private var pendingBundleShortVersion: String
    private var pendingDeployVersion: String
    private var pendingClangFlags: [String]
    private var pendingSwiftFlags: [String]
    private var pendingLinkerFlags: [String]
    private var isDirty = false {
        didSet { navigationItem.rightBarButtonItem?.isEnabled = isDirty }
    }

    init(project: NXProject) {
        self.project = project
        self.project.reload()
        self.pendingClangFlags = project.projectConfig.dictionary["LDECompilerFlags"] as? [String] ?? []
        self.pendingSwiftFlags = project.projectConfig.dictionary["LDESwiftFlags"] as? [String] ?? []
        self.pendingLinkerFlags = project.projectConfig.dictionary["LDELinkerFlags"] as? [String] ?? []
        self.pendingDisplayName = project.projectConfig.dictionary["LDEDisplayName"] as? String ?? project.projectConfig.displayName
        self.pendingBundleIdentifier = project.projectConfig.dictionary["LDEBundleIdentifier"] as? String ?? project.projectConfig.bundleid
        self.pendingBundleVersion = project.projectConfig.dictionary["LDEBundleVersion"] as? String ?? project.projectConfig.version
        self.pendingBundleShortVersion = project.projectConfig.dictionary["LDEBundleShortVersion"] as? String ?? project.projectConfig.shortVersion
        self.pendingBundleIdentifier = project.projectConfig.dictionary["LDEBundleIdentifier"] as? String ?? project.projectConfig.bundleid
        self.pendingExecutable = project.projectConfig.dictionary["LDEExecutable"] as? String ?? ""
        self.pendingDeployVersion = project.projectConfig.dictionary["LDEMinimumVersion"] as? String ?? NXOSVersionSupportedBuildVersions.first ?? "9.0"
        self.pendingLinkerFlags = project.projectConfig.dictionary["LDELinkerFlags"] as? [String] ?? []
        super.init(style: .insetGrouped)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        title = "Project Configuration"
        
        let saveButton: UIBarButtonItem = UIBarButtonItem()
        saveButton.title = "Save"
        saveButton.target = self
        saveButton.action = #selector(saveTapped)
        saveButton.isEnabled = false
        navigationItem.rightBarButtonItem = saveButton
        
        let closeButton: UIBarButtonItem = UIBarButtonItem()
        closeButton.image = UIImage(systemName: "xmark")
        closeButton.target = self
        closeButton.action = #selector(closeTapped)
        navigationItem.leftBarButtonItem = closeButton
    }
    
    private enum Section: Int, CaseIterable {
        case general
        case deplyment
        case buildFlags

        var header: String {
            switch self {
                case .general: return "General"
                case .deplyment: return "Deployment"
                case .buildFlags: return "Build Flags"
            }
        }
    }

    private enum GeneralRow: Int, CaseIterable {
        case displayName
        case executable
        case bundleIdentifier
        case bundleVersion
        case bundleShortVersion

        var title: String {
            switch self {
                case .displayName: return "Display Name"
                case .executable: return "Executable"
                case .bundleIdentifier: return "Bundle Identifier"
                case .bundleVersion: return "Bundle Version"
                case .bundleShortVersion: return "Bundle Short Version"
            }
        }
    }
    
    private enum DeploymentRow: Int, CaseIterable {
        case deployVersion

        var title: String {
            switch self {
                case .deployVersion: return "Deployment Target"
            }
        }
    }

    private enum BuildFlagRow: Int, CaseIterable {
        case clangFlags
        case swiftFlags
        case linkerFlags

        var title: String {
            switch self {
                case .clangFlags: return "Clang Flags"
                case .swiftFlags: return "Swift Flags"
                case .linkerFlags: return "Other Linker Flags"
            }
        }
    }
    
    override func numberOfSections(in tableView: UITableView) -> Int {
            Section.allCases.count
        }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch Section(rawValue: section)! {
            case .general:
                if project.projectConfig.schemeKind == .app {
                    return GeneralRow.allCases.count
                } else {
                    return GeneralRow.allCases.count - 3
                }
            case .deplyment: return DeploymentRow.allCases.count
            case .buildFlags: return BuildFlagRow.allCases.count
        }
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell") ?? UITableViewCell(style: .value1, reuseIdentifier: "Cell")

        cell.accessoryType = .disclosureIndicator
        cell.detailTextLabel?.textColor = .secondaryLabel

        switch Section(rawValue: indexPath.section)! {
            case .general:
                let row = GeneralRow(rawValue: indexPath.row)!
                cell.textLabel?.text = row.title
                switch row {
                    case .displayName: cell.detailTextLabel?.text = pendingDisplayName.isEmpty ? "Not Set" : pendingDisplayName
                    case .executable: cell.detailTextLabel?.text = pendingExecutable.isEmpty ? "Not Set" : pendingExecutable
                    case .bundleIdentifier: cell.detailTextLabel?.text = pendingBundleIdentifier.isEmpty ? "Not Set" : pendingBundleIdentifier
                    case .bundleVersion: cell.detailTextLabel?.text = pendingBundleVersion.isEmpty ? "Not Set" : pendingBundleVersion
                    case .bundleShortVersion: cell.detailTextLabel?.text = pendingBundleShortVersion.isEmpty ? "Not Set" : pendingBundleShortVersion
                }
            case .deplyment:
                let row = DeploymentRow(rawValue: indexPath.row)!
                cell.textLabel?.text = row.title
                switch row {
                    case .deployVersion: cell.detailTextLabel?.text = "iOS \(pendingDeployVersion)"
                }
            case .buildFlags:
                let row = BuildFlagRow(rawValue: indexPath.row)!
                cell.textLabel?.text        = row.title
                switch row {
                    case .clangFlags: cell.detailTextLabel?.text = subtitle(for: pendingClangFlags)
                    case .swiftFlags: cell.detailTextLabel?.text = subtitle(for: pendingSwiftFlags)
                    case .linkerFlags: cell.detailTextLabel?.text = subtitle(for: pendingLinkerFlags)
                }
        }
        
        return cell
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        Section(rawValue: section)!.header
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        switch Section(rawValue: indexPath.section)! {
            case .general:
                switch GeneralRow(rawValue: indexPath.row)! {
                    case .displayName:
                        presentTextAlert(title: "Display Name", current: pendingDisplayName, placeholder: "Hello") {
                            self.pendingDisplayName = $0
                            self.markDirty()
                        }
                    case .executable:
                        presentTextAlert(title: "Executable", current: pendingExecutable, placeholder: "hello") {
                            self.pendingExecutable = $0;
                            self.markDirty()
                        }
                    case .bundleIdentifier:
                        presentTextAlert(title: "Bundle Identifier", current: pendingBundleIdentifier, placeholder: "com.nyxian.example") {
                            self.pendingBundleIdentifier = $0;
                            self.markDirty()
                        }
                    case .bundleVersion:
                        presentTextAlert(title: "Bundle Version", current: pendingBundleVersion, placeholder: "1.0") {
                            self.pendingBundleVersion = $0;
                            self.markDirty()
                        }
                    case .bundleShortVersion:
                        presentTextAlert(title: "Bundle Short Version", current: pendingBundleShortVersion, placeholder: "1.0") {
                            self.pendingBundleShortVersion = $0;
                            self.markDirty()
                        }
                }
            case .deplyment:
                switch DeploymentRow(rawValue: indexPath.row)! {
                    case .deployVersion: pushVersionPicker(title: "Deployment Target",  current: pendingDeployVersion) { self.pendingDeployVersion = $0; self.markDirty() }
                }
            case .buildFlags:
                switch BuildFlagRow(rawValue: indexPath.row)! {
                    case .clangFlags: pushFlagsEditor(type: .clang)
                    case .swiftFlags: pushFlagsEditor(type: .swift)
                    case .linkerFlags: pushFlagsEditor(type: .linker)
                }
        }
    }

    private func pushVersionPicker(title: String, current: String, onPicked: @escaping (String) -> Void) {
        let vc = IOSVersionPickerViewController(title: title, selectedVersion: current)
        vc.onVersionSelected = { [weak self] version in
            onPicked(version)
            self?.tableView.reloadData()
        }
        navigationController?.pushViewController(vc, animated: true)
    }

    private func pushFlagsEditor(type: FlagType) {
        let flags: [String] = {
            switch type {
                case .clang:
                    return self.pendingClangFlags
                case .swift:
                    return self.pendingSwiftFlags
                case .linker:
                    return self.pendingLinkerFlags
            }
        }()
        
        let vc = FlagsEditViewController(flagType: type, flags: flags)
        vc.onFlagsChanged = { [weak self] updated in
            guard let self else { return }
            switch type {
                case .clang: self.pendingClangFlags = updated
                case .swift: self.pendingSwiftFlags = updated
                case .linker: self.pendingLinkerFlags = updated
            }
            self.markDirty()
        }
        navigationController?.pushViewController(vc, animated: true)
    }
    
    private func presentTextAlert(title: String, current: String, placeholder: String, completion: @escaping (String) -> Void) {
        let alert = UIAlertController(title: title, message: nil, preferredStyle: .alert)
        alert.addTextField { field in
            field.text = current
            field.placeholder = placeholder
            field.autocorrectionType = .no
            field.autocapitalizationType = .none
            field.clearButtonMode = .whileEditing
        }
        let save = UIAlertAction(title: "Save", style: .default) { _ in
            let value = alert.textFields?.first?.text?.trimmingCharacters(in: .whitespaces) ?? ""
            guard !value.isEmpty else { return }
            completion(value)
            self.tableView.reloadData()
        }
        alert.addAction(save)
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.preferredAction = save
        present(alert, animated: true)
    }

    @objc private func saveTapped() {
        project.projectConfig.dictionary["LDEDisplayName"] = pendingDisplayName
        project.projectConfig.dictionary["LDEExecutable"] = pendingExecutable
        project.projectConfig.dictionary["LDEBundleIdentifier"] = pendingBundleIdentifier
        project.projectConfig.dictionary["LDEMinimumVersion"] = pendingDeployVersion
        project.projectConfig.dictionary["LDECompilerFlags"] = pendingClangFlags
        project.projectConfig.dictionary["LDESwiftFlags"] = pendingSwiftFlags
        project.projectConfig.dictionary["LDELinkerFlags"] = pendingLinkerFlags
        project.projectConfig.dictionary["LDEBundleVersion"] = pendingBundleVersion
        project.projectConfig.dictionary["LDEBundleShortVersion"] = pendingBundleShortVersion
        project.projectConfig.save()
        isDirty = false
    }
    
    @objc private func closeTapped() {
        self.dismiss(animated: true)
    }
    
    private func markDirty() {
        isDirty = true
        tableView.reloadData()
    }

    private func subtitle(for flags: [String]) -> String {
        flags.isEmpty ? "None" : flags.joined(separator: " ")
    }
}
