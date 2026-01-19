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

@objc class Bootstrap: NSObject {
    var semaphore: DispatchSemaphore?
#if !JAILBREAK_ENV
    let rootPath: String = "\(NSHomeDirectory())/Documents"
#else
    let rootPath: String = "\(NSHomeDirectory())/Documents/com.cr4zy.nyxian.root"
#endif // !JAILBREAK_ENV
    let newestBootstrapVersion: Int = 9
    
    // Paths that we for sure do not need
    let bootstrapDeletionIfFoundPaths: [String] = [
        "/Config",
        "/Certificates"
    ]
    
    let bundleFixupExecutablePaths: [String] = [
        "/tshelper"
    ]
    
    var bootstrapPlistPath: String {
        bootstrapPath("/bootstrap.plist")
    }
    
    var bootstrapVersion: Int {
        get {
            guard FileManager.default.fileExists(atPath: bootstrapPlistPath),
                  let dict = NSDictionary(contentsOfFile: bootstrapPlistPath),
                  let version = dict["BootstrapVersion"] as? Int else {
                return 0
            }
            return version
        }
        set {
            let cstep = 1.0 / Double(self.newestBootstrapVersion)
            XCButton.updateProgress(withValue: cstep * Double(newValue))
            let dict: NSDictionary = ["BootstrapVersion": newValue]
            dict.write(to: URL(fileURLWithPath: bootstrapPlistPath), atomically: true)
        }
    }
    
    var isBootstrapInstalled: Bool {
        return FileManager.default.fileExists(atPath: bootstrapPlistPath) && bootstrapVersion > 0
    }
    
    @objc func bootstrapPath(_ path: String) -> String {
        var path: String = path
        if path.hasPrefix("/") { path.removeFirst() }
        return URL(fileURLWithPath: path, relativeTo: URL(fileURLWithPath: rootPath)).path
    }
    
    func clearPath(path: String) {
        let fileManager = FileManager.default
        let target = bootstrapPath(path)

        if let files = try? fileManager.contentsOfDirectory(atPath: target) {
            for file in files {
                try? fileManager.removeItem(atPath: "\(target)/\(file)")
            }
        }
    }
    
    func migrateToBootstrapPlistIfNeeded() {
        if FileManager.default.fileExists(atPath: bootstrapPlistPath) {
            return
        }

        let legacyVersion = UserDefaults.standard.integer(forKey: "LDEBootstrapVersion")
        if legacyVersion > 0 && legacyVersion < 10 {
            print("[*] migrating bootstrap state from UserDefaults (v\(legacyVersion))")
            bootstrapVersion = legacyVersion
            UserDefaults.standard.removeObject(forKey: "LDEBootstrapVersion")
        }
    }
    
