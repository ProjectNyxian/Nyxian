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

import Foundation
import Combine

#if JAILBREAK_ENV

// https://github.com/davidmurray/ios-reversed-headers/blob/b8fd3093e0e72107034792ed65272880820fecd5/BackBoardServices/BackBoardServices.h#L64
@_silgen_name("BKSTerminateApplicationForReasonAndReportWithDescription") func BKSTerminateApplicationForReasonAndReportWithDescription(_ bundleID: CFString,_ unknown: Int, _ unknown1: Int, _ desc: CFString)

#endif // JAILBREAK_ENV

class Builder {
    private let project: NXProject
    
    private var compilerJobs: [LDEJob] = []
    private var linkerJobs: [LDEJob] = []
    
    let database: DebugDatabase
    
    init?(project: NXProject) {
        self.project = project
        self.project.reload()
        
        self.database = DebugDatabase.getDatabase(ofPath: "\(self.project.cachePath!)/debug.json")
        self.database.reuseDatabase()
        
        var genericCompilerFlags: [String] = self.project.projectConfig.compilerFlags as! [String]
        
        try? syncFolderStructure(from: URL(fileURLWithPath: self.project.path), to: URL(fileURLWithPath: self.project.cachePath))
        
        guard let codeFiles = LDEFilesFinder(self.project.path, ["c","cpp","m","mm"], ["Resources"]) else {
            return nil
        }
        
        genericCompilerFlags.append(contentsOf: codeFiles)
        genericCompilerFlags.append("-o")
        genericCompilerFlags.append(self.project.machoPath)
        
        let driver: LDEDriver = LDEDriver(arguments: genericCompilerFlags)
        let jobs: [LDEJob] = driver.jobs
        
        var linkerInputItems: [URL] = []
        
        for job in jobs {
            switch(job.type) {
            case .compiler:
                let inputSourceFile: URL = job.input[0]
                let outputObjectFile: URL = URL(fileURLWithPath: "\(self.project.cachePath!)/\(expectedObjectFile(forPath: relativePath(from: URL(fileURLWithPath: self.project.path), to: URL(fileURLWithPath: inputSourceFile.path))))")
                linkerInputItems.append(outputObjectFile)
                job.output = [outputObjectFile]
                self.compilerJobs.append(job)
            case .linker:
                self.linkerJobs.append(job)
            default:
                break
            }
        }
        
        self.linkerJobs[0].input = linkerInputItems
    }
    
    func headsup() throws {
        let type = project.projectConfig.type
        if(type != 1 && type != 2) {
            throw NSError(domain: "com.cr4zy.nyxian.builder.headsup", code: 1, userInfo: [NSLocalizedDescriptionKey:"Project type \(type) is unknown."])
        }
        
        guard let osVersionNeeded: NXOSVersion = NXOSVersion(versionString: project.projectConfig.platformMinimumVersion) else {
            throw NSError(domain: "com.cr4zy.nyxian.builder.headsup", code: 1, userInfo: [NSLocalizedDescriptionKey:"App cannot be build, host version cannot be compared. Version \(project.projectConfig.platformMinimumVersion!) is not valid."])
        }
        
        // Nyxian requirement checks
        if osVersionNeeded < NXOSVersion.minimumBuildVersion {
            throw NSError(domain: "com.cr4zy.nyxian.builder.headsup", code: 1, userInfo: [NSLocalizedDescriptionKey:"System version \(osVersionNeeded) is older than Nyxian supports building for. Nyxian supports \(NXOSVersion.minimumBuildVersion) at a minimum."])
        }
        
        if osVersionNeeded > NXOSVersion.maximumBuildVersion {
            throw NSError(domain: "com.cr4zy.nyxian.builder.headsup", code: 1, userInfo: [NSLocalizedDescriptionKey:"System version \(osVersionNeeded) is newer than Nyxian supports building for. Nyxian supports \(NXOSVersion.maximumBuildVersion) at a maximum."])
        }
        
        // Project requirement check
        if osVersionNeeded > NXOSVersion.hostVersion {
            throw NSError(domain: "com.cr4zy.nyxian.builder.headsup", code: 1, userInfo: [NSLocalizedDescriptionKey:"System version \(osVersionNeeded) is needed to build the app, but host version \(NXOSVersion.hostVersion) is present."])
        }
    }
    
