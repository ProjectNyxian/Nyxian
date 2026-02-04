/*
 Copyright (C) 2025 cr4zyengineer

 This file is part of Nyxian.

 Nyxian is free software: you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.

 Nyxian is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 GNU General Public License for more details.

 You should have received a copy of the GNU General Public License
 along with Nyxian. If not, see <https://www.gnu.org/licenses/>.
*/

import UIKit

class ToolChainController: UIThemedTableViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.title = "Toolchain"
        
        self.tableView.register(UITableViewCell.self, forCellReuseIdentifier: "Cell")
        self.tableView.translatesAutoresizingMaskIntoConstraints = false
        self.tableView.rowHeight = UITableView.automaticDimension
    }
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        #if !JAILBREAK_ENV
        return 2
        #else // !JAILBREAK_ENV
        if #available(iOS 16.0, *) {
            return 3
        } else {
            return 2
        }
        #endif
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
            return "This feature allows apps to be opened inside of nyxian instead of invoking the LSApplicationWorkspace API."
        default:
            return nil
        }
    }
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch section {
        case 0:
            return "Features"
        default:
            return nil
        }
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell: UITableViewCell
        
        switch indexPath.section {
        case 0:
            cell = SwitchTableCell(title: "Incremental Build", key: "LDEIncrementalBuild", defaultValue: true)
            break
        case 1:
            let optimCpuCount: Int = (Int)(LDEGetOptimalThreadCount())
            cell = StepperTableCell(title: "Use Threads", key: "cputhreads", defaultValue: optimCpuCount, minValue: 1, maxValue: optimCpuCount)
            break
        case 2:
            cell = SwitchTableCell(title: "Open app inside Nyxian", key: "LDEOpenAppInsideNyxian", defaultValue: true)
        default:
            cell = UITableViewCell()
        }
        
        return cell
    }
}
