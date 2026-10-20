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

extension UTType {
    static var ipa: UTType {
        UTType(filenameExtension: "ipa") ?? .zip
    }
    static var tipa: UTType {
        UTType(importedAs: "com.cr4zy.nyxian.tipa", conformingTo: .zip)
    }
    static var nipa: UTType {
        UTType(importedAs: "com.cr4zy.nyxian.nipa", conformingTo: .zip)
    }
}

class ApplicationManagementViewController: NXUITableViewController, UITextFieldDelegate, UIDocumentPickerDelegate, UIAdaptivePresentationControllerDelegate, LDEApplicationWorkspaceObserver {
    
    var applications: [LDEApplicationObject] = []
    
    override init(style: UITableView.Style) {
        super.init(style: style)
    }
    
    @MainActor required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.tableView.register(ProjectTableCell.self, forCellReuseIdentifier: ProjectTableCell.reuseIdentifier)
        LDEApplicationWorkspace.shared().ping()
        self.title = "Applications"
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(title: nil, image: UIImage(systemName: "square.and.arrow.down.fill"), target: self, action: #selector(plusButtonPressed))
        
        DispatchQueue.global().async {
            self.applications = LDEApplicationWorkspace.shared().allApplicationObjects()
            LDEApplicationWorkspace.shared().add(self)
            DispatchQueue.main.async {
                self.tableView.reloadData()
            }
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.applications.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let application: LDEApplicationObject = self.applications[indexPath.row]
        let cell: ProjectTableCell = self.tableView.dequeueReusableCell(withIdentifier: ProjectTableCell.reuseIdentifier) as! ProjectTableCell
        cell.configure(displayName: application.localizedName, bundleIdentifier: application.bundleIdentifier, appIcon: application.icon, darkAppIcon: application.darkIcon, showArrow: false)
        return cell
    }
    
    override func tableView(_ tableView: UITableView, contextMenuConfigurationForRowAt indexPath: IndexPath, point: CGPoint) -> UIContextMenuConfiguration? {
        let application = self.applications[indexPath.row]
        
        return UIContextMenuConfiguration(identifier: nil, previewProvider: nil) { [weak self, weak application] _ in
            // MARK: Open Menu
            let openMenu: UIMenuElement = UIAction(title: "Open", image: UIImage(systemName: "arrow.up.right.square.fill")) { _ in
                guard let application = application else { return }
                PEProcessManager.shared().spawnProcess(withBundleIdentifier: application.bundleIdentifier, withItems: [:], withKernelSurfaceProcess: nil, doRestartIfRunning: false)
            }
            
            var menu: [UIMenuElement] = [openMenu]
            
            let clearContainerAction = UIAction(title: "Clear Data Container", image: UIImage(systemName: "arrow.up.trash.fill")) { _ in
                guard let application = application else { return }
                if let process = PEProcessManager.shared().process(forBundleIdentifier: application.bundleIdentifier) {
                    // It is unsafe to send SIGKILL, because data container is wiped
                    process.sendSignal(SIGKILL)
                }
                LDEApplicationWorkspace.shared().clearContainer(forBundleID: application.bundleIdentifier)
            }
            
            let deleteAction = UIAction(title: "Delete", image: UIImage(systemName: "trash.fill"), attributes: .destructive) { [weak self] _ in
                guard let self = self,
                      let application = application else { return }
                PEProcessManager.shared().closeIfRunning(usingBundleIdentifier: application.bundleIdentifier)
                if(LDEApplicationWorkspace.shared().deleteApplication(withBundleID: application.bundleIdentifier)) {
                    if let index = self.applications.firstIndex(where: { $0.bundleIdentifier == application.bundleIdentifier }) {
                        self.applications.remove(at: index)
                        self.tableView.deleteRows(at: [IndexPath(row: index, section: 0)], with: .automatic)
                    }
                }
            }
            
            let browseBundle = UIAction(title: "Browse Bundle", image: UIImage(systemName: "arrow.forward.folder.fill")) { [weak self] _ in
                guard let self = self,
                      let application = application else { return }
                
                self.navigationController?.pushViewController(FileListViewController(isSublink: true, path: application.bundlePath), animated: true)
            }
            
            let browseContainer = UIAction(title: "Browse Container", image: UIImage(systemName: "arrow.forward.folder.fill")) { [weak self] _ in
                guard let self = self,
                      let application = application else { return }
                
                self.navigationController?.pushViewController(FileListViewController(isSublink: true, path: application.containerPath), animated: true)
            }
            
            // TODO: add a info panel for it like in files Get Info
            menu.append(UIMenu(options: .displayInline, children: [browseBundle, browseContainer]))
            menu.append(UIMenu(options: .displayInline, children: [clearContainerAction, deleteAction]))
            
            return UIMenu(title: "", children: menu)
        }
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let application = self.applications[indexPath.row]
        let processIdentifier: pid_t = PEProcessManager.shared().spawnProcess(withBundleIdentifier: application.bundleIdentifier, withItems: [:], withKernelSurfaceProcess: nil, doRestartIfRunning: false)
        if processIdentifier < 0 {
            NXAlertDiagnosticPresenter.notifyUser(with: .error, withMessage: "\"\(application.localizedName ?? "Unknown")\" Is No Longer Available", withDelay: 0.0)
        }
    }
    
    @objc func plusButtonPressed() {
        let documentPicker: UIDocumentPickerViewController = UIDocumentPickerViewController(forOpeningContentTypes: [.ipa,.tipa,.nipa], asCopy: true)
        documentPicker.delegate = self
        documentPicker.modalPresentationStyle = .formSheet
        self.present(documentPicker, animated: true)
    }
    
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        let alert = UIAlertController(title: nil, message: "Validating", preferredStyle: .alert)
        
        let activityIndicator = UIActivityIndicatorView(style: .medium)
        activityIndicator.translatesAutoresizingMaskIntoConstraints = false
        activityIndicator.startAnimating()
        
        alert.view.addSubview(activityIndicator)
        
        NSLayoutConstraint.activate([
            activityIndicator.centerYAnchor.constraint(equalTo: alert.view.centerYAnchor),
            activityIndicator.trailingAnchor.constraint(equalTo: alert.view.trailingAnchor, constant: -20)
        ])
        
        self.present(alert, animated: true)
        
        DispatchQueue.global().async {
            do {
                guard let selectedURL = urls.first else { return }
                
                let fileManager = FileManager.default
                let tempRoot = NSTemporaryDirectory()
                let workRoot = (tempRoot as NSString).appendingPathComponent(UUID().uuidString)
                let unzipRoot = (workRoot as NSString).appendingPathComponent("unzipped")
                let payloadDir = (unzipRoot as NSString).appendingPathComponent("Payload")
                
                guard ((try? fileManager.createDirectory(atPath: unzipRoot, withIntermediateDirectories: true)) != nil) else { return }
                guard unzipArchiveAtPath(selectedURL.path, unzipRoot) else { return }
                let contents: [String] = try FileManager.default.contentsOfDirectory(atPath: payloadDir)
                
                guard let appBundlePathComponent = contents.first(where: { ($0 as NSString).pathExtension == "app" }) else {
                    alert.dismiss(animated: true) {
                        NXAlertDiagnosticPresenter.notifyUser(with: .error, withMessage: "Failed to install application: no .app bundle found", withDelay: 0.0)
                    }
                    return
                }
                
                let appBundleFullPath = payloadDir.appending("/\(appBundlePathComponent)")
                
                guard let bundle = Bundle(path: appBundleFullPath) else {
                    alert.dismiss(animated: true) {
                        NXAlertDiagnosticPresenter.notifyUser(with: .error, withMessage: "Failed to install application: invalid bundle path", withDelay: 0.0)
                    }
                    return
                }
                
                guard let executablePath = bundle.executablePath else {
                    alert.dismiss(animated: true) {
                        NXAlertDiagnosticPresenter.notifyUser(with: .error, withMessage: "Failed to install application: invalid executable path", withDelay: 0.0)
                    }
                    return
                }
                
                var final: [String: Any] = [:]
                var isRootCATrusted: Bool = false;
                if let executablePath = bundle.executablePath {
                    var ent: [String: Any] = [:]
                    var trust_nxt2 = ksurface_nxt2()
                    let kr: kern_return_t = trust_nxt2_read(bundle.executablePath, &trust_nxt2)
                    if(kr != 0) {
                        if trust_nxt2.entitlements != nil {
                            trust_nxt2.entitlements.release()
                        }
                    } else {
                        let unmanagedDict: Unmanaged<CFDictionary>? = trust_nxt2.entitlements
                        if let cfDict = unmanagedDict?.takeRetainedValue() {
                            let nsDict = cfDict as NSDictionary
                            if let swiftDict = nsDict as? [String: Any] {
                                ent = swiftDict
                                withUnsafeBytes(of: trust_nxt2.cdhash) { rawBuffer in
                                    let uint8Pointer = rawBuffer.bindMemory(to: UInt8.self).baseAddress!
                                    if trust_nxt2.isValid && trust_nxt2.isCdHashValid && CDHashMatchesCodeDirectoryOfPath(executablePath, uint8Pointer) == KERN_SUCCESS {
                                        isRootCATrusted = trust_nxt2.isSigned || trust_nxt2.needsResign
                                    }
                                }
                            }
                        }
                    }
                    
                    if !ent.isEmpty {
                        final = ent
                    } else {
                        var appleEnt: [String: Any] = [:]
                        var outError: OSStatus = 0
                        let unmanagedDict: Unmanaged<CFDictionary>? = CopyAppleCSEntitlementsForPath(executablePath as CFString, &outError);
                        if let cfDict = unmanagedDict?.takeRetainedValue() {
                            let nsDict = cfDict as NSDictionary
                            if let swiftDict = nsDict as? [String: Any] {
                                appleEnt = swiftDict
                            }
                        }
                        
                        var extractedEnt: [String: Any] = [:]
                        let unmanagedDict2: Unmanaged<CFDictionary>? = ExtractNXT2OutOfAppleCSEntitlements(appleEnt as CFDictionary);
                        if let cfDict = unmanagedDict2?.takeRetainedValue() {
                            let nsDict = cfDict as NSDictionary
                            if let swiftDict = nsDict as? [String: Any] {
                                extractedEnt = swiftDict
                            }
                        }
                        final = extractedEnt
                    }
                }
                
                // Gated :3
                let proceedWithInstall: () -> Void = {
                    DispatchQueue.main.async {
                        let alert = UIAlertController(title: nil, message: "Installing", preferredStyle: .alert)
                        
                        let activityIndicator = UIActivityIndicatorView(style: .medium)
                        activityIndicator.translatesAutoresizingMaskIntoConstraints = false
                        activityIndicator.startAnimating()
                        
                        alert.view.addSubview(activityIndicator)
                        
                        NSLayoutConstraint.activate([
                            activityIndicator.centerYAnchor.constraint(equalTo: alert.view.centerYAnchor),
                            activityIndicator.trailingAnchor.constraint(equalTo: alert.view.trailingAnchor, constant: -20)
                        ])
                        
                        self.present(alert, animated: true)
                        
                        checkSigningSetup() { codeSignigSetup in
                            if !codeSignigSetup {
                                alert.dismiss(animated: true)
                                return
                            }
                            
                            DispatchQueue.global().async {
                                LCUtils.signAppBundle(withZSign: bundle.bundleURL) { result, error in
                                    if result {
                                        PEProcessManager.shared().closeIfRunning(usingBundleIdentifier: bundle.bundleIdentifier)
                                        
                                        trust_nxt2_sign((executablePath as NSString).utf8String, final as CFDictionary, true, nil)
                                        
                                        if LDEApplicationWorkspace.shared().installApplication(atBundlePath: bundle.bundleURL.path) {
                                            DispatchQueue.main.async {
                                                alert.dismiss(animated: true)
                                            }
                                        } else {
                                            DispatchQueue.main.async {
                                                alert.dismiss(animated: true) {
                                                    NXAlertDiagnosticPresenter.notifyUser(with: .error, withMessage: "Failed to sign or install application.", withDelay: 0.0)
                                                }
                                            }
                                        }
                                    } else {
                                        DispatchQueue.main.async {
                                            alert.dismiss(animated: true) {
                                                NXAlertDiagnosticPresenter.notifyUser(with: .error, withMessage: "Failed to sign or install application.", withDelay: 0.0)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                
                // The app indeed wants something bruh
                DispatchQueue.main.async {
                    alert.dismiss(animated: true) {
                        if !final.isEmpty, !isRootCATrusted {
                            let displayName = bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String ?? bundle.object(forInfoDictionaryKey: "CFBundleName") as? String ?? "Unknown"
                            let alert = UIAlertController(
                                title: "Install \"\(displayName)\"?",
                                message: nil,
                                preferredStyle: .alert
                            )
                            
                            let fullMessage = NSMutableAttributedString()
                            fullMessage.append(KSurfaceNXT2CreateEntitlementSummary(final))
                            alert.setValue(fullMessage, forKey: "attributedMessage")
                            
                            alert.addAction(UIAlertAction(title: "Install", style: .default) { _ in
                                DispatchQueue.global().async {
                                    _ = proceedWithInstall()
                                }
                            })
                            
                            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
                            
                            self.present(alert, animated: true)
                        } else {
                            DispatchQueue.global().async {
                                _ = proceedWithInstall()
                            }
                        }
                    }
                }
                
            } catch {
                NXAlertDiagnosticPresenter.notifyUser(with: .error, withMessage: "Failed to install application: \(error.localizedDescription)", withDelay: 0.0)
            }
        }
    }
    
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        if #available(iOS 26.0, *) {
            return 80
        } else {
            return 70
        }
    }
    
    func applicationInitialPopulationDone() {
        self.applications = LDEApplicationWorkspace.shared().allApplicationObjects()
    }
    
    func applicationWasInstalled(_ app: LDEApplicationObject!) {
        DispatchQueue.main.async {
            if let index = self.applications.firstIndex(of: app) {
                self.applications[index] = app
                self.tableView.reloadRows(
                    at: [IndexPath(row: index, section: 0)],
                    with: .automatic
                )
            } else {
                self.applications.append(app)
                let index = self.applications.count - 1
                self.tableView.insertRows(
                    at: [IndexPath(row: index, section: 0)],
                    with: .automatic
                )
            }
        }
    }
    
    func application(withBundleIdentifierWasUninstalled bundleIdentifier: String!) {
        DispatchQueue.main.async {
            let temp = LDEApplicationObject()
            temp.bundleIdentifier = bundleIdentifier
            if let index = self.applications.firstIndex(of: temp) {
                self.applications.remove(at: index)
                self.tableView.deleteRows(
                    at: [IndexPath(row: index, section: 0)],
                    with: .automatic
                )
            }
        }
    }
    
    @objc func removeAllApplications() {
        self.applications = []
        DispatchQueue.main.async {
            self.tableView.reloadData()
        }
    }
}
