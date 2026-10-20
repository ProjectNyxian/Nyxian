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

import Foundation
import Combine
import MobileDevelopmentKit

final class NXBuilder: NSObject {
    private(set) var project: NXProject
    private(set) var projectDirty: Bool
    private(set) var database: DebugDatabase
    
    private(set) var dependencyScanner: MDKDependencyScanner
    private(set) var phaseRunner: NXPhaseRunner
    private(set) var remoteCompiler: NXRemoteCompiler? = nil
    
    private(set) var incrementalBuild: Bool = UserDefaults.standard.object(forKey: "LDEIncrementalBuild") as? Bool ?? true
    private(set) var useRemoteServiceIfAvailable: Bool = UserDefaults.standard.object(forKey: "LDERemoteCompileService") as? Bool ?? true
    private let argsString: String
    
    static var builds: Bool = false
    
    init?(project: NXProject) {
        self.project = project
        self.project.reload()
        
        if !self.project.syncFolderStructureToCache() {
            return nil
        }
        
        self.database = DebugDatabase.getDatabase(ofPath: "\(self.project.cacheURL.path)/debug.json")
        self.database.reuseDatabase()
        
        if useRemoteServiceIfAvailable {
            remoteCompiler = NXRemoteCompiler.new()
        }
        
        if remoteCompiler?.setupDependencyScanner(withArguments: self.project.projectConfig.compilerFlags) ?? false,
           let remoteDependencyScanner = remoteCompiler?.dependencyScanner() {
            self.dependencyScanner = remoteDependencyScanner
        } else {
            self.dependencyScanner = MDKDependencyScanner(arguments: self.project.projectConfig.compilerFlags)
        }
        
        let phaseEngine: NXPhaseEngine
        do {
            phaseEngine = try NXPhaseEngine(project: self.project)
        } catch {
            self.database.addMessage(message: error.localizedDescription, severity: .error)
            self.database.saveDatabase(toPath: project.cacheURL.appendingPathComponent("debug.json").path)
            return nil
        }
        
        self.argsString = self.project.projectConfig.swiftFlags.joined(separator: " ") + self.project.projectConfig.compilerFlags.joined(separator: " ") + " \(self.project.projectConfig.linkFrameworksAutomatically)"
        
        // Check if the args string matches up
        if self.incrementalBuild,
           let args: String = (try? String(contentsOf: self.project.cacheURL.appendingPathComponent("args.txt"), encoding: .utf8)) {
            self.projectDirty = args != self.argsString
        } else {
            self.projectDirty = true
            self.database.clearDatabase() /* nothing valid anymore */
        }
        
        guard let phaseRunner = NXPhaseRunner(engine: phaseEngine) else {
            return nil
        }
        self.phaseRunner = phaseRunner
        
        super.init()
        
        phaseEngine.delegate = self
        self.phaseRunner.delegate = self
    }
    
    func headsup(buildType: NXBuilder.BuildType) throws {
        let type = project.projectConfig.schemeKind
        if(type != .app && type != .utility && type != .kSurfaceKext) {
            throw NSError(domain: "com.cr4zy.nyxian.builder.headsup", code: 1, userInfo: [NSLocalizedDescriptionKey:"Project type \(type) is unknown."])
        }
        
        guard let osVersionNeeded: MDKOSVersion = MDKOSVersion(versionString: project.projectConfig.deploymentTarget) else {
            throw NSError(domain: "com.cr4zy.nyxian.builder.headsup", code: 1, userInfo: [NSLocalizedDescriptionKey:"Target \"\(self.project.projectConfig.displayName ?? "Unknown") (\(self.project.projectConfig.bundleid ?? "Unknown"))\" cannot be build, host version cannot be compared. Version \(project.projectConfig.deploymentTarget!) is not valid."])
        }
        
        // Nyxian requirement check
        let minimumOSVersion: MDKOSVersion = MDKOSVersion(versionString: NXOSVersion.NXOSVersionSupportedBuildVersions.first)!
        let maximumOSVersion: MDKOSVersion = MDKOSVersion(versionString: NXOSVersion.NXOSVersionSupportedBuildVersions.last)!
        if osVersionNeeded < minimumOSVersion || osVersionNeeded > maximumOSVersion {
            throw NSError(domain: "com.cr4zy.nyxian.builder.headsup", code: 1, userInfo: [NSLocalizedDescriptionKey:"Target \"\(self.project.projectConfig.displayName ?? "Unknown") (\(self.project.projectConfig.bundleid ?? "Unknown"))\" declares deployment target \(osVersionNeeded) which is not supported by this version of Nyxian. This version of Nyxian supports \(minimumOSVersion) up to \(maximumOSVersion)."])
        }
        
        // Project requirement check
        if osVersionNeeded > MDKOSVersion.host,
           buildType == .run {
            throw NSError(domain: "com.cr4zy.nyxian.builder.headsup", code: 1, userInfo: [NSLocalizedDescriptionKey:"Target \"\(self.project.projectConfig.displayName ?? "Unknown") (\(self.project.projectConfig.bundleid ?? "Unknown"))\" declares deployment target \(osVersionNeeded) which doesn't support the host version \(MDKOSVersion.host). Please update your idevice."])
        }
    }
    
