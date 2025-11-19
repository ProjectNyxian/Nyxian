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
import Runestone

class CustomizationViewController: UIThemedTableViewController {
    var textField: UITextField?
    
    var currentIconName: String {
        UIApplication.shared.alternateIconName ?? "Default"
    }
    
    var icons: [String] = [
        "Default",
        "Drawn",
        "Nyxcat",
        "Nyxcat2",
        "Nyxcat3"
    ]
    
    var themePreviewCell: ThemePickerPreviewCell?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.title = "Customization"
    }
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch section {
        case 0:
            return "Credentials"
        case 1:
            return "Themes"
        case 2:
            return "Icons"
        default:
            return nil
        }
    }
    
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        switch indexPath.section {
        case 1:
            return (indexPath.row == 0) ? 150 : 44
        case 2:
            return 65
        default:
            return 44
        }
    }
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 3
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch section {
        case 0:
            return 2
        case 1:
            return 7
        case 2:
            return self.icons.count
        default:
            return 2
        }
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell: UITableViewCell
        
        if indexPath.section == 0 {
            if indexPath.row == 0 {
                cell = TextFieldTableCell(title: "Username", key: "LDEUsername", defaultValue: "Anonym")
            } else {
                cell = TextFieldTableCellHandler(title: "Hostname", value: UserDefaults.standard.string(forKey: "LDEHostname") ?? "localhost")
                (cell as! TextFieldTableCellHandler).writeHandler = { text in
                    UserDefaults.standard.set(text, forKey: "LDEHostname")
                    kern_sethostname(text)
                }
            }
        } else if indexPath.section == 1 {
            if indexPath.row == 0 {
                themePreviewCell = ThemePickerPreviewCell()
                cell = themePreviewCell!
                (cell as! ThemePickerPreviewCell).populate(with: ThemePickerPreviewCell.ViewModel(theme: getCurrentSelectedTheme(), text: """
#include <stdio.h>

int main(void)
{
\tprintf(\"Hello, World\\n\");
\treturn 0;
}
"""))
            } else if indexPath.row == 1 {
                cell = PickerTableCell(options: ["NyxianLDE", "Solarized"], title: "Theme", key: "LDETheme", defaultValue: 0)
                (cell as! PickerTableCell).callback = { selected in
                    self.themePreviewCell!.switchTheme(theme: themes[selected])
                    RevertUI()
                }
            } else if indexPath.row == 2 {
                cell = StepperTableCell(title: "Font Size", key: "LDEFontSize", defaultValue: 10, minValue: 8, maxValue: 15)
            } else if indexPath.row == 3 {
                cell = SwitchTableCell(title: "Show Line Numbers", key: "LDEShowLineNumbers", defaultValue: true)
            } else if indexPath.row == 4 {
                cell = SwitchTableCell(title: "Show Spaces", key: "LDEShowSpaces", defaultValue: true)
            } else if indexPath.row == 5 {
                cell = SwitchTableCell(title: "Wrap Lines", key: "LDEWrapLines", defaultValue: true)
            } else {
                cell = SwitchTableCell(title: "Show Line Breaks", key: "LDEShowLineBreaks", defaultValue: true)
            }
        } else {
            cell = UITableViewCell(style: .default, reuseIdentifier: nil)
            let iconName = icons[indexPath.row]
            
            if let image = UIImage(named: {
                if #available(iOS 18.0, *) {
                    return "IconPreview\(iconName)"
                } else {
                    return "IconPreview\(iconName)Old"
                }
            }()) {
                let customImageView = UIImageView(image: image)
                customImageView.layer.cornerRadius = 10
                customImageView.layer.masksToBounds = true
                customImageView.translatesAutoresizingMaskIntoConstraints = false
                customImageView.contentMode = .scaleAspectFit
                cell.contentView.addSubview(customImageView)
                
                NSLayoutConstraint.activate([
                    customImageView.leadingAnchor.constraint(equalTo: cell.contentView.leadingAnchor, constant: 16),
                    customImageView.centerYAnchor.constraint(equalTo: cell.contentView.centerYAnchor),
                    customImageView.widthAnchor.constraint(equalToConstant: 50),
                    customImageView.heightAnchor.constraint(equalToConstant: 50)
                ])
            }

            cell.textLabel?.text = iconName
            cell.textLabel?.font = UIFont.systemFont(ofSize: 14, weight: .bold)
            cell.textLabel?.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                cell.textLabel!.centerYAnchor.constraint(equalTo: cell.contentView.centerYAnchor),
                cell.textLabel!.leadingAnchor.constraint(equalTo: cell.contentView.leadingAnchor, constant: 80)
            ])
            
            if iconName == currentIconName {
                cell.accessoryType = .checkmark
            } else {
                cell.accessoryType = .none
            }
        }

        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard indexPath.section == 2 else { return }

        let iconName = icons[indexPath.row]
        
        if iconName == "Default" {
            UIApplication.shared.setAlternateIconName(nil)
        } else {
            UIApplication.shared.setAlternateIconName(iconName)
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            tableView.reloadSections(IndexSet(integer: 2), with: .automatic)
        }
    }

}
