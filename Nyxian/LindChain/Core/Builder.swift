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

import Foundation
import Combine

class Builder {
    private let project: NXProject
    private let compiler: Compiler
    private let linker: Linker
    private let argsString: String
    
    private var dirtySourceFiles: [String] = []
    private var objectFiles: [String] = []
    
    let database: DebugDatabase
    
    init(project: NXProject) {
        self.project = project
        self.project.reload()
        
        self.database = DebugDatabase.getDatabase(ofPath: "\(self.project.cachePath!)/debug.json")
        self.database.reuseDatabase()
        
        let genericCompilerFlags: [String] = self.project.projectConfig.generateCompilerFlags() as! [String]
        
        self.compiler = Compiler(genericCompilerFlags)
        self.linker = Linker()
        
        try? syncFolderStructure(from: project.path.URLGet(), to: project.cachePath.URLGet())
        
        self.dirtySourceFiles = LDEFilesFinder(self.project.path, ["c","cpp","m","mm"], ["Resources"])
        for item in dirtySourceFiles {
            objectFiles.append("\(self.project.cachePath!)/\(expectedObjectFile(forPath: relativePath(from: self.project.path.URLGet(), to: item.URLGet())))")
        }
        
        // Check if args have changed
        self.argsString = genericCompilerFlags.joined(separator: " ")
        var fileArgsString: String = ""
        if FileManager.default.fileExists(atPath: "\(self.project.cachePath!)/args.txt") {
            // Check if the args string matches up
            fileArgsString = (try? String(contentsOf: URL(fileURLWithPath: "\(self.project.cachePath!)/args.txt"), encoding: .utf8)) ?? ""
        }
        
        if(fileArgsString == self.argsString), self.project.projectConfig.increment {
            self.dirtySourceFiles = self.dirtySourceFiles.filter { self.isFileDirty($0) }
        }
    }
    
    ///
    /// Function to detect if a file is dirty (has to be recompiled)
    ///
    private func isFileDirty(_ item: String) -> Bool {
        let objectFilePath = "\(self.project.cachePath!)/\(expectedObjectFile(forPath: relativePath(from: self.project.path.URLGet(), to: item.URLGet())))"
        
        // Checking if the source file is newer than the compiled object file
        guard let sourceDate = try? FileManager.default.attributesOfItem(atPath: item)[.modificationDate] as? Date,
              let objectDate = try? FileManager.default.attributesOfItem(atPath: objectFilePath)[.modificationDate] as? Date,
              objectDate > sourceDate else {
            return true
        }
        
        // Checking if the header files included by the source code are newer than the object file
        for header in HeaderIncludationsGatherer(path: item).includes {
            guard FileManager.default.fileExists(atPath: header),
                  let headerDate = try? FileManager.default.attributesOfItem(atPath: header)[.modificationDate] as? Date,
                  objectDate > headerDate else {
                return true
            }
        }
        
        return false
    }
    