    func clean() throws {
        // now remove what was find
        for file in LDEFilesFinder(
            self.project.url.path,
            ["o","tmp"],
            ["Resources","Config"]
        ) {
            try? FileManager.default.removeItem(atPath: file)
        }
        
        // if payload exists remove it
        if self.project.projectConfig.schemeKind == .app {
            try? FileManager.default.removeItem(atPath: self.project.payloadURL.path)
            try? FileManager.default.removeItem(atPath: self.project.packageURL.path)
        }
    }
    
    func prepare() throws {
        if project.projectConfig.schemeKind == .app {
            try FileManager.default.createDirectory(at: self.project.payloadURL, withIntermediateDirectories: true)
            try FileManager.default.copyItem(at: self.project.resourcesURL, to: self.project.bundleURL)
            
            let infoPlistDataSerialized = try PropertyListSerialization.data(fromPropertyList: self.project.projectConfig.infoDictionary ?? [:], format: .xml, options: 0)
            FileManager.default.createFile(atPath: self.project.bundleURL.appendingPathComponent("Info.plist").path, contents: infoPlistDataSerialized)
        } else if project.projectConfig.schemeKind == .kSurfaceKext {
            try FileManager.default.createDirectory(at: self.project.bundleURL, withIntermediateDirectories: true)
            let infoPlistDataSerialized = try PropertyListSerialization.data(fromPropertyList: self.project.projectConfig.infoDictionary ?? [:], format: .xml, options: 0)
            FileManager.default.createFile(atPath: self.project.bundleURL.appendingPathComponent("Info.plist").path, contents: infoPlistDataSerialized)
        }
    }
    
    func build() throws {
        if !self.phaseRunner.runPhases() {
            throw NSError(domain: "com.cr4zy.nyxian.builder.runner", code: 1, userInfo: [NSLocalizedDescriptionKey:"Failed to run project."])
        }
        
        do {
            try self.argsString.write(to: self.project.cacheURL.appendingPathComponent("args.txt"), atomically: false, encoding: .utf8)
        } catch {
            throw NSError(domain: "com.cr4zy.nyxian.builder.runner", code: 1, userInfo: [NSLocalizedDescriptionKey:error.localizedDescription])
        }
    }
    
    func install(buildType: NXBuilder.BuildType, executablePathCallback: @escaping (String?) -> Void) throws {
        let spinnerStart = DispatchWorkItem { XCButton.startSpinning() }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0, execute: spinnerStart)
        defer {
            spinnerStart.cancel()
            XCButton.stopSpinning()
        }
        
