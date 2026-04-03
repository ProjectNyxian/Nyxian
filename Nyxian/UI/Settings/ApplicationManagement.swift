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
import UniformTypeIdentifiers

#if !JAILBREAK_ENV

extension UTType {
    static var ipa: UTType {
        UTType(importedAs: "com.apple.itunes.ipa", conformingTo: .zip)
    }
    static var tipa: UTType {
        UTType(importedAs: "com.cr4zy.nyxian.tipa", conformingTo: .zip)
    }
    static var nipa: UTType {
        UTType(importedAs: "com.cr4zy.nyxian.nipa", conformingTo: .data)
    }
}

extension PEEntitlement {
    var displayString: String {
        guard self.rawValue != 0 else { return "None" }
        
        let flags: [(PEEntitlement, String)] = [
            (.getTaskAllowed, "Get Task Allowed"),
            (.taskForPid, "Task For Pid"),
            (.processEnumeration, "Process Enumeration"),
            (.processKill, "Process Kill"),
            (.processSpawn, "Process Spawn"),
            (.processSpawnSignedOnly, "Process Spawn (Signed Only)"),
            (.processElevate, "Process Elevate"),
            (.hostManager, "Host Manager"),
            (.credentialsManager, "Credentials Manager"),
            (.launchServicesStart, "Launch Services: Start"),
            (.launchServicesStop, "Launch Services: Stop"),
            (.launchServicesToggle, "Launch Services: Toggle"),
            (.launchServicesGetEndpoint, "Launch Services: Get Endpoint"),
            (.launchServicesSetEndpoint, "Launch Services: Set Endpoint"),
            (.dyldHideLiveProcess, "DYLD Hide LiveProcess"),
            (.processSpawnInheriteEntitlements, "Spawn Inherits Entitlements"),
            (.platform, "Platform"),
            (.platformRoot, "Platform Root"),
        ]
        
        let matched = flags.filter { self.contains($0.0) }.map { "  • \($0.1)" }
        
        let hex = String(self.rawValue, radix: 16, uppercase: true)
        let lines = ["0x\(hex):"] + matched
        return lines.joined(separator: "\n")
    }
}

class ApplicationManagementViewController: UIThemedTableViewController, UITextFieldDelegate, UIDocumentPickerDelegate, UIAdaptivePresentationControllerDelegate {
    @objc static var shared: ApplicationManagementViewController = ApplicationManagementViewController(style: .insetGrouped)
    var applications: [LDEApplicationObject] = []
    static let lock: NSLock = NSLock()
    
    override init(style: UITableView.Style) {
        super.init(style: style)
    }
    