    ///
    /// Function to cleanup the project from old build files
    ///
    func clean() throws {
        // now remove what was find
        for file in LDEFilesFinder(
            self.project.path,
            ["o","tmp"],
            ["Resources","Config"]
        ) {
            try? FileManager.default.removeItem(atPath: file)
        }
        
        // if payload exists remove it
        if self.project.projectConfig.type == NXProjectType.app.rawValue {
            let payloadPath: String = self.project.payloadPath
            if FileManager.default.fileExists(atPath: payloadPath) {
                try? FileManager.default.removeItem(atPath: payloadPath)
            }
            
            let packagedApp: String = self.project.packagePath
            if FileManager.default.fileExists(atPath: packagedApp) {
                try? FileManager.default.removeItem(atPath: packagedApp)
            }
        }
    }
    
    func prepare() throws {
        if project.projectConfig.type == NXProjectType.app.rawValue {
            let bundlePath: String = self.project.bundlePath
            let resourcesPath: String = self.project.resourcesPath
            
            try FileManager.default.createDirectory(atPath: self.project.payloadPath, withIntermediateDirectories: true)
            try FileManager.default.copyItem(atPath: resourcesPath, toPath: bundlePath)
            
            var infoPlistData: [String: Any] = [
                "CFBundleExecutable": self.project.projectConfig.executable!,
                "CFBundleIdentifier": self.project.projectConfig.bundleid!,
                "CFBundleName": self.project.projectConfig.displayName!,
                "CFBundleShortVersionString": self.project.projectConfig.version!,
                "CFBundleVersion": self.project.projectConfig.shortVersion!,
                "MinimumOSVersion": self.project.projectConfig.platformMinimumVersion!,
                "UIDeviceFamily": [1, 2],
                "UIRequiresFullScreen": false,
                "UISupportedInterfaceOrientations~ipad": [
                    "UIInterfaceOrientationPortrait",
                    "UIInterfaceOrientationPortraitUpsideDown",
                    "UIInterfaceOrientationLandscapeLeft",
                    "UIInterfaceOrientationLandscapeRight"
                ]
            ]
            
            for (key, value) in self.project.projectConfig.infoDictionary {
                infoPlistData[key as! String] = value
            }
            
            let infoPlistDataSerialized = try PropertyListSerialization.data(fromPropertyList: infoPlistData, format: .xml, options: 0)
            FileManager.default.createFile(atPath:"\(bundlePath)/Info.plist", contents: infoPlistDataSerialized, attributes: nil)
        }
    }
    
    ///
    /// Function to build object files
    ///
    func compile() throws {
        if self.compilerJobs.count > 0 {
            let pstep: Double = 1.00 / Double(self.compilerJobs.count)
            guard let threader = LDEThreadGroupController(threads: UInt32(self.project.projectConfig.threads)) else {
                throw NSError(domain: "com.cr4zy.nyxian.builder.compile", code: 1, userInfo: [NSLocalizedDescriptionKey:"Failed to compile source code, because threader creation failed"])
            }
            
            for _ in self.compilerJobs {
                threader.enter();
            }
            
            for job in self.compilerJobs {
                threader.dispatchExecution( {
                    var issues: NSArray?
                    
                    if !LDECompiler.execute(job, outDiagnostics: &issues) {
                        threader.lockdown = true
                    }
                    
                    self.database.setFileDebug(ofPath: job.input[0].path, synItems: (issues as? [LDEDiagnostic]) ?? [])
                    
                    XCButton.incrementProgress(withValue: pstep)
                }, withCompletion: nil)
            }
            
            threader.wait()
            
            if threader.lockdown {
                throw NSError(domain: "com.cr4zy.nyxian.builder.compile", code: 1, userInfo: [NSLocalizedDescriptionKey:"Failed to compile source code"])
            }
        }
    }
    
    func link() throws {
        for job in linkerJobs {
            if !LDELinker.execute(job, outDiagnostics: nil) {
                throw NSError(domain: "com.cr4zy.nyxian.builder.link", code: 1, userInfo: [NSLocalizedDescriptionKey:"Linking object files together to a executable failed"])
            }
        }
    }
    
