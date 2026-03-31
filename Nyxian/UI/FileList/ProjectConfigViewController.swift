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

import UIKit

enum FlagType {
    case compiler, linker
    
    var title: String {
        switch self {
            case .compiler: return "Compiler Flags"
            case .linker: return "Linker Flags"
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
    
    private var pendingCompilerFlags: [String]
    private var pendingLinkerFlags:   [String]
    private var isDirty = false {
        didSet { navigationItem.rightBarButtonItem?.isEnabled = isDirty }
    }

    init(project: NXProject) {
        self.project = project
        self.pendingCompilerFlags = project.projectConfig.dictionary["LDECompilerFlags"] as? [String] ?? []
        self.pendingLinkerFlags = project.projectConfig.dictionary["LDELinkerFlags"] as? [String] ?? []
        super.init(style: .insetGrouped)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        title = project.projectConfig.displayName
        
        let saveButton: UIBarButtonItem = UIBarButtonItem()
        saveButton.title = "Save"
        saveButton.target = self
        saveButton.action = #selector(saveTapped)
        saveButton.isEnabled = false
        navigationItem.rightBarButtonItem = saveButton
    }
    
    private enum Section: Int, CaseIterable {
        case buildFlags
    }

    private enum BuildFlagRow: Int, CaseIterable {
        case compilerFlags
        case linkerFlags

        var title: String {
            switch self {
                case .compilerFlags: return "Compiler Flags"
                case .linkerFlags: return "Linker Flags"
            }
        }
    }
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        Section.allCases.count
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch Section(rawValue: section)! {
            case .buildFlags: return BuildFlagRow.allCases.count
        }
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell") ?? UITableViewCell(style: .value1, reuseIdentifier: "Cell")
        switch Section(rawValue: indexPath.section)! {
            case .buildFlags:
                let row = BuildFlagRow(rawValue: indexPath.row)!
                cell.textLabel?.text = row.title
                cell.accessoryType = .disclosureIndicator

                switch row {
                    case .compilerFlags:
                        cell.detailTextLabel?.text = subtitle(for: pendingCompilerFlags)
                    case .linkerFlags:
                        cell.detailTextLabel?.text = subtitle(for: pendingLinkerFlags)
                }
        }

        return cell
    }

    override func tableView(_ tableView: UITableView,
                            titleForHeaderInSection section: Int) -> String? {
        switch Section(rawValue: section)! {
            case .buildFlags: return "Build Flags"
        }
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        switch Section(rawValue: indexPath.section)! {
            case .buildFlags:
                switch BuildFlagRow(rawValue: indexPath.row)! {
                    case .compilerFlags: pushFlagsEditor(type: .compiler)
                    case .linkerFlags: pushFlagsEditor(type: .linker)
                }
        }
    }

    private func pushFlagsEditor(type: FlagType) {
        let flags = type == .compiler ? pendingCompilerFlags : pendingLinkerFlags

        let vc = FlagsEditViewController(flagType: type, flags: flags)
        vc.onFlagsChanged = { [weak self] updated in
            guard let self else { return }
            switch type {
                case .compiler: self.pendingCompilerFlags = updated
                case .linker:   self.pendingLinkerFlags   = updated
            }
            self.isDirty = true
            self.tableView.reloadData()
        }

        navigationController?.pushViewController(vc, animated: true)
    }

    @objc private func saveTapped() {
        project.projectConfig.dictionary["LDECompilerFlags"] = pendingCompilerFlags
        project.projectConfig.dictionary["LDELinkerFlags"] = pendingLinkerFlags
        project.projectConfig.save()
        isDirty = false
    }

    private func subtitle(for flags: [String]) -> String {
        flags.isEmpty ? "None" : flags.joined(separator: " ")
    }
}
