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

class SettingsViewController: UIThemedTableViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        self.title = "Settings"
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 5
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
        cell.accessoryType = .disclosureIndicator

        switch indexPath.row {
        case 0:
            cell.imageView?.image = UIImage(systemName: {
                if #available(iOS 16.0, *) {
                    return "wrench.adjustable.fill"
                } else {
                    return "gearshape.2.fill"
                }
            }())
            cell.textLabel?.text = "Toolchain"
            break
        case 1:
            cell.imageView?.image = UIImage(systemName: "app.badge.fill")
            cell.textLabel?.text = "Applications"
            break
        case 2:
            cell.imageView?.image = UIImage(systemName: "paintbrush.fill")
            cell.textLabel?.text = "Customization"
            break
        case 3:
            cell.imageView?.image = UIImage(systemName: "checkmark.seal.text.page.fill")
            cell.textLabel?.text = "Certificate"
            break
        case 4:
            cell.imageView?.image = UIImage(systemName: "info")
            cell.textLabel?.text = "Info"
            break
        default:
            break
        }

        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        navigateToController(for: indexPath.row, animated: true)
    }

    private func navigateToController(for index: Int, animated: Bool) {
        guard let viewController: UIViewController = {
            switch index {
            case 0:
                return ToolChainController(style: .insetGrouped)
            case 1:
                return ApplicationManagementViewController(style: .insetGrouped)
            case 2:
                return CustomizationViewController(style: .insetGrouped)
            case 3:
                return CertificateController(style: .insetGrouped)
            case 4:
                return AppInfoViewController(style: .insetGrouped)
            default:
                return nil
            }
        }() else { return }

        navigationController?.pushViewController(viewController, animated: animated)
    }
}
