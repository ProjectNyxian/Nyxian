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
import UniformTypeIdentifiers

class CertificateImporter: UIThemedTableViewController, UITextFieldDelegate {
    var textField: NXTextFieldTableCell?
    
    var cert: ImportTableCell?
    let callback: () -> Void
    
    let sectionTitles: [String] = [
        "Certificate",
        "Password"
    ]
    
    init(style: UITableView.Style,
         callback: @escaping () -> Void) {
        self.callback = callback
        super.init(style: style)
    }
    
    @MainActor required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.title = "Import Certificate"
        
        let barbutton: UIBarButtonItem = UIBarButtonItem()
        barbutton.title = "Submit"
        barbutton.target = self
        barbutton.action = #selector(importButton)
        navigationItem.rightBarButtonItem = barbutton
        
        self.tableView.translatesAutoresizingMaskIntoConstraints = false
        self.tableView.isScrollEnabled = false
        self.tableView.rowHeight = UITableView.automaticDimension
        
        if UIDevice.current.userInterfaceIdiom == .phone {
            if #available(iOS 16.0, *) {
                if let sheet = self.navigationController?.sheetPresentationController {
                    DispatchQueue.main.async {
                        sheet.animateChanges {
                            sheet.detents = [
                                .custom { context in
                                    let contentHeight = self.tableView.contentSize.height + 50
                                    return contentHeight
                                }
                            ]
                        }
                    }
                }
            }
        }
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 1
    }
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return sectionTitles[section]
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell: UITableViewCell
        
        switch indexPath.section {
        case 0:
            cert = ImportTableCell(parent: self)
            cell = cert!
            break
        case 1:
            textField = NXTextFieldTableCell(title: "", hint: "i.e 123456", key: nil, defaultValue: "")
            cell = textField!
            break
        default:
            cell = UITableViewCell()
            break
        }
        
        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        self.tableView.deselectRow(at: indexPath, animated: true)
    }
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 2
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
    
    @objc func importButton() {
        do {
            if let cert = cert,
               let url = cert.url {
                let p12Data: Data = try Data(contentsOf: url)
                let appGroupUserDefault = UserDefaults.init(suiteName: LCUtils.appGroupID()) ?? UserDefaults.standard
                appGroupUserDefault.set(p12Data, forKey: "LCCertificateData")
                appGroupUserDefault.set(textField?.text ?? "", forKey: "LCCertificatePassword")
                appGroupUserDefault.set(NSDate.now, forKey: "LCCertificateUpdateDate")
                UserDefaults.standard.set(LCUtils.appGroupID(), forKey: "LCAppGroupID")
            }
        } catch {
            NotificationServer.NotifyUser(level: .error, notification: "Something went wrong importing the CertBlob! \(error.localizedDescription)")
        }
        
        self.dismiss(animated: true)
        
        callback()
    }
}
