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
import CoreCompiler

#if JAILBREAK_ENV

// https://github.com/davidmurray/ios-reversed-headers/blob/b8fd3093e0e72107034792ed65272880820fecd5/BackBoardServices/BackBoardServices.h#L64
@_silgen_name("BKSTerminateApplicationForReasonAndReportWithDescription") func BKSTerminateApplicationForReasonAndReportWithDescription(_ bundleID: CFString,_ unknown: Int, _ unknown1: Int, _ desc: CFString)

#endif // JAILBREAK_ENV

class Builder: NSObject, CCKDriverDelegate {
    private let project: NXProject
    
    private var compilerJobs: [CCKJob] = []
    private var linkerJobs: [CCKJob] = []
    
    private var compilerSwiftJobs: [(String,String)] = []
    
    private let database: DebugDatabase
    
    private let driver: CCKDriver
    private let dependencyScanner: CCKDependencyScanner
    
    private let incrementalBuild: Bool = UserDefaults.standard.object(forKey: "LDEIncrementalBuild") as? Bool ?? true
    private let projectDirty: Bool
    
    private let argsString: String
    
    init?(project: NXProject) {
        self.project = project
        self.project.reload()
        
        self.database = DebugDatabase.getDatabase(ofPath: "\(self.project.cacheURL.path)/debug.json")
        self.database.reuseDatabase()
        
        var driverFlags: [String] = self.project.projectConfig.compilerFlags
        
        try? syncFolderStructure(from: self.project.url, to: self.project.cacheURL)
        
        guard let codeFiles = LDEFilesFinder(self.project.url.path, ["c","cpp","m","mm"], ["Resources"]) else {
            return nil
        }
        guard let swiftFiles = LDEFilesFinder(self.project.url.path, ["swift"], ["Resources"]) else {
            return nil
        }
        
        for file in swiftFiles {
            let swiftObject: String = "\(self.project.cacheURL.path)/\(expectedObjectFile(forPath: relativePath(from: self.project.url, to: URL(fileURLWithPath: file))))"
            
            /* TODO: add incremental build to swift files */
            self.compilerSwiftJobs.append((file,swiftObject))
        }
        
        driverFlags.append(contentsOf: codeFiles)
        driverFlags.append("-o")
        driverFlags.append(self.project.machoURL.path)
        
        if !self.project.projectConfig.linkerFlags.isEmpty {
            driverFlags.append("-Wl,\(self.project.projectConfig.linkerFlags.joined(separator: " ").split(separator: " ").joined(separator: ","))")
        }
        
        self.argsString = driverFlags.joined(separator: " ")
        
        // Check if the args string matches up
        if let args: String = (try? String(contentsOf: self.project.cacheURL.appendingPathComponent("args.txt"), encoding: .utf8)) {
            self.projectDirty = args != self.argsString
        } else {
            self.projectDirty = true
            self.database.clearDatabase() /* nothing valid anymore */
        }
        
        self.driver = CCKDriver(arguments: driverFlags)
        self.dependencyScanner = CCKDependencyScanner(arguments: self.project.projectConfig.compilerFlags)
        
        super.init()
        
        driver.delegate = self
        
        let jobs: [CCKJob] = self.driver.generateJobs()
        for job in jobs {
            switch(job.type) {
            case .compiler:
                self.compilerJobs.append(job)
            case .linker:
                self.linkerJobs.append(job)
            default:
                break
            }
        }
        
        if !self.compilerSwiftJobs.isEmpty {
            // Have to patch link job
            let linkerJob: CCKJob = self.linkerJobs[0]
            let type: CCJobType = linkerJob.type
            var arguments: [String] = linkerJob.arguments
            
            // Adding swift object files
            for job in self.compilerSwiftJobs {
                arguments.append(job.1)
            }
            
            // Adding swift related linker flags
            // TODO: let the user add those manually in Other linker flags
            arguments.append("-L\(NXBootstrap.shared().sdkURL.path)/usr/lib/swift")
            arguments.append("-L\(NXBootstrap.shared().swiftURL.path)")
            arguments.append("-rpath")
            arguments.append("/usr/lib/swift")
            self.linkerJobs[0] = CCKJob(type: type, withArguments: arguments)
        }
    }
    
    func driver(_ driver: CCKDriver!, outputPathForInputFile file: CCKFile!) -> String! {
        return "\(self.project.cacheURL.path)/\(expectedObjectFile(forPath: relativePath(from: self.project.url, to: file.fileURL)))"
    }
    
