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

@objc class Bootstrap: NSObject {
    var semaphore: DispatchSemaphore?
#if !JAILBREAK_ENV
    static let rootPath: String = "\(NSHomeDirectory())/Documents"
#else
    static let rootPath: String = "\(NSHomeDirectory())/Documents/com.cr4zy.nyxian.root"
#endif // !JAILBREAK_ENV
    
    static let rootURL: URL = URL(fileURLWithPath: Bootstrap.rootPath)
    let newestBootstrapVersion: Int = 17
    
    @objc var sdkPath: String {
        self.bootstrapPath("/SDK/iPhoneOS26.4.1.sdk")
    }
    
    @objc var bootstrapPlistPath: String {
        bootstrapPath("/bootstrap.plist")
    }
    
    @objc var bootstrapVersion: Int {
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
    
    @objc var isBootstrapInstalled: Bool {
        return FileManager.default.fileExists(atPath: bootstrapPlistPath) && bootstrapVersion > 0
    }
    
    @objc func bootstrapPath(_ path: String) -> String {
        var path: String = path
        if path.hasPrefix("/") { path.removeFirst() }
        return URL(fileURLWithPath: path, relativeTo: Bootstrap.rootURL).path
    }
    
    @objc func sdkPath(_ path: String) -> String {
        var path: String = path
        if path.hasPrefix("/") { path.removeFirst() }
        return URL(fileURLWithPath: path, relativeTo: URL(fileURLWithPath: sdkPath)).path
    }
    
    @objc func relativeToBootstrapSafe(_ absolutePath: String) -> String? {
        let rootURL = Bootstrap.rootURL
        let absoluteURL = URL(fileURLWithPath: absolutePath)
        guard absoluteURL.path.hasPrefix(rootURL.path + "/") || absoluteURL.path == rootURL.path else {
            return nil
        }
        let relativePath = absoluteURL.path.replacingOccurrences(of: rootURL.path + "/", with: "")
        return relativePath
    }
    
    func clearPath(path: String) {
        let fileManager = FileManager.default
        let target = bootstrapPath(path)

        if let files = try? fileManager.contentsOfDirectory(atPath: target) {
            for file in files {
                if !(path == "/" && file == "Projects") {
                    try? fileManager.removeItem(atPath: "\(target)/\(file)")
                }
            }
        }
    }
    
    @objc func bootstrap() {
        // Cmon one UIInit once part can be here ^^
        UIBarButtonItem.swizzleBarButtonitem
        UIViewController.swizzlePresentOnce
        
        print("[*] checking upon nyxian bootstrap")
        
        LDEPthreadDispatch {
            if(!FileManager.default.fileExists(atPath: Bootstrap.rootPath)) {
                do {
                    try FileManager.default.createDirectory(at: Bootstrap.rootURL, withIntermediateDirectories: true)
                } catch {
                    // Something terrible has happened
                    exit(0)
                }
            }
            
            print("[*] install status: \(self.isBootstrapInstalled)")
            print("[*] version: \(self.bootstrapVersion)")
            
            do {
                
                if !self.isBootstrapInstalled || self.bootstrapVersion != self.newestBootstrapVersion {
                    
                    // need to clear the entire path if its not installed
                    // to make sure it can be safely installed in the first
                    // place.
                    if !self.isBootstrapInstalled || self.bootstrapVersion > self.newestBootstrapVersion {
                        print("[*] Bootstrap is not installed or too new, clearing")
                        self.clearPath(path: "/")
                    }
                    
                    if self.bootstrapVersion < 9 {
                        // Creating bootstrap base
                        print("[*] Creating folder structures")
                        
                        // We need include to put clangs includations into
                        try FileManager.default.createDirectory(atPath: self.bootstrapPath("/SDK"), withIntermediateDirectories: false)
                        try FileManager.default.createDirectory(atPath: self.bootstrapPath("/Projects"), withIntermediateDirectories: false)
                        
                        print("[*] creating bootstrap cache")
                        try FileManager.default.createDirectory(atPath: self.bootstrapPath("/Cache"), withIntermediateDirectories: false)
                        
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
                    
                    if self.bootstrapVersion < 10 {
                        if FileManager.default.fileExists(atPath: self.bootstrapPath("/lib")) {
                            try FileManager.default.removeItem(atPath: self.bootstrapPath("/lib"))
                        }
                        
                        print("[*] bootstrapping libraries")
                        
                        unzipArchiveAtPath("\(Bundle.main.bundlePath)/Shared/lib.zip", self.bootstrapPath("/"))
                        
                        self.bootstrapVersion = 10
                    }
                    
                    if self.bootstrapVersion < 15 {
                        // permission fixup for the DOS zip vulnerability
                        let url = URL(fileURLWithPath: NSTemporaryDirectory())
                        let fm = FileManager.default
                        guard let enumerator = fm.enumerator(at: url, includingPropertiesForKeys: nil) else { return }
                        
                        try? fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: url.path)
                        
                        for case let fileURL as URL in enumerator {
                            var isDir: ObjCBool = false
                            fm.fileExists(atPath: fileURL.path, isDirectory: &isDir)
                            let perms: Int = isDir.boolValue ? 0o755 : 0o644
                            try? fm.setAttributes([.posixPermissions: perms], ofItemAtPath: fileURL.path)
                        }
                        
                        self.bootstrapVersion = 15
                    }
                    
                    if self.bootstrapVersion < 16 {
                        for deleteItem in ["/Config", "/Certificates"] {
                            let bootstrapDeleteItem = self.bootstrapPath(deleteItem)
                            if FileManager.default.fileExists(atPath: bootstrapDeleteItem) {
                                try? FileManager.default.removeItem(atPath: bootstrapDeleteItem)
                            }
                        }
                        
                        self.bootstrapVersion = 16
                    }
                    
                    if self.bootstrapVersion < 17 {
                        if FileManager.default.fileExists(atPath: self.bootstrapPath("/SDK")) {
                            print("[*] removing deprecated sdk")
                            try FileManager.default.removeItem(atPath: self.bootstrapPath("/SDK"))
                        }
                        
                        print("[*] downloading sdk")
                        
                        if !fdownload("https://nyxian.app/bootstrap/iPhoneOS26.4.1.sdk.zip", "sdk.zip") {
                            print("[*] sdk download failed")
                            throw NSError(domain: "", code: 0, userInfo: [NSLocalizedDescriptionKey: "Download failed!"])
                        }
                        
                        print("[*] extracting sdk.zip")
                        unzipArchiveAtPath("\(NSTemporaryDirectory())/sdk.zip", self.bootstrapPath("/SDK"))

                        // create compatibility symlink for projects still using the iPhoneOS26.2.sdk SDK
                        let realSDK = self.bootstrapPath("/SDK/iPhoneOS26.4.1.sdk")
                        let symlinkSDKs: [String] = [
                            self.bootstrapPath("/SDK/iPhoneOS26.2.sdk"),
                            self.bootstrapPath("/SDK/iPhoneOS26.4.sdk")
                        ]
                        
                        for symlinkSDK in symlinkSDKs {
                            if !FileManager.default.fileExists(atPath: symlinkSDK) {
                                try FileManager.default.createSymbolicLink(
                                    atPath: symlinkSDK,
                                    withDestinationPath: realSDK
                                )
                            }
                        }
                        
                        self.bootstrapVersion = 17
                    }
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
    
    @objc func waitTillDone() {
        guard Bootstrap.shared.bootstrapVersion != Bootstrap.shared.newestBootstrapVersion else { return }
        
        XCButton.switchImage(withSystemName: "archivebox.fill", animated: true)
        XCButton.updateProgress(withValue: 0.1)
        
        while Bootstrap.shared.bootstrapVersion != Bootstrap.shared.newestBootstrapVersion {
            Thread.sleep(forTimeInterval: 1.0)
        }
        
        XCButton.switchImage(withSystemName: "hammer.fill", animated: true)
    }
    
    @objc func isNewest() -> Bool {
        return Bootstrap.shared.bootstrapVersion == Bootstrap.shared.newestBootstrapVersion
    }
    
    @objc static var shared: Bootstrap = Bootstrap()
}