    func headsup() throws {
        func osBuildVersion() -> String? {
            var size = 0
            // First call to get the required size
            sysctlbyname("kern.osversion", nil, &size, nil, 0)
            var buffer = [CChar](repeating: 0, count: size)
            // Second call to actually get the value
            sysctlbyname("kern.osversion", &buffer, &size, nil, 0)
            return String(cString: buffer)
        }
        
        let type = project.projectConfig.type
        if(type != 1 && type != 2) {
            throw NSError(domain: "com.cr4zy.nyxian.builder.headsup", code: 1, userInfo: [NSLocalizedDescriptionKey:"Project type \(type) is unknown"])
        }
        
        func operatingSystemVersion(from string: String) -> OperatingSystemVersion? {
            let components = string.split(separator: ".").map { Int($0) ?? 0 }
            guard components.count >= 2 else { return nil }
            
            let major = components[0]
            let minor = components[1]
            let patch = components.count > 2 ? components[2] : 0
            
            return OperatingSystemVersion(majorVersion: major, minorVersion: minor, patchVersion: patch)
        }

        guard let neededMinimumOSVersion = operatingSystemVersion(from: project.projectConfig.platformMinimumVersion) else {
            throw NSError(domain: "com.cr4zy.nyxian.builder.headsup", code: 1, userInfo: [NSLocalizedDescriptionKey:"App cannot be build, host version cannot be compared. Version \(project.projectConfig.platformMinimumVersion!) is not valid"])
        }
        if !ProcessInfo.processInfo.isOperatingSystemAtLeast(neededMinimumOSVersion) {
            let version = ProcessInfo.processInfo.operatingSystemVersion
            let versionString = "\(version.majorVersion).\(version.minorVersion).\(version.patchVersion)"
            let neededVersionString = "\(neededMinimumOSVersion.majorVersion).\(neededMinimumOSVersion.minorVersion).\(neededMinimumOSVersion.patchVersion)"
            
            throw NSError(domain: "com.cr4zy.nyxian.builder.headsup", code: 1, userInfo: [NSLocalizedDescriptionKey:"System version \(neededVersionString) is needed to build the app, but version \(versionString) (\(osBuildVersion() ?? "Custom")) is present"])
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
        if self.dirtySourceFiles.count > 0 {
            let pstep: Double = 1.00 / Double(self.dirtySourceFiles.count)
            guard let threader = LDEThreadGroupController(threads: UInt32(self.project.projectConfig.threads)) else {
                throw NSError(domain: "com.cr4zy.nyxian.builder.compile", code: 1, userInfo: [NSLocalizedDescriptionKey:"Failed to compile source code, because threader creation failed"])
            }
            
            for filePath in self.dirtySourceFiles {
                threader.dispatchExecution( {
                    var issues: NSArray?
                    
                    if self.compiler.compileObject(
                        filePath,
                        outputFile: "\(self.project.cachePath!)/\(expectedObjectFile(forPath: relativePath(from: self.project.path.URLGet(), to: filePath.URLGet())))",
                        issues: &issues
                    ) != 0 {
                        threader.lockdown = true
                    }
                    
                    self.database.setFileDebug(ofPath: filePath, synItems: (issues as? [Synitem]) ?? [])
                    
                    XCButton.incrementProgress(withValue: pstep)
                }, withCompletion: nil)
            }
            
            threader.wait()
            
            if threader.lockdown {
                throw NSError(domain: "com.cr4zy.nyxian.builder.compile", code: 1, userInfo: [NSLocalizedDescriptionKey:"Failed to compile source code"])
            }
            
            do {
                try self.argsString.write(to: URL(fileURLWithPath: "\(project.cachePath!)/args.txt"), atomically: false, encoding: .utf8)
            } catch {
                throw NSError(domain: "com.cr4zy.nyxian.builder.compile", code: 1, userInfo: [NSLocalizedDescriptionKey:error.localizedDescription])
            }
        }
    }
    
    func link() throws {
        let ldArgs: [String] = self.project.projectConfig.generateLinkerFlags() + self.project.projectConfig.linkerFlags as! [String] + [
            "-o",
            self.project.machoPath
        ] + objectFiles
        
        if self.linker.ld64((ldArgs as NSArray).mutableCopy() as? NSMutableArray) != 0 {
            throw NSError(domain: "com.cr4zy.nyxian.builder.link", code: 1, userInfo: [NSLocalizedDescriptionKey:self.linker.error ?? "Linking object files together to a executable failed"])
        }
    }
    
    func install(buildType: Builder.BuildType) throws {
#if !JAILBREAK_ENV
        if(buildType == .RunningApp) {
            if self.project.projectConfig.type == NXProjectType.app.rawValue {
                let semaphore = DispatchSemaphore(value: 0)
                var nsError: NSError? = nil
                if LCUtils.certificateData() == nil {
                    throw NSError(domain: "com.cr4zy.nyxian.builder.install", code: 1, userInfo: [NSLocalizedDescriptionKey:"No code signature present to perform signing, import code signature in Settings > Miscellanous > Import Certificate. Note that the code signature must be the same code signature used to sign Nyxian."])
                }
                LCAppInfo(bundlePath: project.bundlePath)?.patchExecAndSignIfNeed(completionHandler: { [weak self] result, errorDescription in
                    guard let self = self else { return }
                    if result {
                        if(LDEApplicationWorkspace.shared().installApplication(atBundlePath: self.project.bundlePath)) {
                            let application: LDEApplicationObject = LDEApplicationWorkspace.shared().applicationObject(forBundleID: project.projectConfig.bundleid)
                            if let entHash: String = LDETrust.entHashOfExecutable(atPath: application.executablePath) {
                                TrustCache.shared().setEntitlementsForHash(entHash, usingEntitlements: project.entitlementsConfig.generateEntitlements())
                            }
                            LDEProcessManager.shared().spawnProcess(withBundleIdentifier: self.project.projectConfig.bundleid, withKernelSurfaceProcess: kernel_proc(), doRestartIfRunning: true)
                        } else {
                            nsError = NSError(domain: "com.cr4zy.nyxian.builder.install", code: 1, userInfo: [NSLocalizedDescriptionKey:"Failed to install application"])
                        }
                    } else {
                        nsError = NSError(domain: "com.cr4zy.nyxian.builder.install", code: 1, userInfo: [NSLocalizedDescriptionKey:errorDescription ?? "Unknown error happened signing application"])
                    }
                    semaphore.signal()
                }, progressHandler: { progress in }, forceSign: false)
                semaphore.wait()
                
                if let nsError = nsError {
                    throw nsError
                }
            } else if self.project.projectConfig.type == NXProjectType.utility.rawValue {
                if let path: String = LDEApplicationWorkspace.shared().fastpathUtility(self.project.machoPath) {
                    DispatchQueue.main.sync {
                        if let entHash: String = LDETrust.entHashOfExecutable(atPath: path) {
                            TrustCache.shared().setEntitlementsForHash(entHash, usingEntitlements: project.entitlementsConfig.generateEntitlements())
                        }
                        let TerminalSession: LDEWindowSessionTerminal = LDEWindowSessionTerminal(utilityPath: path)
                        LDEWindowServer.shared().openWindow(withSession: TerminalSession, identifier: nil)
                    }
                }
            }
        } else {
            try? self.package()
        }
#else
        try? self.package()
        if(buildType == .RunningApp),
          self.project.projectConfig.type == NXProjectType.app.rawValue {
            var output: NSString?
            if shell("\(Bundle.main.bundlePath)/tshelper install '\(self.project.packagePath ?? "")'", 0, nil, &output) != 0 {
                throw NSError(domain: "com.cr4zy.nyxian.builder.install", code: 1, userInfo: [NSLocalizedDescriptionKey:output ?? "Unknown error happened installing application"])
            }
        }
#endif // !JAILBREAK_ENV
    }
    
    func package() throws {
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
                             completion: @escaping (Bool) -> Void) {
        project.projectConfig.reloadData()
        
        XCButton.resetProgress()
        
        LDEPthreadDispatch {
            Bootstrap.shared.waitTillDone()
            
            var result: Bool = true
            let builder: Builder = Builder(
                project: project
            )
            
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
                    ("arrow.down.app.fill",nil,{try builder.install(buildType: buildType) })
                ];
                
                // doit
                try progressFlowBuilder(flow: flow)
            } catch {
                try? builder.clean()
                result = false
                builder.database.addInternalMessage(message: error.localizedDescription, severity: .Error)
            }
            
            builder.database.saveDatabase(toPath: "\(project.cachePath!)/debug.json")
            
            completion(result)
        }
    }
}