    func driver(_ driver: CCKDriver!, skipCompileForInputFile file: CCKFile!) -> Bool {
        if self.incrementalBuild {
            if self.projectDirty {
                return false
            }
            
            let path: String = file.fileURL.path
            let objectPath = "\(self.project.cacheURL.path)/\(expectedObjectFile(forPath: relativePath(from: self.project.url, to: file.fileURL)))"
            
            // Checking if the source file is newer than the compiled object file
            guard let sourceDate = try? FileManager.default.attributesOfItem(atPath: path)[.modificationDate] as? Date,
                  let objectDate = try? FileManager.default.attributesOfItem(atPath: objectPath)[.modificationDate] as? Date,
                  objectDate > sourceDate else {
                return false
            }
            
            // Checking if the header files included by the source code are newer than the object file
            guard let headers = self.dependencyScanner.headerFiles(for: file) else {
                return false
            }
            
            for header in headers {
                guard let fileURL = header.fileURL,
                      let headerDate = try? FileManager.default.attributesOfItem(atPath: fileURL.path)[.modificationDate] as? Date,
                      objectDate > headerDate else {
                    return false
                }
            }
            
            return true
        } else {
            return false
        }
    }
    
    func headsup() throws {
        let type = project.projectConfig.type
        if(type != .app && type != .utility) {
            throw NSError(domain: "com.cr4zy.nyxian.builder.headsup", code: 1, userInfo: [NSLocalizedDescriptionKey:"Project type \(type) is unknown."])
        }
        
        guard let osVersionNeeded: NXOSVersion = NXOSVersion(versionString: project.projectConfig.deploymentTarget) else {
            throw NSError(domain: "com.cr4zy.nyxian.builder.headsup", code: 1, userInfo: [NSLocalizedDescriptionKey:"App cannot be build, host version cannot be compared. Version \(project.projectConfig.deploymentTarget!) is not valid."])
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
            self.project.url.path,
            ["o","tmp"],
            ["Resources","Config"]
        ) {
            try? FileManager.default.removeItem(atPath: file)
        }
        
        // if payload exists remove it
        if self.project.projectConfig.type == .app {
            let payloadPath: String = self.project.payloadURL.path
            if FileManager.default.fileExists(atPath: payloadPath) {
                try? FileManager.default.removeItem(atPath: payloadPath)
            }
            
            let packagedApp: String = self.project.packageURL.path
            if FileManager.default.fileExists(atPath: packagedApp) {
                try? FileManager.default.removeItem(atPath: packagedApp)
            }
        }
    }
    
