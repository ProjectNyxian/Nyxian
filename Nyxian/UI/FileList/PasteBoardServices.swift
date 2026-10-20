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
    
    static func resolvedDestinationURL(for sourcePath: String, inDirectory directory: String) -> URL {
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
