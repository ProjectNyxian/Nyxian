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

import UIKit
import UniformTypeIdentifiers

final class ROMImporter: NSObject, UIDocumentPickerDelegate {
    private var completion: ((URL?) -> Void)?
    
    func present(from viewController: UIViewController, completion: @escaping (URL?) -> Void) {
        self.completion = completion
        
        let picker = UIDocumentPickerViewController(
            forOpeningContentTypes: [.item],
            asCopy: true
        )
        
        picker.delegate = self
        picker.allowsMultipleSelection = false
        
        viewController.present(picker, animated: true)
    }
    
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        let url = urls.first
        
        completion?(url)
        completion = nil
    }
    
    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
        completion?(nil)
        completion = nil
    }
}

final class ROMPath {
    let path: String
    let permission: Int
    
    struct ROMPathCodeSigningInfo {
        let needed: Bool
        let neededNXT2: Bool
        let nxt2: [String:Any]
    }
    let codesigning: ROMPath.ROMPathCodeSigningInfo
    
    init(path: String,
         permission: Int,
         codesigning: ROMPath.ROMPathCodeSigningInfo) {
        self.path = path
        self.permission = permission
        self.codesigning = codesigning
    }
}

func adaptiveImage(light: UIImage, dark: UIImage) -> UIImage {
    let asset = UIImageAsset()
    let lightTraits = UITraitCollection(traitsFrom: [
        .current,
        UITraitCollection(userInterfaceStyle: .light)
    ])
    asset.register(light, with: lightTraits)
    let darkTraits = UITraitCollection(traitsFrom: [
        .current,
        UITraitCollection(userInterfaceStyle: .dark)
    ])
    asset.register(dark, with: darkTraits)
    return asset.image(with: .current)
}

final class ROMManifest {
    // ABI
    let manifestVersion: Int
    
    // identity
    let identifier: String
    let name: String
    let version: String
    let minimumNyxianVersion: String
    let maximumNyxianVersion: String?
    
    // file permissions
    let defaultFilePermission: Int
    let defaultDirectoryPermission: Int
    let paths: [ROMPath]
    
    // runtime
    let installer: String?
    let uninstaller: String?
    let executable: String
    
    // bootlogo
    let bootlogo: UIImage?
    
    // helpers
    var isNyxianMinimumVersionMet: Bool {
        compareVersions(currentNyxianVersion(), minimumNyxianVersion) != .orderedAscending
    }
    
    var isNyxianVersionSupported: Bool {
        guard isNyxianMinimumVersionMet else { return false }
        if let maximumNyxianVersion {
            return compareVersions(currentNyxianVersion(), maximumNyxianVersion) == .orderedAscending
        }
        return true
    }
    
    var nyxianRequirement: String {
        if let maximumNyxianVersion {
            return "Nyxian \(minimumNyxianVersion) up to (not including) \(maximumNyxianVersion)"
        }
        return "Nyxian \(minimumNyxianVersion) or newer"
    }
    
    init(manifestPlistURL: URL) throws {
        // first we'll read the plist
        guard let manifestContent = NSDictionary(contentsOf: manifestPlistURL) as? [String: Any] else {
            throw NSError(domain: "org.emexlabs.nyxian.bootloader.rom-flash", code: 1, userInfo: [NSLocalizedDescriptionKey:"failed to read menifest plist"])
        }
        
        // next we need to parse version
        guard let manifestVersion = manifestContent["NXRomManifestVersion"] as? Int,
              let identifier = manifestContent["NXRomIdentifier"] as? String,
              let name = manifestContent["NXRomName"] as? String,
              let version = manifestContent["NXRomVersion"] as? String,
        let minimumNyxianVersion = manifestContent["NXRomMinimumNyxianVersion"] as? String,
        let executable = manifestContent["NXRomExecutable"] as? String else {
            throw NSError(domain: "org.emexlabs.nyxian.bootloader.rom-flash", code: 1, userInfo: [NSLocalizedDescriptionKey:"malformed manifest plist"])
        }
        
        // ABI
        self.manifestVersion = manifestVersion
        
        // identity
        self.identifier = identifier
        self.name = name
        self.version = version
        self.minimumNyxianVersion = minimumNyxianVersion
        self.maximumNyxianVersion = manifestContent["NXRomMaximumNyxianVersion"] as? String
        
        // file permissions
        self.defaultFilePermission = manifestContent["NXRomDefaultFilePermission"] as? Int ?? 420
        self.defaultDirectoryPermission = manifestContent["NXRomDefaultDirectoryPermission"] as? Int ?? 493
        
        // parsing explicit paths
        var actualPathObjects: [ROMPath] = []
        let paths: [[String:Any]] = manifestContent["NXRomPaths"] as? [[String:Any]] ?? []
        for pathDict in paths {
            let permission: Int = pathDict["NXPermission"] as? Int ?? self.defaultFilePermission
            let requiresCodeSigning: Bool = pathDict["NXRequiresCodeSigning"] as? Bool ?? false
            var requiresNXT2Signing: Bool = requiresCodeSigning
            let nxt2Entitlements: [String:Any]
            if requiresNXT2Signing {
                if let nxt2: [String:Any] = pathDict["NXT2Entitlements"] as? [String:Any] {
                    nxt2Entitlements = nxt2
                } else {
                    nxt2Entitlements = [:]
                    requiresNXT2Signing = false
                }
            } else {
                nxt2Entitlements = [:]
            }
            
            if let path: [String] = pathDict["NXPath"] as? [String] {
                for additionalPath in path {
                    actualPathObjects.append(ROMPath(path: additionalPath, permission: permission, codesigning: ROMPath.ROMPathCodeSigningInfo(needed: requiresCodeSigning, neededNXT2: requiresNXT2Signing, nxt2: nxt2Entitlements)))
                }
            } else if let path: String = pathDict["NXPath"] as? String {
                actualPathObjects.append(ROMPath(path: path, permission: permission, codesigning: ROMPath.ROMPathCodeSigningInfo(needed: requiresCodeSigning, neededNXT2: requiresNXT2Signing, nxt2: nxt2Entitlements)))
            } else {
                throw NSError(domain: "org.emexlabs.nyxian.bootloader.rom-flash", code: 1, userInfo: [NSLocalizedDescriptionKey:"malformed manifest path's in manifest plist"])
            }
        }
        self.paths = actualPathObjects
        
        self.installer = manifestContent["NXRomInstaller"] as? String
        self.uninstaller = manifestContent["NXRomUninstaller"] as? String
        self.executable = executable
        
        // bootlogo
        if let bootLogoConfig = manifestContent["NXRomBootLogo"] as? [String:String],
           let lightPath = bootLogoConfig["Light"],
           let darkPath = bootLogoConfig["Dark"],
           let light = UIImage(contentsOfFile: manifestPlistURL.deletingLastPathComponent().appendingPathComponent(lightPath).path) {
            let dark = UIImage(contentsOfFile: manifestPlistURL.deletingLastPathComponent().appendingPathComponent(darkPath).path) ?? light
            self.bootlogo = adaptiveImage(light: light, dark: dark)
        } else {
            self.bootlogo = nil
        }
    }
}

enum BootFlag: String, CaseIterable {
    case kextLoading = "nyxian.boot.kextLoading"
    case logObfucation = "nyxian.boot.log.obfuscated"
    case sandboxFilesystem = "nyxian.boot.sandbox.filesystems"
    case verboseBoot = "nyxian.boot.verbose"
    
    var title: String {
        switch self {
            case .kextLoading: return "Load kexts at boot"
            case .logObfucation: return "Obfuscate Log"
            case .sandboxFilesystem: return "Filesystem Sandbox"
            case .verboseBoot: return "Verbose Boot"
        }
    }
    
    var defaultValue: Bool {
        switch self {
            case .kextLoading: return true
            case .logObfucation: return true
            case .sandboxFilesystem: return true
            case .verboseBoot: return false
        }
    }
}

