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
    
    static var path: String = ""
    static var onMove: () -> Void = {}
    static var mode: PasteBoardServices.Mode = .copy
    
    static func copy(mode: PasteBoardServices.Mode, path: String) {
        PasteBoardServices.path = path
        PasteBoardServices.mode = mode
    }
    
    static func paste(path: String) {
        if PasteBoardServices.path != "0" {
            // Craft full path
            let fileName: String = URL(fileURLWithPath: self.path).lastPathComponent
            let dest: String = URL(fileURLWithPath: path).appendingPathComponent(fileName).path
            
            // Overwrite automatically if exists
            if FileManager.default.fileExists(atPath: dest) {
                try? FileManager.default.removeItem(atPath: dest)
            }
            
            // Now copy/move it
            if PasteBoardServices.mode == .copy {
                try? FileManager.default.copyItem(atPath: self.path, toPath: dest)
            } else {
                try? FileManager.default.moveItem(atPath: self.path, toPath: dest)
                PasteBoardServices.onMove()
            }
            
            // Unregister onMove action
            PasteBoardServices.onMove = {}
            PasteBoardServices.path = "0"
        } else {
            print("PasteBoardServices:Error: Nothing to do here")
        }
    }
    
    static func needPaste() -> Bool {
        return (PasteBoardServices.path != "0")
    }
}