func buildProjectWithArgumentUI(targetViewController: UIViewController,
                                project: NXProject,
                                buildType: Builder.BuildType,
                                completion: @escaping () -> Void = {}) {
    targetViewController.navigationItem.titleView?.isUserInteractionEnabled = false
    XCButton.switchImageSync(withSystemName: "hammer.fill", animated: false)
    guard let oldBarButtons: [UIBarButtonItem] = targetViewController.navigationItem.rightBarButtonItems else { return }
    
    let barButton: UIBarButtonItem = UIBarButtonItem(customView: XCButton.shared())
    
    targetViewController.navigationItem.setRightBarButtonItems([barButton], animated: true)
    targetViewController.navigationItem.setHidesBackButton(true, animated: true)
    
    Builder.buildProject(withProject: project, buildType: buildType) { result in
        DispatchQueue.main.async {
            targetViewController.navigationItem.setRightBarButtonItems(oldBarButtons, animated: true)
            targetViewController.navigationItem.setHidesBackButton(false, animated: true)
            
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

extension UIViewController {
    func topMostViewController() -> UIViewController {
        if let presented = presentedViewController {
            return presented.topMostViewController()
        }
        if let nav = self as? UINavigationController {
            return nav.visibleViewController?.topMostViewController() ?? nav
        }
        if let tab = self as? UITabBarController {
            return tab.selectedViewController?.topMostViewController() ?? tab
        }
        return self
    }
}