enum BootConfig {
    fileprivate static let entitlementModeKey = "nyxian.boot.entitlements.mode"
    
    static func registerDefaults() {
        var defaults: [String: Any] = Dictionary(uniqueKeysWithValues: BootFlag.allCases.map { ($0.rawValue, $0.defaultValue) })
        defaults[entitlementModeKey] = EnforcementMode.enforcing.rawValue
        
        UserDefaults.standard.register(defaults: defaults)
    }
    
    static var entitlementMode: EnforcementMode {
        get {
            guard let raw = UserDefaults.standard.string(forKey: entitlementModeKey),
                  let mode = EnforcementMode(rawValue: raw) else {
                return .enforcing
            }
            return mode
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: entitlementModeKey)
        }
    }
    
    static func isEnabled(_ flag: BootFlag) -> Bool {
        UserDefaults.standard.bool(forKey: flag.rawValue)
    }
    
    static func toggle(_ flag: BootFlag) {
        UserDefaults.standard.set(!isEnabled(flag), forKey: flag.rawValue)
    }
}

enum EnforcementMode: String, CaseIterable {
    case enforcing
    case permissive
    case disabled
    
    var badge: String {
        switch self {
            case .enforcing: return "E"
            case .permissive: return "P"
            case .disabled: return "-"
        }
    }
    
    var next: EnforcementMode {
        let all = EnforcementMode.allCases
        let i = all.firstIndex(of: self) ?? 0
        return all[(i + 1) % all.count]
    }
}

private typealias NXSlotMainFn = @convention(c) () -> UnsafeMutableRawPointer?
private typealias NXSlotDidAppearFn = @convention(c) () -> Void
private typealias NXSlotCreateWindowFn = @convention(c) (UnsafeMutableRawPointer) -> UnsafeMutableRawPointer?
private typealias NXRomGenericFn = @convention(c) (UnsafePointer<CChar>) -> Int32

private func romError(_ message: String) -> NSError {
    NSError(domain: "org.emexlabs.nyxian.bootloader.rom-flash", code: 3, userInfo: [NSLocalizedDescriptionKey: message])
}

private func slotFile(_ relative: String,
                      in slot: URL) throws -> URL {
    let root = slot.resolvingSymlinksInPath().standardizedFileURL.path
    let url = slot.appendingPathComponent(relative).resolvingSymlinksInPath().standardizedFileURL
    guard url.path.hasPrefix(root + "/") else {
        throw romError("path escapes ROM slot: \(relative)")
    }
    return url
}

private let nxRomLogFD: Int32 = 27
private let romQueue = DispatchQueue(label: "org.emexlabs.nyxian.bootloader.rom", qos: .userInitiated)
private var romOperationInProgress = false

private func drainLines(from readFD: Int32, onLine: @escaping (String) -> Void) -> DispatchGroup {
    let drained = DispatchGroup()
    drained.enter()
    DispatchQueue.global(qos: .userInitiated).async {
        var buf = [UInt8](repeating: 0, count: 4096)
        var pending: [UInt8] = []
        while true {
            let n = read(readFD, &buf, buf.count)
            if n > 0 {
                pending.append(contentsOf: buf[0..<n])
                var start = pending.startIndex
                while let nl = pending[start...].firstIndex(of: 0x0A) {
                    emitRomLine(pending[start..<nl], onLine)
                    start = nl + 1
                }
                pending.removeFirst(start)
                continue
            }
            if n < 0 && errno == EINTR {
                continue
            }
            break
        }
        emitRomLine(pending[...], onLine)
        close(readFD)
        drained.leave()
    }
    return drained
}

private final class BootLogCapture {
    private var savedFD: Int32 = -1
    private var drained: DispatchGroup?
    private(set) var active = false
    
    func start(onLine: @escaping (String) -> Void) -> Bool {
        dispatchPrecondition(condition: .onQueue(.main))
        guard !active else { return true }
        
        var fds: [Int32] = [0, 0]
        guard pipe(&fds) == 0 else { return false }
        
        savedFD = dup(nxRomLogFD) // -1 if nothing was on 27, that's fine
        guard dup2(fds[1], nxRomLogFD) >= 0 else {
            close(fds[0])
            close(fds[1])
            if savedFD >= 0 { close(savedFD); savedFD = -1 }
            return false
        }
        close(fds[1])
        
        drained = drainLines(from: fds[0], onLine: onLine)
        active = true
        return true
    }
    
    func stop() {
        dispatchPrecondition(condition: .onQueue(.main))
        guard active else { return }
        active = false
        
        if savedFD >= 0 {
            dup2(savedFD, nxRomLogFD) // atomically drops our write end
            close(savedFD)
            savedFD = -1
        } else {
            close(nxRomLogFD)
        }
        
        // if the slot dup'd fd 27 somewhere we never see EOF, so don't block boot on it
        _ = drained?.wait(timeout: .now() + .milliseconds(100))
        drained = nil
    }
}

private final class VerboseBootConsole {
    let layer = CATextLayer()
    
    private let lock = NSLock()
    private var lines: [(text: String, isError: Bool)] = []
    private var maxLines = 1
    private var columns = Int.max
    
    private let font = UIFont.monospacedSystemFont(ofSize: 8, weight: .regular)
    private let normalColor: CGColor
    private let errorColor: CGColor
    
    private static let historyLimit = 512
    
    init(in host: UIView) {
        dispatchPrecondition(condition: .onQueue(.main))
        
        normalColor = UIColor.label.resolvedColor(with: host.traitCollection).cgColor
        errorColor = UIColor.systemRed.resolvedColor(with: host.traitCollection).cgColor
        
        layer.isWrapped = false
        layer.truncationMode = .end
        layer.alignmentMode = .left
        layer.contentsScale = host.traitCollection.displayScale > 0 ? host.traitCollection.displayScale : 3
        
        host.layer.addSublayer(layer)
        layout(in: host)
    }
    
    func layout(in host: UIView) {
        dispatchPrecondition(condition: .onQueue(.main))
        
        let insets = host.safeAreaInsets
        let frame = host.bounds.inset(by: UIEdgeInsets(top: insets.top + 8,
                                                       left: insets.left + 8,
                                                       bottom: insets.bottom + 8,
                                                       right: insets.right + 8))
        
        let scale = host.window?.screen.scale ?? host.traitCollection.displayScale
        
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        layer.frame = frame
        if scale > 0 { layer.contentsScale = scale }
        CATransaction.commit()
        
        // monospaced font, so one cell width gives the column count
        let cellWidth = ("M" as NSString).size(withAttributes: [.font: font]).width
        
        lock.lock()
        maxLines = max(1, Int(frame.height / font.lineHeight))
        columns = cellWidth > 0 ? max(1, Int(frame.width / cellWidth)) : Int.max
        lock.unlock()
        
        redraw()
    }
    
    /// any thread
    func append(_ line: String, isError: Bool) {
        lock.lock()
        lines.append((line, isError))
        if lines.count > Self.historyLimit {
            lines.removeFirst(lines.count - Self.historyLimit)
        }
        lock.unlock()
        DispatchQueue.main.async { [weak self] in
            self?.redraw()
        }
    }
    
    /// any thread
    func snapshot() -> [(text: String, isError: Bool)] {
        lock.lock()
        defer { lock.unlock() }
        return lines
    }
    
    /// hard wrap at the column limit, same as the recovery glyph view does
    private static func wrap(_ text: String, columns: Int) -> [String] {
        let text = text.replacingOccurrences(of: "\t", with: "    ")
        guard columns > 0, columns != Int.max, text.count > columns else { return [text] }
        
        var rows: [String] = []
        var rest = text[...]
        while rest.count > columns {
            let cut = rest.index(rest.startIndex, offsetBy: columns)
            rows.append(String(rest[..<cut]))
            rest = rest[cut...]
        }
        rows.append(String(rest))
        return rows
    }
    