    func install(buildType: Builder.BuildType, outPipe: Pipe?, inPipe: Pipe?) throws {
#if !JAILBREAK_ENV
        if LCUtils.certificateData() == nil {
            throw NSError(domain: "com.cr4zy.nyxian.builder.install", code: 1, userInfo: [NSLocalizedDescriptionKey:"No code signature present to perform signing, import code signature in Settings > Certificate. Note that the code signature must be the same code signature used to sign Nyxian."])
        }
        
        if(buildType == .RunningApp) {
            if self.project.projectConfig.type == NXProjectType.app.rawValue {
                let semaphore = DispatchSemaphore(value: 0)
                var nsError: NSError? = nil
                
                LCUtils.signAppBundle(withZSign: URL(fileURLWithPath: project.bundlePath)) { [weak self] result, error in
                    guard let self = self else { return }
                    macho_after_sign(self.project.machoPath, self.project.entitlementsConfig.generateEntitlements())
                    if result {
                        if LDEApplicationWorkspace.shared().installApplication(atBundlePath: project.bundlePath) {
                            DispatchQueue.main.async {
                                var mapObject: FDMapObject? = nil
                                
                                if let inPipe = inPipe,
                                   let outPipe = outPipe {
                                    
                                    /*
                                     * creating empty mapobject and adding new pipes
                                     * to it we will need so we can receive prints
                                     * to for example the console of the IDE
                                     * workspace.
                                     */
                                    mapObject = FDMapObject.emptyMap()
                                    mapObject?.appendFileDescriptor(inPipe.fileHandleForReading.fileDescriptor, withMappingToLoc: STDIN_FILENO)
                                    mapObject?.appendFileDescriptor(outPipe.fileHandleForWriting.fileDescriptor, withMappingToLoc: STDOUT_FILENO)
                                    mapObject?.appendFileDescriptor(outPipe.fileHandleForWriting.fileDescriptor, withMappingToLoc: STDERR_FILENO)
                                    
                                    /*
                                     * shitty solution for now, but fixes the issue
                                     * where a process that prints debug text
                                     * gets terminated because someone has to hold
                                     * the receive pipes even if we close them.
                                     */
                                    mapObject?.appendFileDescriptor(inPipe.fileHandleForWriting.fileDescriptor, withMappingToLoc: 100)
                                    mapObject?.appendFileDescriptor(outPipe.fileHandleForReading.fileDescriptor, withMappingToLoc: 101)
                                }
                                
                                PEProcessManager.shared().spawnProcess(withBundleIdentifier: self.project.projectConfig.bundleid, withItems: (mapObject != nil) ? ["PEMapObject":mapObject!] : [:], withKernelSurfaceProcess: nil, doRestartIfRunning: true)
                            }
                        } else {
                            nsError = NSError(domain: "com.cr4zy.nyxian.builder.install", code: 1, userInfo: [NSLocalizedDescriptionKey:"Failed to install application"])
                        }
                    } else {
                        nsError = NSError(domain: "com.cr4zy.nyxian.builder.install", code: 1, userInfo: [NSLocalizedDescriptionKey:error?.localizedDescription ?? "Unknown error happened signing application"])
                    }
                    semaphore.signal()
                }
                semaphore.wait()
                
                if let nsError = nsError {
                    throw nsError
                }
            } else if self.project.projectConfig.type == NXProjectType.utility.rawValue {
                MachOObject.signBinary(atPath: self.project.machoPath)
                macho_after_sign(self.project.machoPath, self.project.entitlementsConfig.generateEntitlements())
                
                if let path: String = LDEApplicationWorkspace.shared().fastpathUtility(self.project.machoPath) {
                    DispatchQueue.main.sync {
                        let TerminalSession: NXWindowSessionTerminal = NXWindowSessionTerminal(utilityPath: path)
                        NXWindowServer.shared().openWindow(with: TerminalSession, withCompletion: nil)
                    }
                } else {
                    throw NSError(domain: "com.cr4zy.nyxian.builder.install", code: 1, userInfo: [NSLocalizedDescriptionKey:"Failed to fastpath install utility"])
                }
            }
        } else {
            macho_after_sign(self.project.machoPath, self.project.entitlementsConfig.generateEntitlements())
            try self.package()
        }
#else
        
        try self.package()
        
        if buildType == .RunningApp,
          self.project.projectConfig.type == NXProjectType.app.rawValue {
            // installing app
            var output: NSString?
            if shell(["\(Bundle.main.bundlePath)/tshelper","install",self.project.packagePath ?? ""], 0, nil, &output) != 0 {
                throw NSError(domain: "com.cr4zy.nyxian.builder.install", code: 1, userInfo: [NSLocalizedDescriptionKey:output ?? "Unknown error happened installing application"])
            }
            
            BKSTerminateApplicationForReasonAndReportWithDescription(self.project.projectConfig.bundleid! as CFString, 0, 0, "reinstalled application" as CFString)
            
            // opening app on iOS 16.x and above in our app it self in case user wants it so
            if #available(iOS 16.0, *) {
                
                // avoid lsapplication workspace if user wants it so
                // FIXME: currently unsupported
                if let avoidLSAWObj: NSNumber = (NSNumber(value: false) as NSNumber?) /*UserDefaults.standard.object(forKey: "LDEOpenAppInsideNyxian") as? NSNumber*/,
                   !avoidLSAWObj.boolValue {
                    
                    var success = false
                    let maxAttempts = 10
                    let delay: TimeInterval = 0.5
                    
                    for attempt in 1...maxAttempts {
                        if LSApplicationWorkspace.default().openApplication(withBundleID: self.project.projectConfig.bundleid) {
                            success = true
                            break
                        }
                        
                        Thread.sleep(forTimeInterval: delay)
                    }
                    
                    if !success {
                        throw NSError(domain: "com.cr4zy.nyxian.builder.install", code: 1, userInfo: [NSLocalizedDescriptionKey:"Failed to open application"])
                    }
                    
                    return
                }
                
                PEProcessManager.shared().spawnProcess(withBundleIdentifier: self.project.projectConfig.bundleid)
            } else {
                while(!LSApplicationWorkspace.default().openApplication(withBundleID: self.project.projectConfig.bundleid)) {
                    relax()
                }
            }
        }
#endif // !JAILBREAK_ENV
    }
    
    func package() throws {
#if JAILBREAK_ENV
        let entitlementsPath: String = "\(self.project.path ?? "")/Config/Entitlements.plist"
        if FileManager.default.fileExists(atPath: entitlementsPath),
           self.project.projectConfig.type == NXProjectType.app.rawValue {
            // pseudo signing executable
            if !ZSigner.adhocSignMachO(atPath: self.project.machoPath!, bundleId: self.project.projectConfig.bundleid!, entitlementData: try Data(contentsOf: URL(fileURLWithPath: entitlementsPath))) {
                throw NSError(domain: "com.cr4zy.nyxian.builder.install", code: 1, userInfo: [NSLocalizedDescriptionKey:"Unknown error happened pseudo signing application with entitlements"])
            }
        }
#endif // JAILBREAK_ENV
        
        zipDirectoryAtPath(project.payloadPath, project.packagePath, true)
    }
    
    ///
    /// Static function to build the project
    ///
    enum BuildType {
        case RunningApp
        case InstallPackagedApp
    }
    
    static func buildProject(withProject project: NXProject,
                             buildType: Builder.BuildType,
                             outPipe: Pipe?,
                             inPipe: Pipe?,
                             completion: @escaping (Bool) -> Void) {
        project.projectConfig.reloadData()
        
        XCButton.resetProgress()
        
        LDEPthreadDispatch {
            Bootstrap.shared.waitTillDone()
            
            var result: Bool = true
            guard let builder: Builder = Builder(
                project: project
            ) else {
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
                    (nil,nil,{ try builder.headsup() }),
                    (nil,nil,{ try builder.clean() }),
                    (nil,nil,{ try builder.prepare() }),
                    (nil,nil,{ try builder.compile() }),
                    ("link",0.3,{ try builder.link() }),
                    ("arrow.down.app.fill",nil,{try builder.install(buildType: buildType, outPipe: outPipe, inPipe: inPipe) })
                ];
                
                // doit
                try progressFlowBuilder(flow: flow)
            } catch {
                try? builder.clean()
                result = false
                builder.database.addInternalMessage(message: error.localizedDescription, severity: .error)
            }
            
            builder.database.saveDatabase(toPath: "\(project.cachePath!)/debug.json")
            
            completion(result)
        }
    }
}