        if buildType == .run {
            var success: Bool = false;
            let semaphore = DispatchSemaphore(value: 0)
            checkSigningSetup() { codeSigningSetup in
                success = codeSigningSetup
                semaphore.signal()
            }
            semaphore.wait()
            
            if !success {
                throw NSError(domain: "com.cr4zy.nyxian.builder.install", code: 1, userInfo: [NSLocalizedDescriptionKey:"Code signing is not properly set up. Cannot sign targets."])
            }
            
            if self.project.projectConfig.schemeKind == .app {
                let semaphore = DispatchSemaphore(value: 0)
                var nsError: NSError? = nil
                
                LCUtils.signAppBundle(withZSign: self.project.bundleURL) { [weak self] result, error in
                    guard let self = self else { return }
                    
                    if self.project.projectConfig.signMachOWithNyxianEntitlements {
                        trust_nxt2_sign(self.project.machoURL.path, project.entitlementsConfig.dictionary as CFDictionary, true, nil)
                    }
                    
                    guard result else {
                        nsError = NSError(domain: "com.cr4zy.nyxian.builder.install", code: 1, userInfo: [NSLocalizedDescriptionKey:error?.localizedDescription ?? "Unknown error happened signing application"])
                        semaphore.signal()
                        return
                    }
                    
                    guard LDEApplicationWorkspace.shared().installApplication(atBundlePath: project.bundleURL.path) else {
                        nsError = NSError(domain: "com.cr4zy.nyxian.builder.install", code: 1, userInfo: [NSLocalizedDescriptionKey:"Unknown error happened installing application"]) // TODO: implement NSError pipeline
                        semaphore.signal()
                        return
                    }
                    
                    semaphore.signal()
                }
                semaphore.wait()
                
                if let nsError = nsError {
                    throw nsError
                }
            } else if self.project.projectConfig.schemeKind == .utility {
                LCUtils.signMachO(at: self.project.machoURL)
                if self.project.projectConfig.signMachOWithNyxianEntitlements {
                    trust_nxt2_sign(self.project.machoURL.path, project.entitlementsConfig.dictionary as CFDictionary, true, nil)
                }
                
                let path: String? = LDEApplicationWorkspace.shared().fastpathUtility(self.project.machoURL.path)
                if path == nil {
                    throw NSError(domain: "com.cr4zy.nyxian.builder.install", code: 1, userInfo: [NSLocalizedDescriptionKey:"Failed to fastpath install utility"])
                }
                executablePathCallback(path)
            } else if self.project.projectConfig.schemeKind == .kSurfaceKext {
                if let ptr = LCMapMachO(self.project.machoURL.path, false) {
                    ptr.pointee.header.pointee.filetype = UInt32(MH_KEXT_BUNDLE)
                    LCUnmapMachO(ptr)
                    
                    LCUtils.signMachOWithoutPatch(at: self.project.machoURL)
                    trust_nxt2_sign(self.project.machoURL.path, [
                        "org.emexlabs.nyxian.ksurface.kernelextension.loading" : true
                    ] as CFDictionary, true, nil)
                    vnode_refresh_with_path(self.project.machoURL.path)
                    let ret: kern_return_t = ksurface_fs_install_kext_at_path(self.project.bundleURL.path);
                    if ret != 0 {
                        throw NSError(domain: "com.cr4zy.nyxian.builder.install", code: 1, userInfo: [NSLocalizedDescriptionKey:"Failed to install kext: \(String(cString: mach_error_string(ret)))"])
                    }
                    
                    PERestartSelf()
                }
            }
        } else {
            if self.project.projectConfig.schemeKind == .kSurfaceKext {
                if let ptr = LCMapMachO(self.project.machoURL.path, false) {
                    ptr.pointee.header.pointee.filetype = UInt32(MH_KEXT_BUNDLE)
                    LCUnmapMachO(ptr)
                    
                    trust_nxt2_sign(self.project.machoURL.path, [
                        "org.emexlabs.nyxian.ksurface.kernelextension.loading" : true
                    ] as CFDictionary, true, nil)
                    
                    zipDirectoryAtPath(project.payloadURL.path, project.packageURL.path, true)
                }
            } else {
                if self.project.projectConfig.signMachOWithNyxianEntitlements {
                    trust_nxt2_sign(self.project.machoURL.path, project.entitlementsConfig.dictionary as CFDictionary, false, nil)
                }
                if self.project.projectConfig.schemeKind == .app {
                    try self.package()
                }
            }
        }
    }
    
    func package() throws {
        zipDirectoryAtPath(project.payloadURL.path, project.packageURL.path, true)
    }
    
    ///
    /// Static function to build the project
    ///
    enum BuildType {
        case run
        case export
    }
    
    static func buildProject(withProject project: NXProject,
                             buildType: NXBuilder.BuildType,
                             completion: @escaping (Bool,String?) -> Void) {
        project.projectConfig.reloadData()
        
        XCButton.resetProgress()
        
        var execPath: String?
        
        MDKPthreadDispatch {
            autoreleasepool {
                NXBootstrap.shared().waitTillDone()
                
                var result: Bool = true
                guard let builder: NXBuilder = NXBuilder(
                    project: project
                ) else {
                    completion(false,nil)
                    return
                }
                
                var resetNeeded: Bool = false
                func progressStage(systemName: String? = nil, increment: Double? = nil, handler: () throws -> Void) throws {
                    let doReset: Bool = (increment == nil)
                    if doReset, resetNeeded {
                        XCButton.resetProgress()
                        resetNeeded = false
                    }
                    if let systemName = systemName { XCButton.switchImage(withSystemName: systemName, animated: true) }
                    try handler()
                    if !doReset, let increment = increment {
                        XCButton.incrementProgress(withValue: increment)
                        resetNeeded = true
                    }
                }
                
                func progressFlowBuilder(flow: [(String?,Double?,() throws -> Void)]) throws {
                    for item in flow { try progressStage(systemName: item.0, increment: item.1, handler: item.2) }
                }
                
                do {
                    // prepare
                    let flow: [(String?,Double?,() throws -> Void)] = [
                        (nil,nil,{ try builder.headsup(buildType: buildType) }),
                        (nil,nil,{ try builder.clean() }),
                        (nil,nil,{ try builder.prepare() }),
                        (nil,nil,{ try builder.build() }),
                        ("arrow.down.app.fill",nil,{try builder.install(buildType: buildType, executablePathCallback: { path in
                            execPath = path
                        }) })
                    ];
                    
                    // doit, just do it!
                    try progressFlowBuilder(flow: flow)
                } catch {
                    try? builder.clean()
                    result = false
                    builder.database.addMessage(message: error.localizedDescription, severity: .error)
                }
                builder.database.saveDatabase(toPath: project.cacheURL.appendingPathComponent("debug.json").path)
                
                completion(result, execPath)
            }
        }
    }
}