    private func redraw() {
        lock.lock()
        let capacity = maxLines
        let cols = columns
        let all = lines
        lock.unlock()
        
        var visible: [(text: String, isError: Bool)] = []
        outer: for entry in all.reversed() {
            for row in Self.wrap(entry.text, columns: cols).reversed() {
                visible.append((row, entry.isError))
                if visible.count >= capacity { break outer }
            }
        }
        visible.reverse()
        
        let text = NSMutableAttributedString()
        let fontKey = NSAttributedString.Key(kCTFontAttributeName as String)
        let colorKey = NSAttributedString.Key(kCTForegroundColorAttributeName as String)
        
        for (i, entry) in visible.enumerated() {
            let s = (i == 0 ? "" : "\n") + entry.text
            text.append(NSAttributedString(string: s, attributes: [
                fontKey: font as CTFont,
                colorKey: entry.isError ? errorColor : normalColor,
            ]))
        }
        
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        layer.string = text
        CATransaction.commit()
        
        if !Thread.isMainThread {
            CATransaction.flush()
        }
    }
}

private let bootLogMax = 64

private let verboseBootHold: TimeInterval = 1.5

private func bootLog(_ message: String) {
    (message + "\n").withCString { _ = write(nxRomLogFD, $0, strlen($0)) }
}

private struct RomLog {
    let controller: NXRecoveryViewController
    
    func info(_ message: String) {
        DispatchQueue.main.async { controller.recoveryLog(message) }
    }
    
    func error(_ message: String) {
        DispatchQueue.main.async { controller.recoveryLogError(message) }
    }
    
    func rom(_ line: String) {
        if line.hasPrefix("ERROR:") {
            error(line)
        } else {
            info(line)
        }
    }
}

private func romIsBusy(_ c: NXRecoveryViewController) -> Bool {
    if romOperationInProgress {
        c.recoveryLogError("ERROR: a ROM operation is still running")
    }
    return romOperationInProgress
}

private func runRomOperation(_ c: NXRecoveryViewController, _ work: @escaping (RomLog) -> Void) {
    dispatchPrecondition(condition: .onQueue(.main))
    guard !romIsBusy(c) else { return }
    romOperationInProgress = true
    let log = RomLog(controller: c)
    romQueue.async {
        work(log)
        DispatchQueue.main.async {
            romOperationInProgress = false
        }
    }
}

private func runRomGeneric(_ relative: String, symbol: String, slot: URL, onLine: @escaping (String) -> Void) throws {
    dispatchPrecondition(condition: .notOnQueue(.main))
    
    let url = try slotFile(relative, in: slot)
    
    var fds: [Int32] = [0, 0]
    guard pipe(&fds) == 0 else {
        throw romError("pipe failed: \(String(cString: strerror(errno)))")
    }
    
    let readFD = fds[0]
    let writeFD = fds[1]
    
    let oldFD = dup(nxRomLogFD)
    guard dup2(writeFD, nxRomLogFD) >= 0 else {
        close(readFD)
        close(writeFD)
        if oldFD >= 0 { close(oldFD) }
        throw romError("dup2 failed: \(String(cString: strerror(errno)))")
    }
    close(writeFD)
    
    let drained = drainLines(from: readFD, onLine: onLine)
    
    func restoreLogFD() {
        close(nxRomLogFD)
        if oldFD >= 0 {
            dup2(oldFD, nxRomLogFD)
            close(oldFD)
        }
        drained.wait()
    }
    
    guard let handle = dlopen(url.path, RTLD_NOW | RTLD_LOCAL) else {
        let reason = lastDlError()
        restoreLogFD()
        throw romError("couldnt load \(relative): \(reason)")
    }
    defer { dlclose(handle) }
    
    guard let sym = dlsym(handle, symbol) else {
        restoreLogFD()
        throw romError("\(relative) has no \(symbol) entry point")
    }
    
    let generic = unsafeBitCast(sym, to: NXRomGenericFn.self)
    let rc = slot.path.withCString {
        generic($0)
    }
    
    restoreLogFD()
    
    guard rc == 0 else {
        throw romError("\(symbol) returned \(rc)")
    }
}

private func emitRomLine(_ bytes: ArraySlice<UInt8>, _ onLine: (String) -> Void) {
    var bytes = bytes
    if bytes.last == 0x0D {
        bytes = bytes.dropLast()
    }
    guard !bytes.isEmpty else { return }
    onLine(String(decoding: bytes, as: UTF8.self))
}

private enum SlotLoadResult {
    case loaded(name: String, main: NXSlotMainFn, didAppear: NXSlotDidAppearFn?, createWindow: NXSlotCreateWindowFn?)
    case failed(String)
}

private typealias RestartSelfFn = @convention(c) () -> Void

private func restartSelf() {
    let RTLD_DEFAULT = UnsafeMutableRawPointer(bitPattern: -2)
    guard let sym = dlsym(RTLD_DEFAULT, "PERestartSelf") else {
        exit(0)
    }
    unsafeBitCast(sym, to: RestartSelfFn.self)()
}

private func refreshVnode(atPath path: String) -> Bool {
    let fd = open(path, O_RDWR)
    guard fd >= 0 else { return false }
    defer { close(fd) }
    guard unlink(path) == 0 else { return false }
    if fclonefileat(fd, AT_FDCWD, path, 0) == 0 {
        return true
    }
    let copyfd = open(path, O_RDWR | O_CREAT | O_TRUNC, 0o777)
    guard copyfd >= 0 else { return false }
    defer { close(copyfd) }
    lseek(fd, 0, SEEK_SET)
    return fcopyfile(fd, copyfd, nil, copyfile_flags_t(COPYFILE_DATA)) == 0
}

func currentNyxianVersion() -> String {
    Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
}

func compareVersions(_ a: String, _ b: String) -> ComparisonResult {
    func parts(_ version: String) -> [Int] {
        version.split(separator: ".").map { Int($0.prefix(while: { $0.isNumber })) ?? 0 }
    }
    let left = parts(a)
    let right = parts(b)
    for index in 0..<max(left.count, right.count) {
        let l = index < left.count ? left[index] : 0
        let r = index < right.count ? right[index] : 0
        if l != r {
            return l < r ? .orderedAscending : .orderedDescending
        }
    }
    return .orderedSame
}

// MARK: - Slots

private let activeSlotKey = "org.emexlabs.nyxian.bootloader.active-slot"
private let slotNames = ["A", "B"]

private func slotURL(_ name: String) -> URL {
    URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Boot/Slot/\(name)")
}

private func slotManifest(_ name: String) -> ROMManifest? {
    try? ROMManifest(manifestPlistURL: slotURL(name).appendingPathComponent("manifest.plist"))
}

private func slotIsFlashed(_ name: String) -> Bool {
    FileManager.default.fileExists(atPath: slotURL(name).appendingPathComponent("manifest.plist").path)
}

private func otherSlotName(_ name: String) -> String {
    name == "A" ? "B" : "A"
}

private func activeSlotName() -> String {
    let stored = UserDefaults.standard.string(forKey: activeSlotKey) ?? "A"
    let name = slotNames.contains(stored) ? stored : "A"
    if !slotIsFlashed(name) && slotIsFlashed(otherSlotName(name)) {
        return otherSlotName(name)
    }
    return name
}

private func setActiveSlot(_ name: String) {
    UserDefaults.standard.set(name, forKey: activeSlotKey)
    CFPreferencesAppSynchronize(kCFPreferencesCurrentApplication)
}

private func flashTargetSlotName() -> String {
    let active = activeSlotName()
    return slotIsFlashed(active) ? otherSlotName(active) : active
}

private func slotSummary(_ name: String) -> String {
    if let manifest = slotManifest(name) {
        return "Slot \(name): \(manifest.name) \(manifest.version)"
    }
    return slotIsFlashed(name) ? "Slot \(name): unreadable manifest" : "Slot \(name): empty"
}

private func flashedSlotURL() -> URL {
    slotURL(activeSlotName())
}

