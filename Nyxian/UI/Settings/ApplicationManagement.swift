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

class ApplicationManagementViewController: UIThemedTableViewController, UITextFieldDelegate, UIDocumentPickerDelegate, UIAdaptivePresentationControllerDelegate {
    @objc static var shared: ApplicationManagementViewController = ApplicationManagementViewController(style: .insetGrouped)
    var applications: [LDEApplicationObject] = []
    static let lock: NSLock = NSLock()
    
    let entitlementsContextMenuMappings: [(key: String, value: [(String, PEEntitlement)])] = [
        ("Task Port (iOS 26.0 Only):powerplug.portrait.fill", [
            ("Get Task Allowed", .getTaskAllowed),
            ("Task For Pid", .taskForPid)
        ]),
        ("Process:cable.coaxial", [
            ("Enumeration", .processEnumeration),
            ("Kill", .processKill),
            ("Spawn", .processSpawn),
            ("Spawn (Signed Only)", .processSpawnSignedOnly),
            ("Spawn (Inherite Entitlements)", .processSpawnInheriteEntitlements),
            ("Elevate", .processElevate)
        ]),
        ("Host:pc", [
            ("Host Manager", .hostManager),
            //("Credentials Manager", .credentialsManager)
        ]),
        ("LaunchServices:bolt.fill", [
            /*("Start", .launchServicesStart),
            ("Stop", .launchServicesStop),
            ("Toggle", .launchServicesToggle),*/
            ("Get Endpoint", .launchServicesGetEndpoint),
            //("Manager", .launchServicesManager),
        ]),
        /*("TrustCache:tray.full.fill", [
            ("Read", .trustCacheRead),
            ("Write", .trustCacheWrite),
            ("Manager", .trustCacheManager)
        ]),*/
        ("Misc:ellipsis", [
            ("Platform", .platform),
            //("Enforce Device Spoof", .enforceDeviceSpoof),
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
        cell.configure(withDisplayName: application.displayName, withBundleIdentifier: application.bundleIdentifier, withAppIcon: application.icon, showAppIcon: true, showBundleID: true, showArrow: false)
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
                    PEProcessManager.shared().closeIfRunning(usingBundleIdentifier: application.bundleIdentifier)
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
                
                guard let appBundlePathComponent = contents.first(where: { ($0 as NSString).pathExtension == "app" }) else {
                    NotificationServer.NotifyUser(level: .error, notification: "Failed to install application: no .app bundle found")
                    return
                }
                
                let appBundleFullPath = payloadDir.appending("/\(appBundlePathComponent)")
                
                guard let bundle = Bundle(path: appBundleFullPath) else {
                    NotificationServer.NotifyUser(level: .error, notification: "Failed to install application: invalid bundle path")
                    return
                }
                
                LCUtils.signAppBundle(withZSign: bundle.bundleURL) { [weak self] result, error in
                    guard let self = self else { return }
                    
                    if result,
                       LDEApplicationWorkspace.shared().installApplication(atBundlePath: bundle.bundleURL.path) {
                        DispatchQueue.main.async {
                            PEProcessManager.shared().spawnProcess(withBundleIdentifier: bundle.bundleIdentifier, withItems: [:], withKernelSurfaceProcess: nil, doRestartIfRunning: false)
                        }
                    } else {
                        NotificationServer.NotifyUser(level: .error, notification: "Failed to sign or install application.")
                    }
                }
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
            //let entHash: String = LDETrust.shared().entHashOfExecutable(atPath: application.executablePath)
            //TrustCache.shared().setEntitlementsForHash(entHash, usingEntitlements: entitlement)
            PEProcessManager.shared().closeIfRunning(usingBundleIdentifier: application.bundleIdentifier)
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