    func prepare() throws {
        if project.projectConfig.type == .app {
            try FileManager.default.createDirectory(at: self.project.payloadURL, withIntermediateDirectories: true)
            try FileManager.default.copyItem(at: self.project.resourcesURL, to: self.project.bundleURL)
            
            var infoPlistData: [String: Any] = [
                "CFBundleExecutable": self.project.projectConfig.executable!,
                "CFBundleIdentifier": self.project.projectConfig.bundleid!,
                "CFBundleName": self.project.projectConfig.displayName!,
                "CFBundleShortVersionString": self.project.projectConfig.version!,
                "CFBundleVersion": self.project.projectConfig.shortVersion!,
                "MinimumOSVersion": self.project.projectConfig.deploymentTarget!,
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
            FileManager.default.createFile(atPath: self.project.bundleURL.appendingPathComponent("Info.plist").path, contents: infoPlistDataSerialized)
        }
    }
    
    func compile() throws {
        if !self.compilerJobs.isEmpty {
            let pstep: Double = 1.00 / Double(self.compilerJobs.count)
            guard let threader = LDEThreadGroupController(usersetThreadCount: ()) else {
                throw NSError(domain: "com.cr4zy.nyxian.builder.compile", code: 1, userInfo: [NSLocalizedDescriptionKey:"Failed to compile source code, because threader creation failed"])
            }
            
            for _ in self.compilerJobs {
                threader.enter();
            }
            
            for job in self.compilerJobs {
                threader.dispatchExecution( {
                    defer { XCButton.incrementProgress(withValue: pstep) }
                    
                    guard let astUnit: CCKASTUnit = CCKCompiler.execute(job),
                          let file: CCKFile = astUnit.file else {
                        threader.lockdown = true
                        return
                    }
                    
                    let issues: [CCKDiagnostic] = astUnit.diagnostics
                    self.database.setFileDebug(ofPath: file.fileURL.path, synItems: issues)
                    
                    if astUnit.hasErrorOccured {
                        threader.lockdown = true
                        return
                    }
                }, withCompletion: nil)
            }
            
            threader.wait()
            
            if threader.lockdown {
                throw NSError(domain: "com.cr4zy.nyxian.builder.compile", code: 1, userInfo: [NSLocalizedDescriptionKey:"Failed to compile source code"])
            }
            
            do {
                try self.argsString.write(to: self.project.cacheURL.appendingPathComponent("args.txt"), atomically: false, encoding: .utf8)
            } catch {
                throw NSError(domain: "com.cr4zy.nyxian.builder.compile", code: 1, userInfo: [NSLocalizedDescriptionKey:error.localizedDescription])
            }
        }
    }
    
    func compileSwift() throws {
        guard !self.compilerSwiftJobs.isEmpty else { return }
        
        let pstep: Double = 1.00 / Double(self.compilerSwiftJobs.count + 1)
        
        let baseArguments: [String] = self.project.projectConfig.swiftFlags
        let moduleName: String = self.project.projectConfig.displayName
        let modulePath: String = self.project.cacheURL.appendingPathComponent(moduleName).path
        let allSources: [String] = self.compilerSwiftJobs.map { $0.0 }
        
        let emitArgs: [String] = baseArguments + ["-emit-module", "-emit-module-path", modulePath, "-module-name", moduleName] + allSources
        var issues: NSArray?
        let succeeded: Bool = CCKSwiftCompiler.execute(withArguments: emitArgs, outDiagnostic:&issues)
        
        XCButton.incrementProgress(withValue: pstep)
        
        if let issues = issues as? [CCKDiagnostic] {
            var sortedIssues: [URL:[CCKDiagnostic]] = [:]
            for issue in issues {
                if var fileIssueArray: [CCKDiagnostic] = sortedIssues[issue.fileSourceLocation.fileURL] {
                    fileIssueArray.append(issue)
                    sortedIssues[issue.fileSourceLocation.fileURL] = fileIssueArray
                } else {
                    let fileIssueArray: [CCKDiagnostic] = [issue]
                    sortedIssues[issue.fileSourceLocation.fileURL] = fileIssueArray
                }
            }
            
            for key in sortedIssues.keys {
                if let fileIssueArray: [CCKDiagnostic] = sortedIssues[key] {
                    self.database.setFileDebug(ofPath: key.path, synItems: fileIssueArray)
                }
            }
        }
        
        if !succeeded {
            throw NSError(domain: "com.cr4zy.nyxian.builder.compile", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to emit Swift module"])
        }
        
        for job in self.compilerSwiftJobs {
            let others = allSources.filter { $0 != job.0 }
            let jobArguments: [String] = baseArguments + ["-module-name", moduleName, "-c", "-primary-file", job.0] + others + ["-o", job.1]
            
            var issues: NSArray?
            let succeeded: Bool = CCKSwiftCompiler.execute(withArguments: jobArguments, outDiagnostic:&issues)
            XCButton.incrementProgress(withValue: pstep)
            
            let swiftIssues: [CCKDiagnostic] = issues as! [CCKDiagnostic]
            self.database.setFileDebug(ofPath: job.0, synItems: swiftIssues)
            
            if !succeeded {
                throw NSError(domain: "com.cr4zy.nyxian.builder.compile", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to compile swift source code"])
            }
        }
    }
    
    func link() throws {
        for job in linkerJobs {
            var issues: NSArray?
            
            if !job.execute(withOutDiagnostics: &issues) {
                self.database.addDiagnosticMessages(title: "Linker", items: (issues as? [CCKDiagnostic]) ?? [], clearPrevious: true)
                throw NSError(domain: "com.cr4zy.nyxian.builder.link", code: 1, userInfo: [NSLocalizedDescriptionKey:"Linking object files together to a executable failed"])
            }
            
            self.database.addDiagnosticMessages(title: "Linker", items: (issues as? [CCKDiagnostic]) ?? [], clearPrevious: true)
        }
    }
    
    func install(buildType: Builder.BuildType, outPipe: Pipe?, inPipe: Pipe?) throws {
#if !JAILBREAK_ENV
        if(buildType == .RunningApp) {
            if LCUtils.certificateData() == nil {
                throw NSError(domain: "com.cr4zy.nyxian.builder.install", code: 1, userInfo: [NSLocalizedDescriptionKey:"No code signature present to perform signing, import code signature in Settings > Certificate. Note that the code signature must be the same code signature used to sign Nyxian."])
            }
            
            if self.project.projectConfig.type == .app {
                let semaphore = DispatchSemaphore(value: 0)
                var nsError: NSError? = nil
                
                LCUtils.signAppBundle(withZSign: self.project.bundleURL) { [weak self] result, error in
                    guard let self = self else { return }
                    
                    if(self.project.projectConfig.signMachOWithNyxianEntitlements)
                    {
                        macho_after_sign(self.project.machoURL.path, self.project.entitlementsConfig.entitlement)
                    }
                    
                    guard result else {
                        nsError = NSError(domain: "com.cr4zy.nyxian.builder.install", code: 1, userInfo: [NSLocalizedDescriptionKey:error?.localizedDescription ?? "Unknown error happened signing application"])
                        semaphore.signal()
                        return
                    }
                    
                    guard LDEApplicationWorkspace.shared().installApplication(atBundlePath: project.bundleURL.path) else {
                        nsError = NSError(domain: "com.cr4zy.nyxian.builder.install", code: 1, userInfo: [NSLocalizedDescriptionKey:error?.localizedDescription ?? "Unknown error happened installing application"])
                        semaphore.signal()
                        return
                    }
                    
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
                    
                    semaphore.signal()
                }
                semaphore.wait()
                
                if let nsError = nsError {
                    throw nsError
                }
            } else if self.project.projectConfig.type == .utility {
                if LCUtils.certificateData() == nil {
                    throw NSError(domain: "com.cr4zy.nyxian.builder.install", code: 1, userInfo: [NSLocalizedDescriptionKey:"No code signature present to perform signing, import code signature in Settings > Certificate. Note that the code signature must be the same code signature used to sign Nyxian."])
                }
                
                MachOObject.signBinary(atPath: self.project.machoURL.path)
                macho_after_sign(self.project.machoURL.path, self.project.entitlementsConfig.entitlement)
                
                if let path: String = LDEApplicationWorkspace.shared().fastpathUtility(self.project.machoURL.path) {
                    DispatchQueue.main.sync {
                        let TerminalSession: NXWindowSessionTerminal = NXWindowSessionTerminal(utilityPath: path)
                        NXWindowServer.shared().openWindow(with: TerminalSession, withCompletion: nil)
                    }
                } else {
                    throw NSError(domain: "com.cr4zy.nyxian.builder.install", code: 1, userInfo: [NSLocalizedDescriptionKey:"Failed to fastpath install utility"])
                }
            }
        } else {
            macho_after_sign(self.project.machoURL.path, self.project.entitlementsConfig.entitlement)
            try self.package()
        }
#else
        
        try self.package()
        
        if buildType == .RunningApp,
          self.project.projectConfig.type == .app {
            // installing app
            var output: NSString?
            if shell(["\(Bundle.main.bundlePath)/tshelper","install",self.project.packageURL.path], 0, nil, &output) != 0 {
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
        let entitlementsPath: String = "\(self.project.url.path)/Config/Entitlements.plist"
        if FileManager.default.fileExists(atPath: entitlementsPath),
           self.project.projectConfig.type == .app {
            // pseudo signing executable
            if !ZSigner.adhocSignMachO(atPath: self.project.machoURL!.path, bundleId: self.project.projectConfig.bundleid!, entitlementData: try Data(contentsOf: URL(fileURLWithPath: entitlementsPath))) {
                throw NSError(domain: "com.cr4zy.nyxian.builder.install", code: 1, userInfo: [NSLocalizedDescriptionKey:"Unknown error happened pseudo signing application with entitlements"])
            }
        }
#endif // JAILBREAK_ENV
        
        zipDirectoryAtPath(project.payloadURL.path, project.packageURL.path, true)
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
            NXBootstrap.shared().waitTillDone()
            
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
                    (nil,nil,{ try builder.compileSwift() }),
                    (nil,nil,{ try builder.compile() }),
                    ("link",0.3,{ try builder.link() }),
                    ("arrow.down.app.fill",nil,{try builder.install(buildType: buildType, outPipe: outPipe, inPipe: inPipe) })
                ];
                
                // doit
                try progressFlowBuilder(flow: flow)
            } catch {
                try? builder.clean()
                result = false
                builder.database.addMessage(message: error.localizedDescription, severity: .error)
            }
            
            builder.database.saveDatabase(toPath: project.cacheURL.appendingPathComponent("debug.json").path)
            
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
                share(url: project.packageURL, remove: true)
            }
            
            completion()
        }
    }
}
