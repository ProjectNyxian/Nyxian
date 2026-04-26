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

class ToolChainController: UIThemedTableViewController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        tableView.register(ToggleTableCell.self, forCellReuseIdentifier: ToggleTableCell.reuseIdentifier)
        
        self.title = "Toolchain"
        
        self.tableView.translatesAutoresizingMaskIntoConstraints = false
        self.tableView.rowHeight = UITableView.automaticDimension
    }
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 3
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 1
    }
    
    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        switch section {
        case 0:
            return "An incremental build compiles only the parts of the code that have changed, reducing build times by avoiding a full rebuild of the entire project."
        case 1:
            return "Threading in compilation refers to the compiler's ability to perform tasks in parallel like parsing, code generation, and optimization across multiple CPU threads to speed up the build process."
        case 2:
            return "This clears caches that were created for performance."
        default:
            return nil
        }
    }
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch section {
        case 0:
            return "Features"
        case 2:
            return "Actions"
        default:
            return nil
        }
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell: UITableViewCell
        
        switch indexPath.section {
        case 0:
            cell = tableView.dequeueReusableCell(withIdentifier: ToggleTableCell.reuseIdentifier, for: indexPath) as! ToggleTableCell
            (cell as! ToggleTableCell).configure(title: "Incremental Build", key: "LDEIncrementalBuild", defaultValue: true)
            break
        case 1:
            let optimCpuCount: Int = (Int)(LDEGetOptimalThreadCount())
            cell = StepperTableCell(title: "Use Threads", key: "cputhreads", defaultValue: optimCpuCount, minValue: 1, maxValue: optimCpuCount)
            break
        case 2:
            cell = UITableViewCell()
            cell.textLabel?.text = "Clear ModuleCache"
            break
        default:
            cell = UITableViewCell()
        }
        
        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if(indexPath.section == 2)
        {
            do {
                try FileManager.default.removeItem(at: NXBootstrap.shared().swiftModuleCacheURL)
            } catch {
                NotificationServer.NotifyUser(level: .error, notification: "failed to remove module cache: \(error.localizedDescription)")
            }
        }
        tableView.deselectRow(at: indexPath, animated: true)
    }
}
