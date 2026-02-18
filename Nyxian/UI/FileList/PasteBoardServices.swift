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

class PasteBoardServices {
    enum Mode {
        case copy
        case move
    }

    static var paths: Set<String> = []
    static var onMove: () -> Void = {}
    static var mode: PasteBoardServices.Mode = .copy

    static func copy(mode: PasteBoardServices.Mode, paths: Set<String>) {
        PasteBoardServices.paths = paths
        PasteBoardServices.mode = mode
    }

    static func paste(path: String, addFileHandler: @escaping (URL) -> Void) {
        for item in PasteBoardServices.paths {
            guard item != "0" else {
                print("PasteBoardServices:Error: Nothing to do here")
                continue
            }

            let dest = resolvedDestinationURL(for: item, inDirectory: path)
            
            if PasteBoardServices.mode == .copy {
                if (try? FileManager.default.copyItem(atPath: item, toPath: dest.path)) != nil {
                    DispatchQueue.main.async { addFileHandler(dest) }
                }
            } else {
                if (try? FileManager.default.moveItem(atPath: item, toPath: dest.path)) != nil {
                    PasteBoardServices.onMove()
                    PasteBoardServices.onMove = {}
                    DispatchQueue.main.async { addFileHandler(dest) }
                }
            }
        }

        PasteBoardServices.paths = []
    }

    static func needPaste() -> Bool {
        return !PasteBoardServices.paths.isEmpty
    }
    
    private static func resolvedDestinationURL(for sourcePath: String, inDirectory directory: String) -> URL {
        let sourceURL = URL(fileURLWithPath: sourcePath)
        let dirURL = URL(fileURLWithPath: directory)

        let ext  = sourceURL.pathExtension
        let base = sourceURL.deletingPathExtension().lastPathComponent

        func candidate(_ suffix: String) -> URL {
            let name = suffix.isEmpty ? base : "\(base) \(suffix)"
            return ext.isEmpty
                ? dirURL.appendingPathComponent(name)
                : dirURL.appendingPathComponent(name).appendingPathExtension(ext)
        }

        var dest = candidate("")
        var counter = 1

        while FileManager.default.fileExists(atPath: dest.path) {
            dest = candidate("\(counter)")
            counter += 1
        }

        return dest
    }
}
