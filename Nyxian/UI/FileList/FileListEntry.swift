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
                                      path: isLink ? try FileManager.default.destinationOfSymbolicLink(atPath: path) : path,
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

class FileAction {
    enum FileActionType {
        case none
        case move
        case copy
    }
    
    @Published var path: String = ""
    @Published var action: FileAction.FileActionType = .none
    
    static let shared = FileAction()
}
