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
    @objc static var shared: ApplicationManagementViewController = ApplicationManagementViewController(style: .insetGrouped)
    var applications: [LDEApplicationObject] = []
    static let lock: NSLock = NSLock()
    
    let entitlementsContextMenuMappings: [(key: String, value: [(String, PEEntitlement)])] = [
        ("Task Port (iOS 26.0 Only):powerplug.portrait.fill", [
            ("Get Task Allowed", .getTaskAllowed),
            ("Task For Pid", .taskForPid),
            ("Task For Host Pid", .taskForPidHost)
        ]),
        ("Process:cable.coaxial", [
            ("Enumeration", .processEnumeration),
            ("Kill", .processKill),
            ("Spawn", .processSpawn),
            ("Spawn (Signed Only)", .processSpawnSignedOnly),
            ("Spawn (Inherite Entitlements)", .processElevate),
            ("Elevate", .processKill)
        ]),
        ("Host:pc", [
            ("Host Manager", .hostManager),
            ("Credentials Manager", .credentialsManager)
        ]),
        ("LaunchServices:bolt.fill", [
            ("Start", .launchServicesStart),
            ("Stop", .launchServicesStop),
            ("Toggle", .launchServicesToggle),
            ("Get Endpoint", .launchServicesGetEndpoint),
            ("Manager", .launchServicesManager),
        ]),
        ("TrustCache:tray.full.fill", [
            ("Read", .trustCacheRead),
            ("Write", .trustCacheWrite),
            ("Manager", .trustCacheManager)
        ]),
        ("Misc:ellipsis", [
            ("Platform", .enforceDeviceSpoof),
            ("Enforce Device Spoof", .enforceDeviceSpoof),
            ("DYLD Hide LiveProcess", .dyldHideLiveProcess)
        ])
    ]
    
    override init(style: UITableView.Style) {
        super.init(style: style)
    }
    
    @MainActor required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
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
        return NXProjectTableCell(appObject: self.applications[indexPath.row])
    }
    
    override func tableView(_ tableView: UITableView, contextMenuConfigurationForRowAt indexPath: IndexPath, point: CGPoint) -> UIContextMenuConfiguration? {
        let application = self.applications[indexPath.row]
        
        return UIContextMenuConfiguration(identifier: nil, previewProvider: nil) { [weak application] _ in
            // MARK: Open Menu
            let openMenu: UIMenuElement = UIAction(title: "Open", image: UIImage(systemName: "arrow.up.right.square.fill")) { _ in
                guard let application = application else { return }
                LDEProcessManager.shared().spawnProcess(withBundleIdentifier: application.bundleIdentifier, withKernelSurfaceProcess: kernel_proc(), doRestartIfRunning: false)
            }
            
            var menu: [UIMenuElement] = [openMenu]
            
            // MARK: Entitlement Menu
            if let entHash: String = LDETrust.entHashOfExecutable(atPath: application?.executablePath) {
                let entitlement: PEEntitlement = TrustCache.shared().getEntitlementsForHash(entHash)
                var entMenuItems: [UIMenu] = []
                
                for entry in self.entitlementsContextMenuMappings {
                    let keyComponents: [String] = entry.key.components(separatedBy: ":")
                    let subMenuTitle: String = keyComponents[0]
                    let subMenuImageName: String = keyComponents[1]
                    let subMenuItems: [(String,PEEntitlement)] = entry.value
                    var children: [UIMenuElement] = []
                    for subMenuItem in subMenuItems {
                        children.append(self.createEntitlementButton(title: subMenuItem.0, entitlement: entitlement, targetEntitlement: subMenuItem.1, application: application))
                    }
                    entMenuItems.append(UIMenu(title: subMenuTitle, image: UIImage(systemName: subMenuImageName), children: children))
                }
                
                let entMenu: UIMenu = UIMenu(title: "Entitlements", image: UIImage(systemName: "checkmark.seal.text.page.fill"), children: entMenuItems)
                menu.append(entMenu)
            }
            
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
                    if let index = self.applications.firstIndex(where: { $0.bundleIdentifier == application.bundleIdentifier }) {
                        self.applications.remove(at: index)
                        self.tableView.deleteRows(at: [IndexPath(row: index, section: 0)], with: .automatic)
                    }
                }
            }
            
            menu.append(contentsOf: [clearContainerAction, deleteAction])
            
            return UIMenu(title: "", children: menu)
        }
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let application = self.applications[indexPath.row]
        LDEProcessManager.shared().spawnProcess(withBundleIdentifier: application.bundleIdentifier, withKernelSurfaceProcess: kernel_proc(), doRestartIfRunning: false)
    }
    
    @objc func plusButtonPressed() {
        let documentPicker: UIDocumentPickerViewController = UIDocumentPickerViewController(forOpeningContentTypes: [.item], asCopy: true)
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
                
                guard let appBundlePathComponent = contents.first(where: { $0.URLGet().pathExtension == "app" }) else {
                    NotificationServer.NotifyUser(level: .error, notification: "Failed to install application: no .app bundle found")
                    return
                }
                
                let appBundleFullPath = payloadDir.appending("/\(appBundlePathComponent)")
                
                guard let bundle = Bundle(path: appBundleFullPath) else {
                    NotificationServer.NotifyUser(level: .error, notification: "Failed to install application: invalid bundle path")
                    return
                }
                
                let bundleURL = bundle.bundleURL
                let lcapp = LCAppInfo(bundlePath: bundleURL.path)
                lcapp!.patchExecAndSignIfNeed(completionHandler: { [weak self] result, error in
                    guard let self = self else { return }
                    if result {
                        lcapp!.save()
                        let bundlePath = lcapp!.bundlePath()
                        let bundleId = lcapp!.bundleIdentifier()
                        if LDEApplicationWorkspace.shared().installApplication(atBundlePath: bundlePath) {
                            DispatchQueue.main.async {
                                LDEProcessManager.shared().spawnProcess(withBundleIdentifier: bundleId, withKernelSurfaceProcess: kernel_proc(), doRestartIfRunning: false)
                                let appObject: LDEApplicationObject = LDEApplicationWorkspace.shared().applicationObject(forBundleID: bundle.bundleIdentifier)
                                if let index = self.applications.firstIndex(where: { $0.bundleIdentifier == appObject.bundleIdentifier }) {
                                    self.applications[index] = appObject
                                } else {
                                    self.applications.append(appObject)
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
            } catch {
                NotificationServer.NotifyUser(level: .error, notification: "Failed to install application: \(error.localizedDescription)")
            }
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
            let entHash: String = LDETrust.entHashOfExecutable(atPath: application.executablePath)
            TrustCache.shared().setEntitlementsForHash(entHash, usingEntitlements: entitlement)
            LDEProcessManager.shared().closeIfRunning(usingBundleIdentifier: application.bundleIdentifier)
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
}