private func lastDlError() -> String {
    if let err = dlerror() { return String(cString: err) }
    return "unknown dyld error"
}

private func loadSlot(loadSuperslotForcefully: Bool) -> SlotLoadResult {
    let fm = FileManager.default
    let slot = flashedSlotURL()
    let manifestURL = slot.appendingPathComponent("manifest.plist")
    
    let image: URL
    let name: String
    
    if fm.fileExists(atPath: manifestURL.path),
       !loadSuperslotForcefully {
        do {
            let manifest = try ROMManifest(manifestPlistURL: manifestURL)
            image = try slotFile(manifest.executable, in: slot)
            name = manifest.name
        } catch {
            return .failed("flashed ROM is invalid: \(error.localizedDescription)")
        }
        guard fm.fileExists(atPath: image.path) else {
            return .failed("\(name): executable missing")
        }
    } else if let bundled = Bundle.main.privateFrameworksURL?.appendingPathComponent("SuperSlot.dylib"),
              fm.fileExists(atPath: bundled.path) {
        image = bundled
        name = "SuperSlot.dylib"
    } else {
        return .failed("No slot found (no flashed ROM and no bundled SuperSlot.dylib)")
    }
    
    guard let handle = dlopen(image.path, RTLD_NOW | RTLD_NODELETE | RTLD_GLOBAL) else {
        return .failed("Couldnt load \(name): \(lastDlError())")
    }
    
    guard let mainSym = dlsym(handle, "NXSlotMain") else {
        return .failed("\(name) has no NXSlotMain entry point")
    }
    
    let main = unsafeBitCast(mainSym, to: NXSlotMainFn.self)
    let didAppear = dlsym(handle, "NXSlotDidAppear").map { unsafeBitCast($0, to: NXSlotDidAppearFn.self) }
    let createWindow = dlsym(handle, "NXSlotCreateWindow").map { unsafeBitCast($0, to: NXSlotCreateWindowFn.self) }
    return .loaded(name: name, main: main, didAppear: didAppear, createWindow: createWindow)
}

private func bootConfigItems(returningTo parent: @escaping (NXRecoveryViewController) -> Void) -> [NXRecoveryItem] {
    func label(_ flag: BootFlag) -> String {
        "[\(BootConfig.isEnabled(flag) ? "X" : " ")] \(flag.title)"
    }
    
    func reload(_ c: NXRecoveryViewController) {
        let keep = c.recoveryIndex
        c.recoveryItems = bootConfigItems(returningTo: parent)
        c.recoveryIndex = keep
    }
    
    var items: [NXRecoveryItem] = [
        NXRecoveryItem(title: "../") { c in
            if let c = c {
                parent(c)
            }
        }
    ]
    
    for flag in BootFlag.allCases {
        items.append(NXRecoveryItem(title: label(flag)) { c in
            guard let c = c else { return }
            
            BootConfig.toggle(flag)
            reload(c)
            
            let state = BootConfig.isEnabled(flag) ? "enabled" : "disabled"
            c.recoveryLog("\(flag.title): \(state)")
        })
    }
    
    let mode = BootConfig.entitlementMode
    items.append(NXRecoveryItem(title: "[\(mode.badge)] Entitlements: \(mode.rawValue)") { c in
        guard let c = c else { return }
        
        BootConfig.entitlementMode = BootConfig.entitlementMode.next
        reload(c)
        
        switch BootConfig.entitlementMode {
            case .enforcing: c.recoveryLog("entitlements: enforcing")
            case .permissive: c.recoveryLogError("entitlements: permissive, denials logged, not blocked")
            case .disabled: c.recoveryLogError("entitlements: DISABLED, no checks will run")
        }
    })
    
    return items
}

func recoveryShowBootConfig(recoveryController c: NXRecoveryViewController) {
    c.enterRecovery(
        withHeader: "Boot Configuration",
        instructions: nil,
        footer: nil,
        items: bootConfigItems(returningTo: { parent in
            recoveryShowMenu(recoveryController: parent)
        }),
        onSelect: nil,
        onMove: nil
    )
}

private struct WipeFailure {
    let path: String
    let reason: String
}

private struct WipeStats {
    var removedFiles = 0
    var removedDirectories = 0
    var bytes: Int64 = 0
    var failures: [WipeFailure] = []
}

private let maxFailuresShown = 3

private let wipeResourceKeys: [URLResourceKey] = [
    .isDirectoryKey,
    .isSymbolicLinkKey,
    .totalFileAllocatedSizeKey,
]

private func errnoDescription(_ error: Error) -> String {
    let ns = error as NSError
    if let u = ns.userInfo[NSUnderlyingErrorKey] as? NSError, u.domain == NSPOSIXErrorDomain {
        return String(cString: strerror(Int32(u.code)))
    }
    return ns.localizedDescription
}

private func formatBytes(_ bytes: Int64) -> String {
    ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
}

private func relativePath(_ url: URL, home: String) -> String {
    let path = url.standardizedFileURL.path
    return path.hasPrefix(home) ? String(path.dropFirst(home.count)) : path
}

private func recordFailure(_ url: URL, _ error: Error, home: String, stats: inout WipeStats) {
    stats.failures.append(WipeFailure(path: relativePath(url, home: home), reason: errnoDescription(error)))
}

private func removeTree(_ url: URL,
                        keeping keep: Set<String>,
                        isRoot: Bool,
                        home: String,
                        stats: inout WipeStats) -> Bool {
    let fm = FileManager.default
    let values = try? url.resourceValues(forKeys: Set(wipeResourceKeys))
    let isSymlink = values?.isSymbolicLink ?? false
    let isRealDirectory = (values?.isDirectory ?? false) && !isSymlink
    
    var ok = true
    if isRealDirectory {
        let children: [URL]
        do {
            children = try fm.contentsOfDirectory(at: url, includingPropertiesForKeys: wipeResourceKeys, options: [])
        } catch {
            recordFailure(url, error, home: home, stats: &stats)
            return false
        }
        
        for child in children {
            let childOK = removeTree(child, keeping: keep, isRoot: false, home: home, stats: &stats)
            ok = ok && childOK
        }
    }
    
    if isRoot || keep.contains(url.standardizedFileURL.path) || !ok {
        return ok
    }
    
    let size = Int64(values?.totalFileAllocatedSize ?? 0)
    do {
        try fm.removeItem(at: url)
    } catch {
        recordFailure(url, error, home: home, stats: &stats)
        return false
    }
    
    if isRealDirectory {
        stats.removedDirectories += 1
    } else {
        stats.removedFiles += 1
        stats.bytes += size
    }
    
    return true
}

