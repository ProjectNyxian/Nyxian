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

class SettingsViewController: UIThemedTableViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        self.title = "Settings"
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
#if !JAILBREAK_ENV
#if DEBUG
        return 5
#else
        return 4
#endif // DEBUG
#else
        return 3
#endif /* !JAILBREAK_ENV */
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
            cell.imageView?.image = UIImage(systemName: "paintbrush.fill")
            cell.textLabel?.text = "Customization"
            break
#if !JAILBREAK_ENV
        case 2:
            cell.imageView?.image = UIImage(systemName: {
                if #available(iOS 17.0, *) {
                    return "checkmark.seal.text.page.fill"
                } else {
                    return "checkmark.seal.fill"
                }
            }())
            cell.textLabel?.text = "Certificate"
            break
#if DEBUG
        case 3:
            cell.imageView?.image = UIImage(systemName: "ant.fill")
            cell.textLabel?.text = "Kernel Log"
            break
        case 4:
            cell.imageView?.image = UIImage(systemName: "person.3.fill")
            cell.textLabel?.text = "Credits"
            break
#else
        case 5:
            cell.imageView?.image = UIImage(systemName: "person.3.fill")
            cell.textLabel?.text = "Credits"
            break
#endif // DEBUG
#else
        case 2:
            cell.imageView?.image = UIImage(systemName: "person.3.fill")
            cell.textLabel?.text = "Credits"
            break
#endif /* !JAILBREAK_ENV */
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
                return CustomizationViewController(style: .insetGrouped)
#if !JAILBREAK_ENV
            case 2:
                return CertificateController(style: .insetGrouped)
#if DEBUG
            case 3:
                return KernelLogViewController()
            case 4:
                return CreditsViewController(style: .insetGrouped)
#else
            case 5:
                return CreditsViewController(style: .insetGrouped)
#endif // DEBUG
#else
            case 2:
                return CreditsViewController(style: .insetGrouped)
#endif /* !JAILBREAK_ENV */
            default:
                return nil
            }
        }() else { return }

        navigationController?.pushViewController(viewController, animated: animated)
    }
    
    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        return "\(Bundle.main.infoDictionary?["CFBundleName"] as? String ?? "Nyxian") \"Falcon\" \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown") Beta (\(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"))"
    }
}
