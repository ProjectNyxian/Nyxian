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
import UniformTypeIdentifiers

class CertificateImporter: NXUITableViewController, UITextFieldDelegate {
    var textField: NXTextFieldTableCell?
    
    var cert: ComplexImportTableCell?
    
    let importButton: UIBarButtonItem = UIBarButtonItem()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.isModalInPresentation = true
        self.navigationController?.isModalInPresentation = true
        self.title = "Set Up Signing"
        
        importButton.title = "Import"
        importButton.target = self
        importButton.action = #selector(importButtonTapped)
        if #available(iOS 26.0, *) {
            importButton.style = .prominent
        }
        
        let cancelButton: UIBarButtonItem = UIBarButtonItem()
        cancelButton.title = "Cancel"
        cancelButton.target = self
        cancelButton.action = #selector(closeButtonTapped)
        
        navigationItem.rightBarButtonItem = importButton
        navigationItem.leftBarButtonItem = cancelButton
        
        self.tableView.translatesAutoresizingMaskIntoConstraints = false
        self.tableView.isScrollEnabled = false
        self.tableView.rowHeight = UITableView.automaticDimension
        
        if UIDevice.current.userInterfaceIdiom == .phone {
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
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 1
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell: UITableViewCell
        
        switch indexPath.section {
        case 0:
            cert = ComplexImportTableCell(parent: self)
            cell = cert!
            break
        case 1:
            textField = NXTextFieldTableCell(title: "Password", hint: "Enter certificate password", key: nil, defaultValue: "")
            textField!.textField.isSecureTextEntry = true
            textField!.textField.textContentType = .password
            cell = textField!
            break
        default:
            cell = UITableViewCell()
            break
        }
        
        return cell
    }
    
    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        switch section {
            case 1:
                return "The password and certificate is only used to sign apps on your behave, they stay entirely on your device."
            default:
                return nil
        }
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
    
    @objc func importButtonTapped() {
        let spinner = UIActivityIndicatorView(style: .medium)
        spinner.startAnimating()
        navigationItem.setRightBarButton(UIBarButtonItem(customView: spinner), animated: true)
        
        let cert = self.cert
        let password = self.textField?.text ?? ""
        
        DispatchQueue.global().asyncAfter(deadline: .now() + 1.0) { [weak self] in
            do {
                if let cert = cert,
                   let url = cert.url {
                    let p12Data: Data = try Data(contentsOf: url)
                    
                    LCUtils.validateCertificate(withCertificateData: p12Data, withPassword: password) { [weak self] status, someWords in
                        guard let self = self else { return }
                        if status == 0 {
                            LCUtils.certificateData = p12Data
                            LCUtils.certificatePassword = password
                            DispatchQueue.main.async {
                                self.dismiss(animated: true)
                            }
                            return
                        }
                        NXAlertDiagnosticPresenter.notifyUser(with: .error, withMessage: someWords ?? "A Unknown issue has happened importing the certificate, please report this issue. (error = \(status))", withDelay: 0.0)
                        DispatchQueue.main.async {
                            self.navigationItem.setRightBarButton(self.importButton, animated: true)
                        }
                    }
                } else {
                    guard let self = self else { return }
                    NXAlertDiagnosticPresenter.notifyUser(with: .error, withMessage: "Select a certificate first.", withDelay: 0.0)
                    DispatchQueue.main.async {
                        self.navigationItem.setRightBarButton(self.importButton, animated: true)
                    }
                }
            } catch {
                NXAlertDiagnosticPresenter.notifyUser(with: .error, withMessage: "Something went wrong importing the certificate! (\(error.localizedDescription))", withDelay: 0.0)
            }
        }
    }
    
    @objc func closeButtonTapped() {
        self.dismiss(animated: true)
    }
}
