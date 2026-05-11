/*
 SPDX-License-Identifier: AGPL-3.0-or-later

 Copyright (C) 2025 - 2026 mach-port-t

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
import MobileDevelopmentKit

#if JAILBREAK_ENV

// https://github.com/davidmurray/ios-reversed-headers/blob/b8fd3093e0e72107034792ed65272880820fecd5/BackBoardServices/BackBoardServices.h#L64
@_silgen_name("BKSTerminateApplicationForReasonAndReportWithDescription") func BKSTerminateApplicationForReasonAndReportWithDescription(_ bundleID: CFString,_ unknown: Int, _ unknown1: Int, _ desc: CFString)

#endif // JAILBREAK_ENV

class LDEPhaseRunner: MDKPhaseRunner {
    private var pstep: Double = 0.0 // TODO: needs to be float for extremely large projects
    private var steps: Int = 0 {
        didSet {
            self.pstep = 1.0 / Double(self.steps)
            self.refreshDoneStep()
        }
    }
    private var donestep: Int = 0 {
        didSet {
            self.refreshDoneStep()
        }
    }
    
    private func refreshDoneStep() {
        let progress: Double = self.pstep * Double(self.donestep)
        XCButton.updateProgress(withValue: progress)
    }
    
    override func run(_ job: MDKJob, within phase: MDKPhase) -> Bool {
        let success: Bool = super.run(job, within: phase)
        self.donestep += 1
        return success
    }
    
    override func run(_ phase: MDKPhase) -> Bool {
        switch phase.type {
        case .compiler:
            fallthrough
        case .swiftCompiler:
            XCButton.switchImageSync(withSystemName: "hammer.fill", animated: true, withDuration: 0.25)
        case .linker:
            XCButton.switchImageSync(withSystemName: "link", animated: true, withDuration: 0.25)
        default:
            break
        }
        return super.run(phase)
    }
    
    override func runPhases(withPhases phases: [Any]) -> Bool {
        for phase in phases {
            if let phase: MDKPhase = phase as? MDKPhase {
                self.steps += phase.jobs.count
            }
        }
        return super.runPhases(withPhases: phases)
    }
}

class Builder: NSObject, MDKDriverDelegate, MDKPhaseRunnerDelegate {
    private let project: NXProject
    
    private let database: DebugDatabase
    
    private var phaseRunner: LDEPhaseRunner
    private let dependencyScanner: MDKDependencyScanner
    
    private let incrementalBuild: Bool = UserDefaults.standard.object(forKey: "LDEIncrementalBuild") as? Bool ?? true
    private let projectDirty: Bool
    
    private let argsString: String
    
    init?(project: NXProject) {
        self.project = project
        self.project.reload()
        
        if !self.project.syncFolderStructureToCache() {
            return nil
        }
        
        self.database = DebugDatabase.getDatabase(ofPath: "\(self.project.cacheURL.path)/debug.json")
        self.database.reuseDatabase()
        
        self.dependencyScanner = MDKDependencyScanner(arguments: self.project.projectConfig.compilerFlags)
        
        guard let swiftFiles = LDEFilesFinder(self.project.url.path, ["swift"], ["Resources","Config"]),
              let codeFiles = LDEFilesFinder(self.project.url.path, ["c","cpp","m","mm"], ["Resources","Config"]) else {
            self.database.addMessage(message: "A fatal error has happened finding code files.", severity: .error)
            self.database.saveDatabase(toPath: project.cacheURL.appendingPathComponent("debug.json").path)
            return nil
        }
        
        var driverFlags: [String] = []
        driverFlags.append(contentsOf: swiftFiles)
        driverFlags.append(contentsOf: codeFiles)
        driverFlags.append("-o")
        driverFlags.append(self.project.machoURL.path)
        
        let phaseEngine: MDKPhaseEngine
        if swiftFiles.isEmpty && codeFiles.isEmpty {
            self.database.addMessage(message: "Nothing to build. No code files were found, please create a code file.", severity: .error)
            self.database.saveDatabase(toPath: project.cacheURL.appendingPathComponent("debug.json").path)
            return nil
        } else if !swiftFiles.isEmpty {
            driverFlags.append(contentsOf: self.project.projectConfig.swiftFlags)
            driverFlags.append("-module-name")
            driverFlags.append(NXMakeContentCodeFriendly(self.project.projectConfig.displayName))
            
            phaseEngine = MDKPhaseEngine(swiftFlags: driverFlags, withOtherClangFlags: self.project.projectConfig.compilerFlags, withOtherLinkerFlags: self.project.projectConfig.linkerFlags)
        } else {
            driverFlags.append(contentsOf: self.project.projectConfig.compilerFlags)
            
            phaseEngine = MDKPhaseEngine(clangFlags: driverFlags, withOtherLinkerFlags: self.project.projectConfig.linkerFlags)
        }
        
        self.argsString = driverFlags.joined(separator: " ")
        
        // Check if the args string matches up
        if self.incrementalBuild,
           let args: String = (try? String(contentsOf: self.project.cacheURL.appendingPathComponent("args.txt"), encoding: .utf8)) {
            self.projectDirty = args != self.argsString
        } else {
            self.projectDirty = true
            self.database.clearDatabase() /* nothing valid anymore */
        }
        
        guard let phaseRunner = LDEPhaseRunner(engine: phaseEngine) else {
            return nil
        }
        self.phaseRunner = phaseRunner
        
        super.init()
        
        phaseEngine.delegate = self
        self.phaseRunner.delegate = self
    }
    
    func driver(_ driver: MDKDriver,
                outputPathForInputFile file: MDKFile) -> String? {
        return "\(self.project.cacheURL.path)/\(NXExpectedObjectFileURLForFileURL(NXRelativeURLFromBaseURLToFullURL(self.project.url, file.fileURL)).path)"
    }
    
    func driver(_ driver: MDKDriver,
                skipCompileForInputFile file: MDKFile) -> Bool {
        if !CCFileTypeIsSwiftFile(file.type),
           !self.projectDirty {
            
            let path: String = file.fileURL.path
            let objectPath = "\(self.project.cacheURL.path)/\(NXExpectedObjectFileURLForFileURL(NXRelativeURLFromBaseURLToFullURL(self.project.url, file.fileURL)).path)"
            
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
    
    func runner(_ runner: MDKPhaseRunner,
                multithreadingThreadCountFor phase: MDKPhase) -> CFIndex {
        return CFIndex(LDEGetUserSetThreadCount())
    }
    
    func runner(_ runner: MDKPhaseRunner,
                phase: MDKPhase,
                finishedRunning job: MDKJob,
                withResultingDiagnostics diagnostics: [MDKDiagnostic]?,
                withMainSource mainSource: String?,
                wasSuccessful success: Bool) {
        if let diagnostics = diagnostics {
            if job.type == .linker {
                self.database.addDiagnosticMessages(title: "Linker", items: diagnostics, clearPrevious: true)
            } else if let mainSource = mainSource {
                self.database.setFileDebug(ofPath: mainSource, synItems: diagnostics)
            }
        }
    }
    
    func headsup() throws {
        let type = project.projectConfig.schemeKind
        if(type != .app && type != .utility) {
            throw NSError(domain: "com.cr4zy.nyxian.builder.headsup", code: 1, userInfo: [NSLocalizedDescriptionKey:"Project type \(type) is unknown."])
        }
        
        guard let osVersionNeeded: NXOSVersion = NXOSVersion(versionString: project.projectConfig.deploymentTarget) else {
            throw NSError(domain: "com.cr4zy.nyxian.builder.headsup", code: 1, userInfo: [NSLocalizedDescriptionKey:"App cannot be build, host version cannot be compared. Version \(project.projectConfig.deploymentTarget!) is not valid."])
        }
        
        // Nyxian requirement checks
        if osVersionNeeded < NXOSVersion.minimumBuildVersion {
            throw NSError(domain: "com.cr4zy.nyxian.builder.headsup", code: 1, userInfo: [NSLocalizedDescriptionKey:"Deployment target \(osVersionNeeded) is older than Nyxian supports building for. Nyxian supports \(NXOSVersion.minimumBuildVersion) at a minimum."])
        }
        
        if osVersionNeeded > NXOSVersion.maximumBuildVersion {
            throw NSError(domain: "com.cr4zy.nyxian.builder.headsup", code: 1, userInfo: [NSLocalizedDescriptionKey:"Deployment target \(osVersionNeeded) is newer than Nyxian supports building for. Nyxian supports \(NXOSVersion.maximumBuildVersion) at a maximum."])
        }
        
        // Project requirement check
        if osVersionNeeded > NXOSVersion.hostVersion {
            throw NSError(domain: "com.cr4zy.nyxian.builder.headsup", code: 1, userInfo: [NSLocalizedDescriptionKey:"Deployment target \(osVersionNeeded) is needed to build the app, but host version \(NXOSVersion.hostVersion) is present."])
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
        if self.project.projectConfig.schemeKind == .app {
            try? FileManager.default.removeItem(atPath: self.project.payloadURL.path)
            try? FileManager.default.removeItem(atPath: self.project.packageURL.path)
        }
    }
    
    func prepare() throws {
        if project.projectConfig.schemeKind == .app {
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
    
    func executeRunner() throws {
        if !self.phaseRunner.runPhases() {
            throw NSError(domain: "com.cr4zy.nyxian.builder.runner", code: 1, userInfo: [NSLocalizedDescriptionKey:"Failed to run project."])
        }
        
        do {
            try self.argsString.write(to: self.project.cacheURL.appendingPathComponent("args.txt"), atomically: false, encoding: .utf8)
        } catch {
            throw NSError(domain: "com.cr4zy.nyxian.builder.runner", code: 1, userInfo: [NSLocalizedDescriptionKey:error.localizedDescription])
        }
    }
    
    func install(buildType: Builder.BuildType, outPipe: Pipe?, inPipe: Pipe?) throws {
        let spinnerStart = DispatchWorkItem { XCButton.startSpinning() }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0, execute: spinnerStart)
        defer {
            spinnerStart.cancel()
            XCButton.stopSpinning()
        }
        
#if !JAILBREAK_ENV
        if(buildType == .RunningApp) {
            if LCUtils.certificateData() == nil {
                throw NSError(domain: "com.cr4zy.nyxian.builder.install", code: 1, userInfo: [NSLocalizedDescriptionKey:"No code signature present to perform signing, import code signature in Settings > Certificate. Note that the code signature must be the same code signature used to sign Nyxian."])
            }
            
            if self.project.projectConfig.schemeKind == .app {
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
            } else if self.project.projectConfig.schemeKind == .utility {
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
          self.project.projectConfig.schemeKind == .app {
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
           self.project.projectConfig.schemeKind == .app {
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
        
        MDKPthreadDispatch {
            NXBootstrap.shared().waitTillDone()
            
            var result: Bool = true
            guard let builder: Builder = Builder(
                project: project
            ) else {
                completion(false)
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
                    (nil,nil,{ try builder.executeRunner() }),
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
    autoreleasepool {
        targetViewController.navigationItem.titleView?.isUserInteractionEnabled = false
        XCButton.switchImageSync(withSystemName: "hammer.fill", animated: false)
        guard let oldBarButtons: [UIBarButtonItem] = targetViewController.navigationItem.rightBarButtonItems else { return }
        
        let barButton: UIBarButtonItem = UIBarButtonItem(customView: XCButton.shared())
        
        targetViewController.navigationItem.setRightBarButtonItems([barButton], animated: true)
        targetViewController.navigationItem.setHidesBackButton(true, animated: true)
        
        NXDocumentManager.shared().saveAll {
            NXDocumentManager.shared().changeAllLockState(toBoolean: true)
            Builder.buildProject(withProject: project, buildType: buildType, outPipe: outPipe, inPipe: inPipe) { result in
                NXDocumentManager.shared().changeAllLockState(toBoolean: false)
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
    }
}