func recoveryWipeData(_ c: NXRecoveryViewController) {
    let home = URL(fileURLWithPath: NSHomeDirectory(), isDirectory: true).standardizedFileURL
    let homePath = home.path
    
    let targets = ["Documents", "Library", "tmp"].map {
        home.appendingPathComponent($0, isDirectory: true)
    }
    
    let keep: Set<String> = [
        home.appendingPathComponent("Library/Caches").standardizedFileURL.path,
        home.appendingPathComponent("Library/Preferences").standardizedFileURL.path,
    ]
    
    c.recoveryLogMax = max(c.recoveryLogMax, 16)
    
    let started = CFAbsoluteTimeGetCurrent()
    c.recoveryLog("\n-- Wiping data...")
    
    var prefsOK = true
    if let id = Bundle.main.bundleIdentifier {
        let savedData = UserDefaults.standard.object(forKey: "LCCertificateData")
        let savedPassword = UserDefaults.standard.object(forKey: "LCCertificatePassword")
        
        let before = UserDefaults.standard.persistentDomain(forName: id)?.count ?? 0
        c.recoveryLog("Clearing preferences (\(before) keys)...")
        
        UserDefaults.standard.removePersistentDomain(forName: id)
        
        if let savedData = savedData {
            UserDefaults.standard.set(savedData, forKey: "LCCertificateData")
        }
        if let savedPassword = savedPassword {
            UserDefaults.standard.set(savedPassword, forKey: "LCCertificatePassword")
        }
        
        let after = UserDefaults.standard.persistentDomain(forName: id)?.count ?? 0
        if after != 2 {
            c.recoveryLogError("  failed: \(after) keys remain")
            prefsOK = false
        }
    } else {
        c.recoveryLogError("  failed: no bundle identifier")
        prefsOK = false
    }
    
    DispatchQueue.global(qos: .userInitiated).async {
        var success = prefsOK
        var totalBytes: Int64 = 0
        
        for dir in targets {
            let name = dir.lastPathComponent
            DispatchQueue.main.async { c.recoveryLog("Formatting /\(name)...") }
            
            var stats = WipeStats()
            let ok = removeTree(dir, keeping: keep, isRoot: true, home: homePath, stats: &stats)
            success = success && ok
            totalBytes += stats.bytes
            
            let summary = "  \(stats.removedFiles) files, \(stats.removedDirectories) dirs, \(formatBytes(stats.bytes))"
            let shown = Array(stats.failures.prefix(maxFailuresShown))
            let hidden = stats.failures.count - shown.count
            
            DispatchQueue.main.async {
                c.recoveryLog(summary)
                for f in shown {
                    c.recoveryLogError("  failed: \(f.path): \(f.reason)")
                }
                if hidden > 0 {
                    c.recoveryLogError("  ... and \(hidden) more (see system log)")
                }
            }
        }
        
        let elapsed = String(format: "%.1f", CFAbsoluteTimeGetCurrent() - started)
        let tail = "(\(formatBytes(totalBytes)) in \(elapsed)s)"
        
        DispatchQueue.main.async {
            if success {
                c.recoveryLog("Data wipe complete. \(tail)")
            } else {
                c.recoveryLogError("Data wipe failed. \(tail)")
            }
        }
    }
}

func recoveryWipeCache(_ c: NXRecoveryViewController) {
    let home = URL(fileURLWithPath: NSHomeDirectory(), isDirectory: true).standardizedFileURL
    let homePath = home.path
    
    let targets = ["Library/Caches", "tmp"].map {
        home.appendingPathComponent($0, isDirectory: true)
    }
    
    let keep: Set<String> = [
        home.appendingPathComponent("Library/Caches").standardizedFileURL.path,
        home.appendingPathComponent("Library/Preferences").standardizedFileURL.path,
    ]
    
    c.recoveryLogMax = max(c.recoveryLogMax, 16)
    
    let started = CFAbsoluteTimeGetCurrent()
    c.recoveryLog("\n-- Wiping cache...")
    
    DispatchQueue.global(qos: .userInitiated).async {
        var success = true
        var totalBytes: Int64 = 0
        
        for dir in targets {
            let name = dir.lastPathComponent
            DispatchQueue.main.async { c.recoveryLog("Formatting /\(name)...") }
            
            var stats = WipeStats()
            let ok = removeTree(dir, keeping: keep, isRoot: true, home: homePath, stats: &stats)
            success = success && ok
            totalBytes += stats.bytes
            
            let summary = "  \(stats.removedFiles) files, \(stats.removedDirectories) dirs, \(formatBytes(stats.bytes))"
            let shown = Array(stats.failures.prefix(maxFailuresShown))
            let hidden = stats.failures.count - shown.count
            
            DispatchQueue.main.async {
                c.recoveryLog(summary)
                for f in shown {
                    c.recoveryLogError("  failed: \(f.path): \(f.reason)")
                }
                if hidden > 0 {
                    c.recoveryLogError("  ... and \(hidden) more (see system log)")
                }
            }
        }
        
        let elapsed = String(format: "%.1f", CFAbsoluteTimeGetCurrent() - started)
        let tail = "(\(formatBytes(totalBytes)) in \(elapsed)s)"
        
        DispatchQueue.main.async {
            if success {
                c.recoveryLog("Cache wipe complete. \(tail)")
            } else {
                c.recoveryLogError("Cache wipe failed. \(tail)")
            }
        }
    }
}

func recoveryConfirmWipe(recoveryController c: NXRecoveryViewController) {
    c.enterRecovery(
        withHeader: "Wipe all user data?\nTHIS CAN NOT BE UNDONE!",
        instructions: nil,
        footer: nil,
        items: [
            NXRecoveryItem(title: "Cancel") { c in
                if let c = c { recoveryShowMenu(recoveryController: c) }
            },
            NXRecoveryItem(title: "Factory data reset") { c in
                guard let c = c else { return }
                recoveryShowMenu(recoveryController: c)
                recoveryWipeData(c)
            },
        ],
        onSelect: nil,
        onMove: nil
    )
}

@discardableResult private func runUninstaller(_ log: RomLog) -> Bool {
    let slot = flashedSlotURL()
    let manifestURL = slot.appendingPathComponent("manifest.plist")
    guard FileManager.default.fileExists(atPath: manifestURL.path) else { return true }
    
    do {
        let manifest = try ROMManifest(manifestPlistURL: manifestURL)
        guard let uninstaller = manifest.uninstaller else { return true }
        log.info("running uninstaller of \(manifest.name)")
        try runRomGeneric(uninstaller, symbol: "NXRomUninstall", slot: slot, onLine: log.rom)
        log.info("uninstaller finished")
        return true
    } catch {
        log.error("uninstaller failed: \(error.localizedDescription)")
        return false
    }
}

private func removeFlashedSlot(_ log: RomLog) {
    let name = activeSlotName()
    let other = otherSlotName(name)
    do {
        try FileManager.default.removeItem(at: slotURL(name))
        if slotIsFlashed(other) {
            setActiveSlot(other)
            log.info("slot \(name) removed, next boot uses slot \(other)")
        } else {
            log.info("slot \(name) removed, next boot uses SuperSlot.dylib")
        }
    } catch {
        log.error("ERROR: \(errnoDescription(error))")
    }
}

func recoveryShowUnflash(recoveryController c: NXRecoveryViewController) {
    guard !romIsBusy(c) else { return }
    
    let slot = flashedSlotURL()
    guard FileManager.default.fileExists(atPath: slot.path) else {
        c.recoveryLogError("no ROM flashed")
        return
    }
    
    let manifest = try? ROMManifest(manifestPlistURL: slot.appendingPathComponent("manifest.plist"))
    
    let name = activeSlotName()
    let header: String
    if let manifest {
        header = "Unflash \(manifest.name) \(manifest.version) (slot \(name))?\n\(manifest.identifier)"
    } else {
        header = "Unflash ROM (slot \(name))?\nmanifest unreadable, only force removal possible"
    }
    
    var items: [NXRecoveryItem] = [
        NXRecoveryItem(title: "../") { c in
            if let c = c { recoveryShowMenu(recoveryController: c) }
        }
    ]
    
    if let manifest {
        let title = manifest.uninstaller != nil ? "Uninstall ROM" : "Remove ROM (no uninstaller)"
        items.append(NXRecoveryItem(title: title) { c in
            guard let c = c else { return }
            recoveryShowMenu(recoveryController: c)
            runRomOperation(c) { log in
                log.info("\n-- Unflashing \(manifest.name)...")
                
                guard runUninstaller(log) else {
                    log.error("ROM kept, use force removal to delete it anyway")
                    return
                }
                removeFlashedSlot(log)
            }
        })
    }
    
    items.append(NXRecoveryItem(title: "Force remove (skip uninstaller)") { c in
        guard let c = c else { return }
        recoveryShowMenu(recoveryController: c)
        runRomOperation(c) { log in
            log.info("\n-- Force removing ROM...")
            log.error("uninstaller skipped, leftovers outside the slot may remain")
            removeFlashedSlot(log)
        }
    })
    
    c.enterRecovery(
        withHeader: header,
        instructions: nil,
        footer: nil,
        items: items,
        onSelect: nil,
        onMove: nil
    )
}

