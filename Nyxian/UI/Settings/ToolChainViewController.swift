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

import UIKit
import CoreCompiler

class ToolChainViewController: NXUITableViewController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        tableView.register(ToggleTableCell.self, forCellReuseIdentifier: ToggleTableCell.reuseIdentifier)
        
        self.title = "Toolchain"
        
        self.tableView.translatesAutoresizingMaskIntoConstraints = false
        self.tableView.rowHeight = UITableView.automaticDimension
    }
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 4
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return (section == 3) ? 2 : 1
    }
    
    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        switch section {
        case 0:
            return "An incremental build compiles only the parts of the code that have changed, reducing build times by avoiding a full rebuild of the entire project."
        case 1:
            return "Using a remote daemon process means that Nyxian does not compile the code directly, it hands it over to a remote daemon process that still runs on your device, which means that if LLVM crashes it will not take Nyxian with it and also it would gurantee that the memory is destroyed after compilation and no broken LLVM state is still present."
        case 2:
            return "Threading in compilation refers to the compiler's ability to perform tasks in parallel like parsing, code generation, and optimization across multiple CPU threads to speed up the build process."
        case 3:
            return "This clears caches that were created for performance."
        default:
            return nil
        }
    }
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch section {
        case 0:
            return "Features"
        case 3:
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
            cell = tableView.dequeueReusableCell(withIdentifier: ToggleTableCell.reuseIdentifier, for: indexPath) as! ToggleTableCell
            (cell as! ToggleTableCell).configure(title: "Remote Compilation Daemon", key: "LDERemoteCompileService", defaultValue: true)
            break
        case 2:
            let optimCpuCount: Int = (Int)(CCGetMaximumPerformanceCores())
            cell = StepperTableCell(title: "Threads", key: "cputhreads", defaultValue: optimCpuCount, minValue: 1, maxValue: optimCpuCount)
            break
        default:
            switch(indexPath.row) {
            case 0:
                cell = UITableViewCell()
                cell.textLabel?.text = "Clear Module Cache"
                break
            default:
                cell = UITableViewCell()
                cell.textLabel?.text = "Clear Project Cache"
                break
            }
            break
        }
        
        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if(indexPath.section == 3) {
            // TODO: use the indication popup for cache clearing
            switch(indexPath.row) {
            case 0:
                NXBootstrap.shared().clear(NXBootstrap.shared().swiftModuleCacheURL)
                break
            default:
                NXBootstrap.shared().clear(NXBootstrap.shared().cacheURL)
                break
            }
            try? FileManager.default.removeItem(at: NXBootstrap.shared().swiftModuleCacheURL)
        }
        tableView.deselectRow(at: indexPath, animated: true)
    }
}
