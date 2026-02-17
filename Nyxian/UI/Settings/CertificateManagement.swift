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

class CertificateController: UITableViewController {
    var certificateStateCell: UITableViewCell?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.title = "Certificate"
        self.tableView.rowHeight = UITableView.automaticDimension
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 2
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if indexPath.row == 1 {
            let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
            cell.textLabel?.text = "Import Certificate"
            cell.textLabel?.textColor = .label
            cell.textLabel?.textAlignment = .left
            cell.selectionStyle = .default
            return cell
        } else {
            let cell: UITableViewCell = UITableViewCell()
            certificateStateCell = cell
            updateCertificateState()
            return cell
        }
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if indexPath.row == 1 {
            // run your action
            importCertificate()
        }
        tableView.deselectRow(at: indexPath, animated: true)
    }
    
    func importCertificate() {
        let importPopup: CertificateImporter = CertificateImporter(style: .insetGrouped) { [weak self] in
            guard let self = self else { return }
            self.updateCertificateState()
        }
        let importSettings: UINavigationController = UINavigationController(rootViewController: importPopup)
        importSettings.modalPresentationStyle = .formSheet
        
        // dynamic size
        if UIDevice.current.userInterfaceIdiom == .phone {
            if #available(iOS 16.0, *) {
                if let sheet = importSettings.sheetPresentationController {
                    sheet.animateChanges {
                        sheet.detents = [
                            .custom { _ in
                                return 200
                            }
                        ]
                    }
                    
                    sheet.prefersGrabberVisible = true
                }
            }
        }
        
        self.present(importSettings, animated: true)
    }
    
    func updateCertificateState() {
        if let certificateStateCell = certificateStateCell {
            LCUtils.validateCertificate { status, experiationDate, someWords in
                DispatchQueue.main.async {
                    certificateStateCell.textLabel?.textColor = status == 0 ? UIColor.systemGreen : UIColor.systemRed
                    certificateStateCell.textLabel?.text = status == 0 ? "Certificate Valid Till \(experiationDate?.formatted() ?? "Unknown")" : "Certificate Invalid"
                    certificateStateCell.selectionStyle = .none
                }
            }
        }
    }
}