private func flashROM(archive: URL, slotName: String, log: RomLog) throws -> ROMManifest {
    let fm = FileManager.default
    let slot = slotURL(slotName)
    
    log.info("\n-- Flashing rom into slot \(slotName)...")
    log.info("selected rom: \(archive.lastPathComponent)")
    
    try? fm.removeItem(at: slot)
    try fm.createDirectory(at: slot, withIntermediateDirectories: true, attributes: [:])
    
    guard unzipArchiveAtPathWithoutParentDirectory(archive.path, slot.path) else {
        throw romError("failed to extract ROM")
    }
    
    log.info("extracted rom")
    
    let manifest: ROMManifest = try ROMManifest(manifestPlistURL: slot.appendingPathComponent("manifest.plist"))
    
    log.info("setting up default file and directory permissions")
    guard let enumerator = fm.enumerator(at: slot, includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey]) else {
        throw NSError(domain: "org.emexlabs.nyxian.bootloader.rom-flash", code: 2, userInfo: [NSLocalizedDescriptionKey: "could not enumerate \(slot)"])
    }
    var dirs: [URL] = [slot]
    for case let url as URL in enumerator {
        let values = try url.resourceValues(forKeys: Set([.isDirectoryKey, .isSymbolicLinkKey]))
        if values.isSymbolicLink == true { continue }
        if values.isDirectory == true {
            dirs.append(url)
        } else {
            try fm.setAttributes([.posixPermissions: manifest.defaultFilePermission], ofItemAtPath: url.path)
        }
    }
    for dir in dirs.reversed() {
        try fm.setAttributes([.posixPermissions: manifest.defaultDirectoryPermission], ofItemAtPath: dir.path)
    }
    
    log.info("setting up explicit path permissions and configurations")
    var signFiles: [ROMPath] = []
    for path in manifest.paths {
        log.info("setting up \(path.path)")
        
        if path.codesigning.needed {
            signFiles.append(path)
        } else {
            try fm.setAttributes([.posixPermissions: path.permission], ofItemAtPath: slot.appendingPathComponent(path.path).path)
        }
    }
    
    if !signFiles.isEmpty {
        log.info("signing files")
        for file in signFiles {
            guard NXSignMachOAuto(slot.appendingPathComponent(file.path)) else {
                throw romError("failed to sign \(file.path)")
            }
            log.info("signed \(file.path)")
        }
        
        log.info("refreshing signed files")
        for file in signFiles {
            guard refreshVnode(atPath: slot.appendingPathComponent(file.path).path) else {
                throw romError("failed to refresh \(file.path)")
            }
            log.info("refreshed \(file.path)")
        }
        
        log.info("adding NXT2 entitlements if needed")
        for file in signFiles {
            if file.codesigning.neededNXT2 {
                let kr: kern_return_t = trust_nxt2_sign(slot.appendingPathComponent(file.path).path, file.codesigning.nxt2 as CFDictionary, true, nil)
                if kr != 0 {
                    throw romError("failed to add NXT2 entitlements to \(file.path): \(String(cString: mach_error_string(kr)))")
                }
                log.info("added NXT2 entitlements to \(file.path)")
            }
        }
        
        log.info("refixing sign files permissions")
        for file in signFiles {
            try fm.setAttributes([.posixPermissions: file.permission], ofItemAtPath: slot.appendingPathComponent(file.path).path)
        }
    }
    
    if let installer = manifest.installer {
        log.info("running installer")
        do {
            try runRomGeneric(installer, symbol: "NXRomInstall", slot: slot, onLine: log.rom)
        } catch {
            throw romError("installer failed: \(error.localizedDescription)")
        }
        log.info("installer finished")
    }
    
    return manifest
}

private func recoveryFlashROM(_ c: NXRecoveryViewController, archive: URL) {
    guard !romIsBusy(c) else { return }
    c.enterConsole()
    
    runRomOperation(c) { log in
        let previous = activeSlotName()
        let hadPrevious = slotIsFlashed(previous)
        let target = flashTargetSlotName()
        do {
            let manifest = try flashROM(archive: archive, slotName: target, log: log)
            setActiveSlot(target)
            log.info("flashed \(manifest.name) \(manifest.version) into slot \(target), slot \(target) is active")
            if hadPrevious {
                log.info("the previous ROM stays in slot \(previous)")
            }
            if !manifest.isNyxianVersionSupported {
                log.error("this ROM needs \(manifest.nyxianRequirement), this is Nyxian \(currentNyxianVersion())")
            }
            DispatchQueue.main.async {
                c.recoveryLog("\nFlash complete.\nPress both volume buttons to reboot when ready.")
                c.finishConsole(selectAction: { _ in
                    restartSelf()
                })
            }
        } catch {
            log.error("ERROR: \(error.localizedDescription)")
            try? FileManager.default.removeItem(at: slotURL(target))
            DispatchQueue.main.async {
                c.recoveryLogError(hadPrevious
                    ? "\nFlash failed, slot \(previous) untouched."
                    : "\nFlash failed.")
                c.recoveryLogError("Press both volume buttons to return to the menu.")
                c.finishConsole(selectAction: { c in
                    guard let c = c else { return }
                    c.exitConsole()
                    recoveryShowMenu(recoveryController: c)
                })
            }
        }
    }
}

// MARK: - OTA

private let otaPathKey = "org.emexlabs.nyxian.bootloader.ota-path"

private func takePendingOTA() -> String? {
    let defaults = UserDefaults.standard
    guard let path = defaults.string(forKey: otaPathKey) else { return nil }
    defaults.removeObject(forKey: otaPathKey)
    CFPreferencesAppSynchronize(kCFPreferencesCurrentApplication)
    return path
}

private func stageOTA(_ path: String) throws -> URL {
    let fm = FileManager.default
    var isDir: ObjCBool = false
    guard fm.fileExists(atPath: path, isDirectory: &isDir), !isDir.boolValue else {
        throw romError("OTA archive missing: \(path)")
    }
    let staged = URL(fileURLWithPath: NSTemporaryDirectory())
        .appendingPathComponent("ota-\(UUID().uuidString).zip")
    try fm.copyItem(at: URL(fileURLWithPath: path), to: staged)
    return staged
}

private func otaFailed(_ c: NXRecoveryViewController, slotIntact: Bool) {
    c.recoveryLogError(slotIntact
        ? "\nOTA failed, current ROM untouched."
        : "\nOTA failed, no ROM flashed, next boot uses SuperSlot.dylib.")
    c.recoveryLogError("Press both volume buttons to return to the menu.")
    c.finishConsole(selectAction: { c in
        guard let c = c else { return }
        c.exitConsole()
        recoveryShowMenu(recoveryController: c)
    })
}

private func applyOTA(_ c: NXRecoveryViewController, path: String) {
    c.enterConsole()
    
    runRomOperation(c) { log in
        log.info("\n-- Applying OTA update...")
        log.info("source: \(path)")
        
        // staging failure: slot untouched, current ROM still boots
        let staged: URL
        do {
            staged = try stageOTA(path)
        } catch {
            log.error("ERROR: \(error.localizedDescription)")
            DispatchQueue.main.async { otaFailed(c, slotIntact: true) }
            return
        }
        defer { try? FileManager.default.removeItem(at: staged) }
        
        // into the other slot: the running ROM stays where it is, as the fallback
        let previous = activeSlotName()
        let hadPrevious = slotIsFlashed(previous)
        let target = flashTargetSlotName()
        do {
            let manifest = try flashROM(archive: staged, slotName: target, log: log)
            setActiveSlot(target)
            log.info("flashed \(manifest.name) \(manifest.version) into slot \(target), slot \(target) is active")
            if hadPrevious {
                log.info("the previous ROM stays in slot \(previous)")
            }
            DispatchQueue.main.async {
                c.recoveryLog("\nUpdate complete. Rebooting...")
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    restartSelf()
                }
            }
        } catch {
            log.error("ERROR: \(error.localizedDescription)")
            try? FileManager.default.removeItem(at: slotURL(target))
            DispatchQueue.main.async { otaFailed(c, slotIntact: hadPrevious) }
        }
    }
}