func buildProjectWithArgumentUI(targetViewController: UIViewController,
                                project: NXProject,
                                buildType: Builder.BuildType,
                                outPipe: Pipe? = nil,
                                inPipe: Pipe? = nil,
                                completion: @escaping () -> Void = {}) {
    targetViewController.navigationItem.titleView?.isUserInteractionEnabled = false
    XCButton.switchImageSync(withSystemName: "hammer.fill", animated: false)
    guard let oldBarButtons: [UIBarButtonItem] = targetViewController.navigationItem.rightBarButtonItems else { return }
    
    let barButton: UIBarButtonItem = UIBarButtonItem(customView: XCButton.shared())
    
    targetViewController.navigationItem.setRightBarButtonItems([barButton], animated: true)
    targetViewController.navigationItem.setHidesBackButton(true, animated: true)
    
    Builder.buildProject(withProject: project, buildType: buildType, outPipe: outPipe, inPipe: inPipe) { result in
        DispatchQueue.main.async {
            targetViewController.navigationItem.setRightBarButtonItems(oldBarButtons, animated: true)
            targetViewController.navigationItem.setHidesBackButton(false, animated: true)
            targetViewController.navigationController?.navigationBar.isUserInteractionEnabled = true
            targetViewController.navigationItem.titleView?.isUserInteractionEnabled = true
            
            if !result {
                let loggerView = UINavigationController(rootViewController: UIDebugViewController(project: project))
                loggerView.modalPresentationStyle = .formSheet
                targetViewController.present(loggerView, animated: true)
            } else if buildType == .InstallPackagedApp {
                share(url: URL(fileURLWithPath: project.packagePath), remove: true)
            }
            
            completion()
        }
    }
}
