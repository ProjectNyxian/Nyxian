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

class ApplicationManagementViewController: UIThemedTableViewController, UITextFieldDelegate, UIDocumentPickerDelegate, UIAdaptivePresentationControllerDelegate {
    static var applications: [LDEApplicationObject] = []
    static let lock: NSLock = NSLock()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.title = "Applications"
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Add", image: UIImage(systemName: "plus"), target: self, action: #selector(plusButtonPressed))
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if ApplicationManagementViewController.lock.try() {
            DispatchQueue.global().async { [weak self] in
                let newApplications: [LDEApplicationObject] = LDEApplicationWorkspace.shared().allApplicationObjects()
                ApplicationManagementViewController.applications = newApplications
                DispatchQueue.main.async {
                    self?.tableView.reloadData()
                    ApplicationManagementViewController.lock.unlock()
                }
            }
        }
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return ApplicationManagementViewController.applications.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        return NXProjectTableCell(appObject: ApplicationManagementViewController.applications[indexPath.row])
    }
    
    override func tableView(_ tableView: UITableView, contextMenuConfigurationForRowAt indexPath: IndexPath, point: CGPoint) -> UIContextMenuConfiguration? {
        let application = ApplicationManagementViewController.applications[indexPath.row]
        
        return UIContextMenuConfiguration(identifier: nil, previewProvider: nil) { [weak application] _ in
            let entitlement: PEEntitlement = TrustCache.shared().getEntitlementsForHash(application?.entHash)
            
            // MARK: Open Menu
            let openMenu: UIMenuElement = UIAction(title: "Open", image: UIImage(systemName: "arrow.up.right.square.fill")) { _ in
                guard let application = application else { return }
                LDEProcessManager.shared().spawnProcess(withBundleIdentifier: application.bundleIdentifier, with: LDEProcessConfiguration(forHash: application.entHash))
            }
            
            // MARK: Entitlement Menu
            
            var entMenuItems: [UIMenu] = []
            
            // Task Port
            if #available(iOS 26.0, *) {
                if #unavailable(iOS 26.1) {
                    let tfp = self.createEntitlementButton(title: "Task For Pid", entitlement: entitlement, targetEntitlement: PEEntitlement.taskForPid, application: application)
                    let prvtTfp = self.createEntitlementButton(title: "Task For Pid (Private)", entitlement: entitlement, targetEntitlement: PEEntitlement.taskForPidPrvt, application: application)
                    let hostTfp = self.createEntitlementButton(title: "Get Host Task Port", entitlement: entitlement, targetEntitlement: PEEntitlement.getHostTaskPort, application: application)
                    entMenuItems.append(UIMenu(title: "Task Port", image: UIImage(systemName: "powerplug.portrait.fill"), children: [tfp, prvtTfp, hostTfp]))
                }
            }
            
            // Credentials
            let credentialSetUID = self.createEntitlementButton(title: "Set UID", entitlement: entitlement, targetEntitlement: PEEntitlement.setUidAllowed, application: application)
            let credentialSetGID = self.createEntitlementButton(title: "Set GID", entitlement: entitlement, targetEntitlement: PEEntitlement.setGidAllowed, application: application)
            
            entMenuItems.append(UIMenu(title: "Credentials", image: UIImage(systemName: "key.2.on.ring.fill"), children: [credentialSetUID, credentialSetGID]))
            
            // Inter Process
            let sendSignal = self.createEntitlementButton(title: "Send Signal", entitlement: entitlement, targetEntitlement: PEEntitlement.sendSignal, application: application)
            let sendSignalPrvt = self.createEntitlementButton(title: "Send Signal (Private)", entitlement: entitlement, targetEntitlement: PEEntitlement.sendSignalPrvt, application: application)
            let recvSignal = self.createEntitlementButton(title: "Receive Signal", entitlement: entitlement, targetEntitlement: PEEntitlement.recvSignal, application: application)
            
            entMenuItems.append(UIMenu(title: "Inter Process", image: UIImage(systemName: "cable.coaxial"), children: [sendSignal, sendSignalPrvt, recvSignal]))
            
            // Process
            let spawnProc = self.createEntitlementButton(title: "Spawn Process", entitlement: entitlement, targetEntitlement: PEEntitlement.spawnProc, application: application)
            let childSuperv = self.createEntitlementButton(title: "Child Supervisor", entitlement: entitlement, targetEntitlement: PEEntitlement.childSupervisor, application: application)
            
            entMenuItems.append(UIMenu(title: "Process", image: UIImage(systemName: "apple.terminal.fill"), children: [spawnProc, childSuperv]))
            
            let entMent: UIMenu = UIMenu(title: "Entitlements", image: UIImage(systemName: "checkmark.seal.text.page.fill"), children: entMenuItems)
            
            let clearContainerAction = UIAction(title: "Clear Data Container", image: UIImage(systemName: "arrow.up.trash.fill")) { _ in
                guard let application = application else { return }
                LDEProcessManager.shared().closeIfRunning(usingBundleIdentifier: application.bundleIdentifier)
                LDEApplicationWorkspace.shared().clearContainer(forBundleID: application.bundleIdentifier)
            }
            
            let deleteAction = UIAction(title: "Delete", image: UIImage(systemName: "trash.fill"), attributes: .destructive) { [weak self] _ in
                guard let self = self,
                      let application = application else { return }
                LDEProcessManager.shared().closeIfRunning(usingBundleIdentifier: application.bundleIdentifier)
                if(LDEApplicationWorkspace.shared().deleteApplication(withBundleID: application.bundleIdentifier)) {
                    if let index = ApplicationManagementViewController.applications.firstIndex(where: { $0.bundleIdentifier == application.bundleIdentifier }) {
                        ApplicationManagementViewController.applications.remove(at: index)
                        self.tableView.deleteRows(at: [IndexPath(row: index, section: 0)], with: .automatic)
                    }
                }
            }
            
            return UIMenu(title: "", children: [openMenu, entMent, clearContainerAction, deleteAction])
        }
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let application = ApplicationManagementViewController.applications[indexPath.row]
        LDEProcessManager.shared().spawnProcess(withBundleIdentifier: application.bundleIdentifier, with: LDEProcessConfiguration(forHash: application.entHash))
    }
    
    @objc func plusButtonPressed() {
        let documentPicker: UIDocumentPickerViewController = UIDocumentPickerViewController(forOpeningContentTypes: [.item], asCopy: true)
        documentPicker.delegate = self
        documentPicker.modalPresentationStyle = .formSheet
        self.present(documentPicker, animated: true)
    }

    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        DispatchQueue.global().async {
            guard let selectedURL = urls.first else { return }
            
            let fileManager = FileManager.default
            let tempRoot = NSTemporaryDirectory()
            let workRoot = (tempRoot as NSString).appendingPathComponent(UUID().uuidString)
            let unzipRoot = (workRoot as NSString).appendingPathComponent("unzipped")
            let payloadDir = (unzipRoot as NSString).appendingPathComponent("Payload")
            
            guard ((try? fileManager.createDirectory(atPath: unzipRoot, withIntermediateDirectories: true)) != nil) else { return }
            guard unzipArchiveAtPath(selectedURL.path, unzipRoot) else { return }
            var miError: AnyObject?
            guard let miBundle = MIBundle(bundleInDirectory: URL(fileURLWithPath: payloadDir), withExtension: "app", error: &miError) else {
                if let error: NSError = miError as? NSError {
                    NotificationServer.NotifyUser(level: .error, notification: "Failed to install application: \(error.localizedDescription)")
                }
                return
            }
            
            let bundleURL = miBundle.bundleURL!
            let lcapp = LCAppInfo(bundlePath: bundleURL.path)
            lcapp!.patchExecAndSignIfNeed(completionHandler: { [weak self] result, error in
                guard let self = self else { return }
                if result {
                    lcapp!.save()
                    let bundlePath = lcapp!.bundlePath()
                    let bundleId = lcapp!.bundleIdentifier()
                    if LDEApplicationWorkspace.shared().installApplication(atBundlePath: bundlePath) {
                        DispatchQueue.main.async {
                            LDEProcessManager.shared().spawnProcess(withBundleIdentifier: bundleId, with: LDEProcessConfiguration.userApplication())
                            let appObject: LDEApplicationObject = LDEApplicationWorkspace.shared().applicationObject(forBundleID: miBundle.identifier)
                            if let index = ApplicationManagementViewController.applications.firstIndex(where: { $0.bundleIdentifier == appObject.bundleIdentifier }) {
                                ApplicationManagementViewController.applications[index] = appObject
                            } else {
                                ApplicationManagementViewController.applications.append(appObject)
                            }
                            self.tableView.reloadData()
                        }
                    } else {
                        NotificationServer.NotifyUser(level: .error, notification: "Failed to install application.")
                    }
                    try? fileManager.removeItem(atPath: workRoot)
                } else {
                    NotificationServer.NotifyUser(level: .error, notification: "Failed to sign application.")
                }
            }, progressHandler: { _ in }, forceSign: false)
        }
    }
    
    private func createEntitlementButton(title: String, entitlement: PEEntitlement, targetEntitlement: PEEntitlement, application: LDEApplicationObject?) -> UIAction {
        var entitlement: PEEntitlement = entitlement
        return UIAction(title: title, image: UIImage(systemName: entitlement.contains(targetEntitlement) ? "checkmark.circle.fill" : "circle")) { [weak application] _ in
            guard let application = application else { return }
            if entitlement.contains(targetEntitlement) {
                entitlement.remove(targetEntitlement)
            } else {
                entitlement.insert(targetEntitlement)
            }
            TrustCache.shared().setEntitlementsForHash(application.entHash, usingEntitlements: entitlement)
            LDEProcessManager.shared().closeIfRunning(usingBundleIdentifier: application.bundleIdentifier)
        }
    }
}