// Cuz it is weak
let romImporter: ROMImporter = ROMImporter()

private func slotSwitchItems() -> [NXRecoveryItem] {
    let active = activeSlotName()
    let other = otherSlotName(active)
    guard slotIsFlashed(other) else { return [] }
    return [
        NXRecoveryItem(title: "Switch to Slot \(other)") { c in
            guard let c = c, !romIsBusy(c) else { return }
            setActiveSlot(other)
            c.recoveryLog("slot \(other) is active: \(slotSummary(other))")
            if let manifest = slotManifest(other), !manifest.isNyxianVersionSupported {
                c.recoveryLogError("it needs \(manifest.nyxianRequirement), this is Nyxian \(currentNyxianVersion())")
            }
            recoveryShowMenu(recoveryController: c)
        }
    ]
}

func recoveryShowMenu(recoveryController: NXRecoveryViewController) {
    let active = activeSlotName()
    let header = "Nyxian Recovery\n\(Bundle.main.object(forInfoDictionaryKey: "CFBundleName") ?? "UNKNOWN") \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") ?? "0.0.0") \"Scriptura\" Beta (\(Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") ?? "UNKNOWN"))\n\(slotSummary(active)) (active)\n\(slotSummary(otherSlotName(active)))"
    var items: [NXRecoveryItem] = [
        NXRecoveryItem(title: "Reboot system now") { c in
            restartSelf()
        },
        NXRecoveryItem(title: "Boot Configuration") { c in
            if let c = c {
                recoveryShowBootConfig(recoveryController: c)
            }
        },
        NXRecoveryItem(title: "Wipe data / factory reset") { c in
            if let c = c {
                recoveryConfirmWipe(recoveryController: c)
            }
        },
        NXRecoveryItem(title: "Wipe cache") { c in
            if let c = c {
                recoveryWipeCache(c)
            }
        },
        NXRecoveryItem(title: "Flash ROM") { c in
            guard let c = c, !romIsBusy(c) else { return }
            romImporter.present(from: c) { url in
                if let url = url {
                    recoveryFlashROM(c, archive: url)
                }
            }
        },
        NXRecoveryItem(title: "Unflash ROM") { c in
            if let c = c {
                recoveryShowUnflash(recoveryController: c)
            }
        },
    ]
    items.append(contentsOf: slotSwitchItems())
    items += [
        NXRecoveryItem(title: "Nyxian Files") { c in
            c?.enterFileBrowser(atPath: NSHomeDirectory(), root: NSHomeDirectory(), header: "Nyxian Files", onBack: { recovery in
                if let recovery = recovery {
                    recoveryShowMenu(recoveryController: recovery)
                }
            }, onFile: { path,name,controller in
            })
        },
        NXRecoveryItem(title: "System Files") { c in
            c?.enterFileBrowser(atPath: "/", root: "/", header: "System Files", onBack: { recovery in
                if let recovery = recovery {
                    recoveryShowMenu(recoveryController: recovery)
                }
            }, onFile: { path,name,controller in
            })
        },
        NXRecoveryItem(title: "Power Off") { c in
            UIApplication.shared.perform(Selector("suspend"))
            exit(0)
        },
    ]
    recoveryController.enterRecovery(
        withHeader: header,
        instructions: nil,
        footer: nil,
        items: items,
        onSelect: nil,
        onMove: nil
    )
}

class BootViewController: UIViewController {
    private let splashView = UIView()
    private let logoView = UIImageView()
    private var verboseConsole: VerboseBootConsole?
    private let bootCapture = BootLogCapture()
    
    private enum BootTransition {
        case zoomThrough
        case crossfade
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        BootConfig.registerDefaults()
        
        self.view.backgroundColor = .systemBackground
        
        splashView.backgroundColor = self.view.backgroundColor
        splashView.frame = self.view.bounds
        splashView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        self.view.addSubview(splashView)
        
        let slot: URL = flashedSlotURL()
        if let manifest: ROMManifest = try? ROMManifest(manifestPlistURL: slot.appendingPathComponent("manifest.plist")),
           let logo: UIImage = manifest.bootlogo {
            logoView.image = logo
        } else {
            logoView.image = UIImage(named: "EmexLogo")
        }
        logoView.contentMode = .scaleAspectFit
        logoView.translatesAutoresizingMaskIntoConstraints = false
        
        splashView.addSubview(logoView)
        
        NSLayoutConstraint.activate([
            logoView.centerYAnchor.constraint(equalTo: splashView.centerYAnchor),
            logoView.centerXAnchor.constraint(equalTo: splashView.centerXAnchor),
            logoView.heightAnchor.constraint(equalToConstant: 125),
            logoView.widthAnchor.constraint(equalToConstant: 125),
        ])
        
        // from here on, fd 27 -> live console instead of logo
        let verbose = BootConfig.isEnabled(.verboseBoot)
        if verbose {
            startVerboseBoot()
        }
        
        DispatchQueue.global(qos: .utility).async {
            if verbose { bootLog("bootloader: scanning volume buttons") }
            let mode = NXVolumeButtonMonitor.scan(for: 1.0)
            NXVolumeButtonMonitor.disarm()
            
            if mode == 2 {
                if verbose { bootLog("bootloader: recovery requested") }
                DispatchQueue.main.async {
                    self.enterRecovery(error: nil)
                }
                return
            }
            
            // only on a normal boot, safe/recovery boots leave the request pending
            if mode == 0, let otaPath = takePendingOTA() {
                if verbose { bootLog("bootloader: OTA pending: \(otaPath)") }
                DispatchQueue.main.async {
                    self.enterOTA(path: otaPath)
                }
                return
            }
            
            let forceSuperSlot = mode == 1
            
            // a ROM built for another Nyxian doesn't boot, the user can go back to the other slot
            if !forceSuperSlot,
               let manifest = slotManifest(activeSlotName()),
               !manifest.isNyxianVersionSupported {
                if verbose { bootLog("bootloader: slot \(activeSlotName()) needs \(manifest.nyxianRequirement)") }
                DispatchQueue.main.async {
                    self.presentUnsupportedROM(manifest, verbose: verbose)
                }
                return
            }
            
            self.bootSlot(forceSuperSlot: forceSuperSlot, verbose: verbose)
        }
    }
    
    /// loads the active slot (or SuperSlot.dylib) and hands over to it, off the main thread
    private func bootSlot(forceSuperSlot: Bool, verbose: Bool) {
        if verbose { bootLog(forceSuperSlot ? "bootloader: forcing SuperSlot.dylib" : "bootloader: loading slot \(activeSlotName())") }
        let slot = loadSlot(loadSuperslotForcefully: forceSuperSlot)
        
        DispatchQueue.main.async {
            guard case let .loaded(name, slotMain, slotDidAppear, slotCreateWindow) = slot else {
                if case let .failed(message) = slot {
                    self.enterRecovery(error: "ERROR: \(message)")
                }
                return
            }
            
            if verbose { bootLog("bootloader: \(name) loaded, entering NXSlotMain") }
            let raw = slotMain()
            if verbose { bootLog("bootloader: NXSlotMain returned") }
            
            // NXSlotMain returned -> boot is over, fd 27 goes back to what it was
            self.bootCapture.stop()
            
            guard let raw else {
                self.enterRecovery(error: "ERROR: \(name) NXSlotMain returned no view controller")
                return
            }
            let slotRoot = Unmanaged<UIViewController>.fromOpaque(raw).takeRetainedValue()
            
            let hold: TimeInterval = verbose ? verboseBootHold : 0
            DispatchQueue.main.asyncAfter(deadline: .now() + hold) {
                self.changableStatusBarHidden = false
                UIView.animate(withDuration: 0.3) {
                    self.setNeedsStatusBarAppearanceUpdate()
                }
                
                if let slotCreateWindow, let slotWindow = self.makeSlotWindow(slotCreateWindow) {
                    self.transition(into: slotWindow, root: slotRoot) {
                        slotDidAppear?()
                    }
                } else {
                    self.transition(to: slotRoot) {
                        slotDidAppear?()
                    }
                }
            }
        }
    }
    
