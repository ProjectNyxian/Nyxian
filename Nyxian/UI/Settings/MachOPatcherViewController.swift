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

class MachOPatcherViewController: UIThemedTableViewController {
    var path: String
    var entitlements: PEEntitlement
    let applyHandler: () -> Void
    
    struct EntitlementRow {
        let title: String
        let detail: String
        let flag: PEEntitlement
    }

    struct EntitlementSection {
        let title: String
        let rows: [EntitlementRow]
    }

    private let sections: [EntitlementSection] = [
        EntitlementSection(title: "Task & Process Access", rows: [
            EntitlementRow(title: "Get Task Allowed", detail: "Allows other entitled processes to obtain the process's task port.", flag: .getTaskAllowed),
            EntitlementRow(title: "Task for Pid", detail: "Allows obtaining the task port of other processes by pid.", flag: .taskForPid),
            EntitlementRow(title: "Process Enumeration", detail: "Allows listing all running processes in nyxian.", flag: .processEnumeration),
        ]),
        EntitlementSection(title: "Process Control", rows: [
            EntitlementRow(title: "Process Kill", detail: "Allows sending signals to other processes.", flag: .processKill),
            EntitlementRow(title: "Process Spawn", detail: "Allows spawning arbitrary processes.", flag: .processSpawn),
            EntitlementRow(title: "Process Spawn (Signed Only)", detail: "Spawn is restricted to signed binaries only.", flag: .processSpawnSignedOnly),
            EntitlementRow(title: "Process Elevate", detail: "Allows elevating ucred privileges.", flag: .processElevate),
            EntitlementRow(title: "Inherit Entitlements on Spawn", detail: "Child processes inherites the parent processes entitlements.", flag: .processSpawnInheriteEntitlements),
        ]),
        EntitlementSection(title: "Launch Services", rows: [
            EntitlementRow(title: "Start Service", detail: "Allows starting launch services. (unimplemented)", flag: .launchServicesStart),
            EntitlementRow(title: "Stop Service", detail: "Allows stopping launch services. (unimplemented)", flag: .launchServicesStop),
            EntitlementRow(title: "Toggle Service", detail: "Allows toggling launch services on or off. (unimplemented)", flag: .launchServicesToggle),
            EntitlementRow(title: "Get Service Endpoint", detail: "Allows reading the endpoint of a launch service.", flag: .launchServicesGetEndpoint),
            EntitlementRow(title: "Set Service Endpoint", detail: "Allows overriding the endpoint of a launch service that is not registerd.", flag: .launchServicesSetEndpoint),
        ]),
        EntitlementSection(title: "Host & Credentials", rows: [
            EntitlementRow(title: "Host Manager", detail: "Grants overriding host properties such as hostname.", flag: .hostManager),
            EntitlementRow(title: "Credentials Manager", detail: "Allows managing users and groups. (unimplemented)", flag: .credentialsManager),
        ]),
        EntitlementSection(title: "Security & Runtime", rows: [
            EntitlementRow(title: "Platform Process", detail: "Marks the process as a platform process.", flag: .platform),
            EntitlementRow(title: "Platform Root", detail: "Starts a process that is platformized as root user, meant as a security feature to prevent privelege escalations.", flag: .platformRoot),
            EntitlementRow(title: "DYLD Hide LiveProcess", detail: "Hides the PEProcesses trampoline process loader.", flag: .dyldHideLiveProcess),
        ]),
    ]

    init(machOPath path: String, applyHandler: @escaping () -> Void) {
        self.path = path
        self.entitlements = PEContainer.shared().entitlementForExecutable(atPath: path)
        self.applyHandler = applyHandler
        super.init(style: .insetGrouped)
    }

    @MainActor required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "\((path as NSString).lastPathComponent)'s Entitlements"
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "EntitlementCell")
        let barButton = UIBarButtonItem()
        barButton.title = "Apply"
        barButton.target = self
        barButton.action = #selector(applyTapped)
        navigationItem.rightBarButtonItem = barButton
    }

    override func numberOfSections(in tableView: UITableView) -> Int {
        sections.count
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        sections[section].rows.count
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        sections[section].title
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "EntitlementCell", for: indexPath)
        let row = sections[indexPath.section].rows[indexPath.row]
        
        cell.textLabel?.text = row.title
        cell.detailTextLabel?.text = row.detail
        cell.selectionStyle = .none
        
        if cell.detailTextLabel == nil {
            let subtitleCell = UITableViewCell(style: .subtitle, reuseIdentifier: nil)
            subtitleCell.textLabel?.text = row.title
            subtitleCell.detailTextLabel?.text = row.detail
            subtitleCell.detailTextLabel?.textColor = .secondaryLabel
            subtitleCell.detailTextLabel?.numberOfLines = 2
            subtitleCell.selectionStyle = .none
            let toggle = makeToggle(for: row, indexPath: indexPath)
            subtitleCell.accessoryView = toggle
            return subtitleCell
        }
        
        cell.detailTextLabel?.text = row.detail
        cell.detailTextLabel?.textColor = .secondaryLabel
        cell.detailTextLabel?.numberOfLines = 2
        
        let toggle = makeToggle(for: row, indexPath: indexPath)
        cell.accessoryView = toggle
        
        return cell
    }
    
    
    override func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        cell.detailTextLabel?.numberOfLines = 2
    }
    
    override func tableView(_ tableView: UITableView, estimatedHeightForRowAt indexPath: IndexPath) -> CGFloat { 60 }
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        UITableView.automaticDimension
    }

    private func makeToggle(for row: EntitlementRow, indexPath: IndexPath) -> UISwitch {
        let toggle = UIThemedSwitch()
        toggle.isOn = entitlements.contains(row.flag)
        toggle.tag = indexPath.section * 1000 + indexPath.row   // encode position
        toggle.addTarget(self, action: #selector(toggleChanged(_:)), for: .valueChanged)
        return toggle
    }

    @objc private func toggleChanged(_ sender: UISwitch) {
        let sectionIndex = sender.tag / 1000
        let rowIndex = sender.tag % 1000
        let flag = sections[sectionIndex].rows[rowIndex].flag

        if sender.isOn {
            entitlements.insert(flag)
        } else {
            entitlements.remove(flag)
        }
    }
    
    @objc private func applyTapped() {
        PEContainer.shared().setEntitlements(entitlements, forExecutableAtPath: path)
        self.applyHandler()
        self.dismiss(animated: true)
    }
}