    @objc func bootstrap() {
        print("[*] checking upon nyxian bootstrap")
        
        LDEPthreadDispatch {
            // Bootstrap migration
            self.migrateToBootstrapPlistIfNeeded()
            
#if JAILBREAK_ENV
            if(!FileManager.default.fileExists(atPath: self.rootPath)) {
                do {
                    try FileManager.default.createDirectory(atPath: self.rootPath, withIntermediateDirectories: true)
                } catch {
                    exit(0)
                }
            }
#endif // JAILBREAK_ENV
            
            print("[*] install status: \(self.isBootstrapInstalled)")
            print("[*] version: \(self.bootstrapVersion)")
            
            do {
                
                if !self.isBootstrapInstalled ||
                    self.bootstrapVersion != self.newestBootstrapVersion {
                
                    // "e need to clear the entire path if its not installed
                    if !self.isBootstrapInstalled {
                        print("[*] Bootstrap is not installed, clearing")
                        self.clearPath(path: "/")
                    }
                
                    if self.bootstrapVersion < 1 {
                        // Creating bootstrap base
                        print("[*] Creating folder structures")
                    
                        // We need include to put clangs includations into
                        try FileManager.default.createDirectory(atPath: self.bootstrapPath("/Include"), withIntermediateDirectories: false)
                        try FileManager.default.createDirectory(atPath: self.bootstrapPath("/SDK"), withIntermediateDirectories: false)
                        try FileManager.default.createDirectory(atPath: self.bootstrapPath("/Projects"), withIntermediateDirectories: false)
                    
                        self.bootstrapVersion = 1
                    }
                
                    if self.bootstrapVersion < 5 {
                        print("[*] creating bootstrap cache")
                        try FileManager.default.createDirectory(atPath: self.bootstrapPath("/Cache"), withIntermediateDirectories: false)
                        self.bootstrapVersion = 5
                    }
                
                    if self.bootstrapVersion < 7 {
                        if FileManager.default.fileExists(atPath: self.bootstrapPath("/SDK")) {
                            print("[*] removing deprecated sdk")
                            try FileManager.default.removeItem(atPath: self.bootstrapPath("/SDK"))
                        }
                    
                        print("[*] downloading sdk")
                    
                        if !fdownload("https://nyxian.app/bootstrap/sdk26.1.zip", "sdk.zip") {
                            print("[*] sdk download failed")
                            throw NSError(domain: "", code: 0, userInfo: [NSLocalizedDescriptionKey: "Download failed!"])
                        }
                    
                        print("[*] extracting sdk.zip")
                        unzipArchiveAtPath("\(NSTemporaryDirectory())/sdk.zip", self.bootstrapPath("/SDK"))
                        self.bootstrapVersion = 8
                    }
                
                    if self.bootstrapVersion < 9 {
                        if FileManager.default.fileExists(atPath: self.bootstrapPath("/Include")) {
                            try FileManager.default.removeItem(atPath: self.bootstrapPath("/Include"))
                        }
                    
                        print("[*] bootstrapping clang includes")
                    
                        if !fdownload("https://nyxian.app/bootstrap/include.zip", "include.zip") {
                            print("[*] Bootstrap download failed\n")
                            throw NSError(domain: "", code: 0, userInfo: [NSLocalizedDescriptionKey: "Download failed!"])
                        }
                    
                        print("[*] extracting include.zip")
                        unzipArchiveAtPath("\(NSTemporaryDirectory())/include.zip", self.bootstrapPath("/Include"))
                    
                        self.bootstrapVersion = 9
                    }
                }
                
                // Deletion check
                print("[*] deleting deprecated parts of the bootstrap")
                for deleteItem in self.bootstrapDeletionIfFoundPaths {
                    let bootstrapDeleteItem = self.bootstrapPath(deleteItem)
                    if FileManager.default.fileExists(atPath: bootstrapDeleteItem) {
                        try FileManager.default.removeItem(atPath: bootstrapDeleteItem)
                    }
                }
                
                // Executable check
                print("[*] making executables executable again")
                
                // IDK WHY THATS NEEDED LOL
                for executableItem in self.bundleFixupExecutablePaths {
                    shell("chmod 0555 \(Bundle.main.bundlePath)\(executableItem)", 0, nil, nil)
                }
            } catch {
                print("[!] failed: \(error.localizedDescription)")
                NotificationServer.NotifyUser(level: .error, notification: "Bootstrapping failed: \(error.localizedDescription), you will not be able to build any apps. please restart the app to reattempt bootstrapping!")
                self.bootstrapVersion = 0
                self.clearPath(path: "/")
            }
            
            print("[*] done")
        }
    }
    
    func waitTillDone() {
        guard Bootstrap.shared.bootstrapVersion != Bootstrap.shared.newestBootstrapVersion else { return }
        
        XCButton.switchImage(withSystemName: "archivebox.fill", animated: true)
        XCButton.updateProgress(withValue: 0.1)
        
        while Bootstrap.shared.bootstrapVersion != Bootstrap.shared.newestBootstrapVersion {
            Thread.sleep(forTimeInterval: 1.0)
        }
        
        XCButton.switchImage(withSystemName: "hammer.fill", animated: true)
    }
    
    @objc static var shared: Bootstrap = Bootstrap()
}