    private func presentUnsupportedROM(_ manifest: ROMManifest, verbose: Bool) {
        let active = activeSlotName()
        let other = otherSlotName(active)
        
        let alert = UIAlertController(
            title: "Update Nyxian",
            message: "\(manifest.name) \(manifest.version) in slot \(active) needs \(manifest.nyxianRequirement). This is Nyxian \(currentNyxianVersion()). Update Nyxian to boot this ROM.",
            preferredStyle: .alert)
        
        if let previous = slotManifest(other), previous.isNyxianVersionSupported {
            alert.addAction(UIAlertAction(title: "Revert to Slot \(other)", style: .default) { _ in
                setActiveSlot(other)
                if let logo = previous.bootlogo {
                    self.logoView.image = logo
                }
                DispatchQueue.global(qos: .utility).async {
                    self.bootSlot(forceSuperSlot: false, verbose: verbose)
                }
            })
        }
        alert.addAction(UIAlertAction(title: "Recovery", style: .cancel) { _ in
            self.enterRecovery(error: "slot \(active): \(manifest.name) \(manifest.version) needs \(manifest.nyxianRequirement), this is Nyxian \(currentNyxianVersion())")
        })
        
        self.present(alert, animated: true)
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        if splashView.superview != nil {
            verboseConsole?.layout(in: splashView)
        }
    }
    
    // MARK: - Verbose boot
    
    private func startVerboseBoot() {
        let console = VerboseBootConsole(in: splashView)
        verboseConsole = console
        logoView.isHidden = true
        
        // runs on the drain thread and draws right there, main is never involved
        let ok = bootCapture.start { line in
            console.append(line, isError: line.hasPrefix("ERROR:"))
        }
        if !ok {
            console.append("ERROR: couldn't capture fd \(nxRomLogFD): \(String(cString: strerror(errno)))", isError: true)
        }
    }
    
    // MARK: - Transitions
    
    private func makeSlotWindow(_ create: NXSlotCreateWindowFn) -> UIWindow? {
        guard let scene = view.window?.windowScene else { return nil }
        guard let raw = create(Unmanaged.passUnretained(scene).toOpaque()) else { return nil }
        return Unmanaged<UIWindow>.fromOpaque(raw).takeRetainedValue()
    }
    
    private func transition(into slotWindow: UIWindow,
                            root: UIViewController,
                            completion: (() -> Void)? = nil) {
        let hostWindow = view.window
        
        slotWindow.rootViewController = root
        slotWindow.alpha = 0
        slotWindow.makeKeyAndVisible()
        root.view.layoutIfNeeded()
        
        if let presentation = logoView.layer.presentation() {
            logoView.layer.transform = presentation.transform
        }
        logoView.layer.removeAnimation(forKey: "breathe")
        
        let finish = {
            hostWindow?.isHidden = true
            hostWindow?.rootViewController = nil
            if let scene = slotWindow.windowScene {
                (scene.delegate as? SceneDelegate)?.window = slotWindow
            }
            completion?()
        }
        
        if UIAccessibility.isReduceMotionEnabled {
            UIView.animate(withDuration: 0.3, animations: {
                slotWindow.alpha = 1
            }, completion: { _ in
                finish()
            })
            return
        }
        
        root.view.transform = CGAffineTransform(scaleX: 0.97, y: 0.97)
        
        let splashOut = UIViewPropertyAnimator(duration: 0.4, curve: .easeOut) {
            self.logoView.transform = CGAffineTransform(scaleX: 1.15, y: 1.15)
            self.splashView.alpha = 0
            slotWindow.alpha = 1
        }
        
        let appIn = UIViewPropertyAnimator(duration: 0.55, dampingRatio: 1.0) {
            root.view.transform = .identity
        }
        
        appIn.addCompletion { _ in
            finish()
        }
        
        splashOut.startAnimation()
        appIn.startAnimation()
    }
    
    private func makeRecoveryController() -> NXRecoveryViewController {
        bootCapture.stop()
        
        let recoveryController = NXRecoveryViewController()
        
        // carry the boot log over into recovery
        if let console = verboseConsole {
            recoveryController.recoveryLogMax = max(recoveryController.recoveryLogMax, bootLogMax)
            for entry in console.snapshot().suffix(bootLogMax) {
                if entry.isError {
                    recoveryController.recoveryLogError(entry.text)
                } else {
                    recoveryController.recoveryLog(entry.text)
                }
            }
        }
        
        return recoveryController
    }
    
    private func enterRecovery(error: String?) {
        let recoveryController = makeRecoveryController()
        
        if let error {
            recoveryController.recoveryLogError(error)
        }
        recoveryShowMenu(recoveryController: recoveryController)
        self.transition(to: recoveryController, style: .crossfade)
    }
    
    private func enterOTA(path: String) {
        let recoveryController = makeRecoveryController()
        
        // menu underneath so a failed OTA can drop back into it
        recoveryShowMenu(recoveryController: recoveryController)
        self.transition(to: recoveryController, style: .crossfade)
        applyOTA(recoveryController, path: path)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        startBreathing()
    }
    
    private func startBreathing() {
        guard !UIAccessibility.isReduceMotionEnabled,
              !logoView.isHidden,
              splashView.superview != nil,
              logoView.layer.animation(forKey: "breathe") == nil else { return }
        
        let pulse = CABasicAnimation(keyPath: "transform.scale")
        pulse.fromValue = 1.0
        pulse.toValue = 0.94
        pulse.duration = 0.9
        pulse.autoreverses = true
        pulse.repeatCount = .infinity
        pulse.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        logoView.layer.add(pulse, forKey: "breathe")
    }
    
    private func transition(to child: UIViewController,
                            style: BootTransition = .zoomThrough,
                            completion: (() -> Void)? = nil) {
        addChild(child)
        child.view.frame = view.bounds
        child.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.insertSubview(child.view, belowSubview: splashView)
        child.view.layoutIfNeeded()
        
        if let presentation = logoView.layer.presentation() {
            logoView.layer.transform = presentation.transform
        }
        logoView.layer.removeAnimation(forKey: "breathe")
        
        let finish = {
            self.splashView.removeFromSuperview()
            child.didMove(toParent: self)
            completion?()
        }
        
        if style == .crossfade || UIAccessibility.isReduceMotionEnabled {
            UIView.animate(withDuration: 0.3, animations: {
                self.splashView.alpha = 0
            }, completion: { _ in
                finish()
            })
            return
        }
        
        child.view.transform = CGAffineTransform(scaleX: 0.97, y: 0.97)
        
        let splashOut = UIViewPropertyAnimator(duration: 0.4, curve: .easeOut) {
            self.logoView.transform = CGAffineTransform(scaleX: 1.15, y: 1.15)
            self.splashView.alpha = 0
        }
        
        let appIn = UIViewPropertyAnimator(duration: 0.55, dampingRatio: 1.0) {
            child.view.transform = .identity
        }
        
        appIn.addCompletion { _ in
            finish()
        }
        
        splashOut.startAnimation()
        appIn.startAnimation()
    }
    
    var changableStatusBarHidden = true
    override var prefersStatusBarHidden: Bool {
        return self.changableStatusBarHidden
    }
    
    override var preferredStatusBarUpdateAnimation: UIStatusBarAnimation {
        return .fade
    }
    
    override var childForStatusBarStyle: UIViewController? {
        splashView.superview == nil ? children.last : nil
    }
}

@main
class AppDelegate: UIResponder, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        return true
    }
}

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?
    
    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = scene as? UIWindowScene else { return }
        
        let window = UIWindow(windowScene: windowScene)
        window.rootViewController = BootViewController()
        window.makeKeyAndVisible()
        self.window = window
    }
}
