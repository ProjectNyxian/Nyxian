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

class HeaderIncludationsGatherer {
    let path: String
    var includes: [String]
    
    init(path: String) {
        self.path = path
        self.includes = []

        do {
            let content = try String(contentsOfFile: path, encoding: .utf8)
            try gatherIncludations(forFile: path, content: content)
        } catch {
            print(error.localizedDescription)
        }
    }
    
    func matchIncludations(content: String) throws -> [String] {
        let regex = try NSRegularExpression(pattern: #"#(?:import|include)\s+"([^"]+)""#, options: [])
        let matches = regex.matches(in: content, options: [], range: NSRange(content.startIndex..., in: content))
        let includePaths = matches.compactMap { match -> String? in
            guard let range = Range(match.range(at: 1), in: content) else { return nil }
            return String(content[range])
        }
        return includePaths
    }
    
    func gatherIncludations(forFile filePath: String, content: String) throws {
        let items = try matchIncludations(content: content)
        
        for item in items {
            let resolvedPath = resolveFilePath(forInclude: item, fromFile: filePath)
            
            includes.append(resolvedPath)
            
            if FileManager.default.fileExists(atPath: resolvedPath) {
                do {
                    let includedContent = try String(contentsOfFile: resolvedPath, encoding: .utf8)
                    try gatherIncludations(forFile: resolvedPath, content: includedContent)
                } catch {
                    print("Error reading file \(resolvedPath): \(error.localizedDescription)")
                }
            }
        }
    }
    
    func resolveFilePath(forInclude include: String, fromFile filePath: String) -> String {
        let directory = (filePath as NSString).deletingLastPathComponent
        return (directory as NSString).appendingPathComponent(include)
    }
}
