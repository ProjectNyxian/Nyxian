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

struct FileListEntry: Identifiable {
    enum FileListEntryType {
        case file
        case dir
    }
    
    let id: UUID = UUID()
    let name: String
    let path: String
    let isLink: Bool
    let type: FileListEntryType
    
    static func getEntry(ofPath path: String) -> FileListEntry {
        var entry = FileListEntry(name: "N/A", path: path, isLink: false, type: .file)
        do {
            var isDirectory: ObjCBool = false
            if FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory),
               let fileType = try FileManager.default.attributesOfItem(atPath: path)[.type] as? FileAttributeType {
                let isLink: Bool = (fileType == .typeSymbolicLink)
                entry = FileListEntry(name: URL(fileURLWithPath: path).lastPathComponent,
                                      path: path,
                                      isLink: isLink,
                                      type: isDirectory.boolValue ? .dir : .file)
            }
        } catch {
            print(error.localizedDescription)
        }
        
        return entry
    }
    
    static func getEntries(ofPath path: String) -> [FileListEntry] {
        var entries: [FileListEntry]? = nil
        do {
            let rawEntries: [String] = try FileManager.default.contentsOfDirectory(atPath: path)
            entries = rawEntries.map { FileListEntry.getEntry(ofPath: "\(path)/\($0)") }
            entries!.sort {
                $0.type == $1.type
                    ? $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
                    : $0.type == .dir
            }
        } catch {
            print(error)
        }
        return entries ?? []
    }
    
    static func getEntries(ofPath path: String, perEntryHandler: (FileListEntry) -> Void) {
        for item in FileListEntry.getEntries(ofPath: path) {
            perEntryHandler(item)
        }
    }
}