    @MainActor required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.tableView.register(NXProjectTableCell.self, forCellReuseIdentifier: NXProjectTableCell.reuseIdentifier())
        LDEApplicationWorkspace.shared().ping()
        self.title = "Applications"
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Add", image: UIImage(systemName: "plus"), target: self, action: #selector(plusButtonPressed))
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.applications.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let application: LDEApplicationObject = self.applications[indexPath.row]
        let cell: NXProjectTableCell = self.tableView.dequeueReusableCell(withIdentifier: NXProjectTableCell.reuseIdentifier()) as! NXProjectTableCell
        cell.configure(withDisplayName: application.localizedName, withBundleIdentifier: application.bundleIdentifier, withAppIcon: application.icon, showAppIcon: true, showBundleID: true, showArrow: false)
        return cell
    }
    
    override func tableView(_ tableView: UITableView, contextMenuConfigurationForRowAt indexPath: IndexPath, point: CGPoint) -> UIContextMenuConfiguration? {
        let application = self.applications[indexPath.row]
        
        return UIContextMenuConfiguration(identifier: nil, previewProvider: nil) { [weak application] _ in
            // MARK: Open Menu
            let openMenu: UIMenuElement = UIAction(title: "Open", image: UIImage(systemName: "arrow.up.right.square.fill")) { _ in
                guard let application = application else { return }
                PEProcessManager.shared().spawnProcess(withBundleIdentifier: application.bundleIdentifier, withItems: [:], withKernelSurfaceProcess: nil, doRestartIfRunning: false)
            }
            
            var menu: [UIMenuElement] = [openMenu]
            
            let entitlementsPatchAction = UIAction(title: "Patch Entitlements", image: UIImage(systemName: "bandage.fill")) { _ in
                guard let application = application else { return }
                let machOViewController: MachOPatcherViewController = MachOPatcherViewController(machOPath: application.executablePath) {
                    if PEProcessManager.shared().process(forBundleIdentifier: application.bundleIdentifier) != nil {
                        PEProcessManager.shared().spawnProcess(withBundleIdentifier: application.bundleIdentifier, withItems: [:], withKernelSurfaceProcess: nil, doRestartIfRunning: true)
                    }
                }
                let navMachOViewController: UINavigationController = UINavigationController(rootViewController: machOViewController)
                navMachOViewController.modalPresentationStyle = .formSheet
                self.present(navMachOViewController, animated: true)
            }
            
            let clearContainerAction = UIAction(title: "Clear Data Container", image: UIImage(systemName: "arrow.up.trash.fill")) { _ in
                guard let application = application else { return }
                PEProcessManager.shared().closeIfRunning(usingBundleIdentifier: application.bundleIdentifier)
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
            
            menu.append(contentsOf: [entitlementsPatchAction, clearContainerAction, deleteAction])
            
            return UIMenu(title: "", children: menu)
        }
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let application = self.applications[indexPath.row]
        PEProcessManager.shared().spawnProcess(withBundleIdentifier: application.bundleIdentifier, withItems: [:], withKernelSurfaceProcess: nil, doRestartIfRunning: false)
    }
    
    @objc func plusButtonPressed() {
        let documentPicker: UIDocumentPickerViewController = UIDocumentPickerViewController(forOpeningContentTypes: [.ipa,.tipa,.nipa], asCopy: true)
        documentPicker.delegate = self
        documentPicker.modalPresentationStyle = .formSheet
        self.present(documentPicker, animated: true)
    }
    
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
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
                    NotificationServer.NotifyUser(level: .error, notification: "Failed to install application: no .app bundle found")
                    return
                }
                
                let appBundleFullPath = payloadDir.appending("/\(appBundlePathComponent)")
                
                guard let bundle = Bundle(path: appBundleFullPath) else {
                    NotificationServer.NotifyUser(level: .error, notification: "Failed to install application: invalid bundle path")
                    return
                }
                
                guard let executablePath = bundle.executablePath else {
                    NotificationServer.NotifyUser(level: .error, notification: "Failed to install application: invalid executable path")
                    return
                }
                
                var wasSignedLocally: Bool = false
                var ent: PEEntitlement = entitlement_get_path((executablePath as NSString).utf8String, &wasSignedLocally)
                
                // We have to make sure the app is only signed with entitlements known at that time, otherwise a app could contain way more entitlements currently reserved and used by nothing
                ent = PEEntitlement(rawValue: ent.rawValue & PEEntitlement.all.rawValue)
                
                // Gated :3
                let proceedWithInstall = {
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

                        DispatchQueue.global().async {
                            LCUtils.signAppBundle(withZSign: bundle.bundleURL) { result, error in
                                if result {
                                    if !wasSignedLocally {
                                        entitlement_set_path((executablePath as NSString).utf8String, ent)
                                    }

                                    if LDEApplicationWorkspace.shared().installApplication(atBundlePath: bundle.bundleURL.path) {
                                        DispatchQueue.main.async {
                                            alert.dismiss(animated: true) {
                                                PEProcessManager.shared().spawnProcess(
                                                    withBundleIdentifier: bundle.bundleIdentifier,
                                                    withItems: [:],
                                                    withKernelSurfaceProcess: nil,
                                                    doRestartIfRunning: true
                                                )
                                            }
                                        }
                                    } else {
                                        DispatchQueue.main.async {
                                            alert.dismiss(animated: true) {
                                                NotificationServer.NotifyUser(level: .error, notification: "Failed to sign or install application.")
                                            }
                                        }
                                    }
                                } else {
                                    DispatchQueue.main.async {
                                        alert.dismiss(animated: true) {
                                            NotificationServer.NotifyUser(level: .error, notification: "Failed to sign or install application.")
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                
                guard ent.rawValue != 0 else {
                    // If the app does not want anything special then it shall be granted
                    _ = proceedWithInstall()
                    return
                }
                
                // The app indeed wants something bruh
                DispatchQueue.main.async {
                    let alert = UIAlertController(
                        title: "App Requests Entitlements",
                        message: "This app requests the following entitlements:\n\n\(ent.displayString)\n\nDo you want to proceed with installation?",
                        preferredStyle: .alert
                    )
                    
                    alert.addAction(UIAlertAction(title: "Install", style: .default) { _ in
                        DispatchQueue.global().async {
                            _ = proceedWithInstall()
                        }
                    })
                    
                    alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
                    
                    self.present(alert, animated: true)
                }
                
            } catch {
                NotificationServer.NotifyUser(level: .error, notification: "Failed to install application: \(error.localizedDescription)")
            }
        }
    }
    
    @objc func applicationWasInstalled(_ app: LDEApplicationObject!) {
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
    
    @objc func application(withBundleIdentifierWasUninstalled bundleIdentifier: String!) {
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
    
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        if #available(iOS 26.0, *) {
            return 80
        } else {
            return 70
        }
    }
}

#endif // !JAILBREAK_ENV