func buildProjectWithArgumentUI(targetViewController: UIViewController,
                                project: NXProject,
                                buildType: NXBuilder.BuildType,
                                completion: @escaping (Bool,String?) -> Void = { _,_ in }) {
    autoreleasepool {
        targetViewController.navigationItem.titleView?.isUserInteractionEnabled = false
        XCButton.switchImageSync(withSystemName: "hammer.fill", animated: false)
        guard let oldBarButtons: [UIBarButtonItem] = targetViewController.navigationItem.rightBarButtonItems else { return }
        
        let barButton: UIBarButtonItem = UIBarButtonItem(customView: XCButton.shared())
        
        NXBuilder.builds = true
        targetViewController.navigationItem.setRightBarButtonItems([barButton], animated: true)
        targetViewController.navigationItem.setHidesBackButton(true, animated: true)
        
        NXDocumentManager.shared().saveAll {
            NXDocumentManager.shared().changeAllLockState(toBoolean: true)
            NXBuilder.buildProject(withProject: project, buildType: buildType) { result, fastPath in
                NXDocumentManager.shared().changeAllLockState(toBoolean: false)
                DispatchQueue.main.async {
                    targetViewController.navigationItem.setRightBarButtonItems(oldBarButtons, animated: true)
                    targetViewController.navigationItem.setHidesBackButton(false, animated: true)
                    targetViewController.navigationController?.navigationBar.isUserInteractionEnabled = true
                    targetViewController.navigationItem.titleView?.isUserInteractionEnabled = true
                    
                    NXBuilder.builds = false
                    
                    if !result {
                        let loggerView = UINavigationController(rootViewController: UIDebugViewController(project: project))
                        loggerView.modalPresentationStyle = .formSheet
                        targetViewController.present(loggerView, animated: true)
                    } else if buildType == .export {
                        share(url: project.packageURL, remove: true)
                    }
                    
                    completion(result, fastPath)
                }
            }
        }
    }
}
