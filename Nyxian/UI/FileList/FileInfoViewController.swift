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
import UIKit
import Darwin
import UniformTypeIdentifiers

class FileInfoViewController: NXUITableViewController {
    
    private struct Row {
        let title: String
        var value: String
        var monospaced: Bool = false
    }
    
    private struct Section {
        let title: String?
        var rows: [Row]
    }
    
    let fileEntry: FileListEntry
    let fileAttr: [FileAttributeKey: Any]
    
    private var sections: [Section] = []
    
    private var directorySizeIndexPath: IndexPath?
    
    private static let dateFormatter: DateFormatter = {
        let fmt = DateFormatter()
        fmt.dateStyle = .medium
        fmt.timeStyle = .short
        return fmt
    }()
    
    init(fileEntry: FileListEntry) throws {
        self.fileEntry = fileEntry
        self.fileAttr = try FileManager.default.attributesOfItem(atPath: fileEntry.path)
        
        super.init(style: .insetGrouped)
    }
    
    @MainActor required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.title = "\(self.fileEntry.name) Info"
        self.tableView.register(UITableViewCell.self, forCellReuseIdentifier: "filelist.info.vc")
        
        self.buildSections()
        
        if self.fileType == .typeDirectory {
            self.loadDirectorySize()
        }
    }
    
    private var fileType: FileAttributeType? {
        guard let raw = self.fileAttr[.type] as? String else { return nil }
        return FileAttributeType(rawValue: raw)
    }
    
    private var logicalSize: Int64 {
        (self.fileAttr[.size] as? NSNumber)?.int64Value ?? 0
    }
    
    private func number(_ key: FileAttributeKey) -> NSNumber? {
        self.fileAttr[key] as? NSNumber
    }
    
    private func date(_ key: FileAttributeKey) -> String? {
        guard let date = self.fileAttr[key] as? Date else { return nil }
        return Self.dateFormatter.string(from: date)
    }
    
    private static func describe(_ type: FileAttributeType?) -> String {
        switch type {
            case .some(.typeRegular):
                return "Regular File"
            case .some(.typeDirectory):
                return "Directory"
            case .some(.typeSymbolicLink):
                return "Symbolic Link"
            case .some(.typeSocket):
                return "Socket"
            case .some(.typeCharacterSpecial):
                return "Character Device"
            case .some(.typeBlockSpecial):
                return "Block Device"
            default:
                return "Unknown"
        }
    }
    
    private static func describePermissions(_ mode: UInt16) -> String {
        let bits = ["---", "--x", "-w-", "-wx", "r--", "r-x", "rw-", "rwx"]
        let owner = bits[Int((mode >> 6) & 0o7)]
        let group = bits[Int((mode >> 3) & 0o7)]
        let other = bits[Int(mode & 0o7)]
        return "\(owner)\(group)\(other) (\(String(mode & 0o7777, radix: 8)))"
    }
    
    private static func describeProtection(_ raw: String) -> String {
        switch FileProtectionType(rawValue: raw) {
            case .complete:
                return "Complete"
            case .completeUnlessOpen:
                return "Complete Unless Open"
            case .completeUntilFirstUserAuthentication:
                return "Until First Unlock"
            case .none:
                return "None"
            default:
                return raw
        }
    }
    
    private static func kind(for path: String, type: FileAttributeType?) -> String {
        if type == .typeDirectory { return "Folder" }
        if type == .typeSymbolicLink { return "Alias" }
        
        let ext = (path as NSString).pathExtension
        if !ext.isEmpty,
           let utType = UTType(filenameExtension: ext),
           let description = utType.localizedDescription {
            return description
        }
        return ext.isEmpty ? "Document" : "\(ext.uppercased()) File"
    }
    
    private static func allocatedSize(for path: String) -> Int64? {
        let url = URL(fileURLWithPath: path)
        let values = try? url.resourceValues(forKeys: [.totalFileAllocatedSizeKey])
        return (values?.totalFileAllocatedSize).map(Int64.init)
    }
    
    private static func extendedAttributeNames(atPath path: String) -> [String] {
        let length = listxattr(path, nil, 0, XATTR_NOFOLLOW)
        guard length > 0 else {
            return []
        }
        
        var buffer = [CChar](repeating: 0, count: length)
        guard listxattr(path, &buffer, length, XATTR_NOFOLLOW) > 0 else { return [] }
        
        return buffer.split(separator: 0).compactMap { slice in
            String(cString: Array(slice) + [0])
        }
    }
    
    private func buildSections() {
        let path = self.fileEntry.path
        let type = self.fileType
        var result: [Section] = []
        
        var general: [Row] = [
            Row(title: "Name", value: self.fileEntry.name),
            Row(title: "Kind", value: Self.kind(for: path, type: type))
        ]
        
        if type == .typeDirectory {
            general.append(Row(title: "Size", value: "Calculating\u{2026}"))
            self.directorySizeIndexPath = IndexPath(row: general.count - 1, section: 0)
        } else {
            general.append(Row(title: "Size", value: ByteCountFormatter.string(fromByteCount: self.logicalSize, countStyle: .file)))
            if let allocated = Self.allocatedSize(for: path), allocated != self.logicalSize {
                general.append(Row(title: "On Disk", value: ByteCountFormatter.string(fromByteCount: allocated, countStyle: .file)))
            }
        }
        
        if type == .typeSymbolicLink, let target = try? FileManager.default.destinationOfSymbolicLink(atPath: path) {
            general.append(Row(title: "Target", value: target, monospaced: true))
        }
        
        general.append(Row(title: "Where", value: (path as NSString).deletingLastPathComponent, monospaced: true))
        result.append(Section(title: "General", rows: general))
        
        var dates: [Row] = []
        if let created = self.date(.creationDate) {
            dates.append(Row(title: "Created", value: created))
        }
        if let modified = self.date(.modificationDate) {
            dates.append(Row(title: "Modified", value: modified))
        }
        if !dates.isEmpty {
            result.append(Section(title: "Dates", rows: dates))
        }
        
        var ownership: [Row] = []
        if let owner = self.fileAttr[.ownerAccountName] as? String {
            ownership.append(Row(title: "Owner", value: owner))
        } else if let uid = self.number(.ownerAccountID) {
            ownership.append(Row(title: "Owner", value: "uid \(uid.intValue)"))
        }
        if let group = self.fileAttr[.groupOwnerAccountName] as? String {
            ownership.append(Row(title: "Group", value: group))
        } else if let gid = self.number(.groupOwnerAccountID) {
            ownership.append(Row(title: "Group", value: "gid \(gid.intValue)"))
        }
        if let mode = self.number(.posixPermissions)?.uint16Value {
            ownership.append(Row(title: "Permissions", value: Self.describePermissions(mode), monospaced: true))
        }
        if let protection = self.fileAttr[.protectionKey] as? String {
            ownership.append(Row(title: "Protection", value: Self.describeProtection(protection)))
        }
        if !ownership.isEmpty {
            result.append(Section(title: "Ownership", rows: ownership))
        }
        
        var advanced: [Row] = [Row(title: "Type", value: Self.describe(type))]
        if let inode = self.number(.systemFileNumber) {
            advanced.append(Row(title: "Inode", value: "\(inode.uint64Value)", monospaced: true))
        }
        if let links = self.number(.referenceCount), links.intValue > 1 {
            advanced.append(Row(title: "Hard Links", value: "\(links.intValue)"))
        }
        
        var flags: [String] = []
        if self.number(.immutable)?.boolValue == true { flags.append("immutable") }
        if self.number(.appendOnly)?.boolValue == true { flags.append("append-only") }
        if self.number(.extensionHidden)?.boolValue == true { flags.append("hidden extension") }
        if !flags.isEmpty {
            advanced.append(Row(title: "Flags", value: flags.joined(separator: ", ")))
        }
        result.append(Section(title: "Advanced", rows: advanced))
        
        let xattrs = Self.extendedAttributeNames(atPath: path)
        if !xattrs.isEmpty {
            result.append(Section(title: "Extended Attributes", rows: xattrs.map { Row(title: $0, value: "", monospaced: true) }))
        }
        
        self.sections = result
    }
    
    private func loadDirectorySize() {
        let path = self.fileEntry.path
        
        Task.detached(priority: .utility) {
            var total: Int64 = 0
            var items = 0
            
            let url = URL(fileURLWithPath: path)
            let keys: Set<URLResourceKey> = [.totalFileAllocatedSizeKey, .fileSizeKey, .isRegularFileKey]
            if let enumerator = FileManager.default.enumerator(at: url, includingPropertiesForKeys: Array(keys), options: [], errorHandler: { _, _ in true }) {
                for case let child as URL in enumerator {
                    guard let values = try? child.resourceValues(forKeys: keys) else { continue }
                    items += 1
                    if values.isRegularFile == true {
                        total += Int64(values.totalFileAllocatedSize ?? values.fileSize ?? 0)
                    }
                }
            }
            
            let formatted = ByteCountFormatter.string(fromByteCount: total, countStyle: .file)
            let summary = "\(formatted), \(items) item\(items == 1 ? "" : "s")"
            
            await MainActor.run { [weak self] in
                guard let self, let indexPath = self.directorySizeIndexPath else {
                    return
                }
                self.sections[indexPath.section].rows[indexPath.row].value = summary
                if self.isViewLoaded {
                    self.tableView.reloadRows(at: [indexPath], with: .none)
                }
            }
        }
    }
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return self.sections.count
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.sections[section].rows.count
    }
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return self.sections[section].title
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "filelist.info.vc", for: indexPath)
        let row = self.sections[indexPath.section].rows[indexPath.row]
        
        var config = UIListContentConfiguration.valueCell()
        config.text = row.title
        config.secondaryText = row.value.isEmpty ? nil : row.value
        config.prefersSideBySideTextAndSecondaryText = true
        config.secondaryTextProperties.numberOfLines = 0
        if row.monospaced {
            config.secondaryTextProperties.font = .monospacedSystemFont(ofSize: 15, weight: .regular)
        }
        
        cell.contentConfiguration = config
        cell.selectionStyle = .none
        return cell
    }
    
    override func tableView(_ tableView: UITableView, contextMenuConfigurationForRowAt indexPath: IndexPath, point: CGPoint) -> UIContextMenuConfiguration? {
        let row = self.sections[indexPath.section].rows[indexPath.row]
        let copied = row.value.isEmpty ? row.title : row.value
        
        return UIContextMenuConfiguration(identifier: nil, previewProvider: nil) { _ in
            UIMenu(children: [
                UIAction(title: "Copy", image: UIImage(systemName: "doc.on.doc")) { _ in
                    UIPasteboard.general.string = copied
                }
            ])
        }
    }
}
