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

func expectedObjectFile(forPath path: String) -> String {
    let url = URL(fileURLWithPath: "/\(path)").deletingPathExtension().appendingPathExtension("o")
    return String(String(url.path).dropFirst())
}

func relativePath(from base: URL, to fullPath: URL) -> String {
    let baseComponents = base.standardized.pathComponents
    let fullComponents = fullPath.standardized.pathComponents

    let relativeComponents = Array(fullComponents.dropFirst(baseComponents.count))
    
    return relativeComponents.joined(separator: "/")
}

func syncFolderStructure(from sourceURL: URL,
                         to destinationURL: URL) throws {
    let fileManager = FileManager.default

    // Get all directories in source path
    let sourceDirectories = try fileManager.subpathsOfDirectory(atPath: sourceURL.path)
        .map { sourceURL.appendingPathComponent($0) }
        .filter { url in
            var isDir: ObjCBool = false
            return fileManager.fileExists(atPath: url.path, isDirectory: &isDir) && isDir.boolValue
        }

    // Create missing directories in destination
    for sourceDir in sourceDirectories {
        let relativePath = sourceDir.path.replacingOccurrences(of: sourceURL.path, with: "")
        let destDir = destinationURL.appendingPathComponent(relativePath)
        if !fileManager.fileExists(atPath: destDir.path) {
            try fileManager.createDirectory(at: destDir, withIntermediateDirectories: true, attributes: nil)
        }
    }

    // Get all directories in destination path
    let destinationDirectories = try fileManager.subpathsOfDirectory(atPath: destinationURL.path)
        .map { destinationURL.appendingPathComponent($0) }
        .filter { url in
            var isDir: ObjCBool = false
            return fileManager.fileExists(atPath: url.path, isDirectory: &isDir) && isDir.boolValue
        }

    // Remove extra directories in destination that don't exist in source
    /* FIXME: need to comment this out otherwise swift module cache gets removed */
    /*for destDir in destinationDirectories {
        let relativePath = destDir.path.replacingOccurrences(of: destinationURL.path, with: "")
        let sourceDir = sourceURL.appendingPathComponent(relativePath)
        if !fileManager.fileExists(atPath: sourceDir.path) {
            try fileManager.removeItem(at: destDir)
        }
    }*/
    
    ///
    /// This is a early code of fixing the issue where object and source files are out of sync when removing source code files
    ///
    let rsourceSet: Set<String> = Set(LDEFilesFinder(
        sourceURL.path,
        ["c", "cpp", "mm", "m"],
        ["Resources"]
    ).map {
        expectedObjectFile(forPath: relativePath(from: sourceURL, to: URL(fileURLWithPath: $0)))
    })
    
    let robject: [String] = LDEFilesFinder(
        destinationURL.path,
        ["o"],
        ["Resources"]
    ).map {
        relativePath(from: destinationURL, to: URL(fileURLWithPath: $0))
    }
    
    for item in robject {
        if !rsourceSet.contains(item) {
            try? FileManager.default.removeItem(at: destinationURL.appendingPathComponent(item))
        }
    }
}
