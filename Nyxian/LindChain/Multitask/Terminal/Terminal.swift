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
import SwiftTerm
import SwiftUI
import UIKit

// use always the same pipe
@objc class NyxianTerminal: TerminalView, TerminalViewDelegate {
    var title: String
    
    @objc var stdoutHandle: FileHandle?
    @objc var stdinHandle: FileHandle?
    
    @objc var inputCallBack: () -> Void = {}
    
    @objc public init (
        frame: CGRect,
        title: String,
        stdoutFD: Int32,
        stdinFD: Int32
    ){
        self.title = title
        
        self.stdoutHandle = FileHandle(fileDescriptor: stdoutFD, closeOnDealloc: false)
        self.stdinHandle = FileHandle(fileDescriptor: stdinFD, closeOnDealloc: false)
        
        super.init(frame: frame)
        
        self.isOpaque = false;
        self.terminalDelegate = self
        self.backgroundColor = .secondarySystemBackground
        self.nativeForegroundColor = gibDynamicColor(light: .label, dark: self.nativeForegroundColor)
        self.caretTextColor = .label
        self.font = UIFont.monospacedSystemFont(ofSize: (UIDevice.current.userInterfaceIdiom == .pad) ? 14 : 10, weight: .regular)
        _ = self.becomeFirstResponder()
        
        stdoutHandle?.readabilityHandler = { [weak self] fileHandle in
            guard let self = self else { return }
            let data = fileHandle.availableData
            guard !data.isEmpty else { return }
            
            let fixed = data.reduce(into: [UInt8]()) { buffer, byte in
                var byte = byte
                if byte == 0x0A {
                    buffer.append(0x0D)
                } else if byte == 0x0D {
                    byte = 0x0A
                    buffer.append(0x0D)
                }
                buffer.append(byte)
            }
            
            DispatchQueue.main.async {
                self.feed(byteArray: fixed[...])
            }
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func clipboardCopy(source: SwiftTerm.TerminalView, content: Data) {
        
    }
    
    func scrolled(source: SwiftTerm.TerminalView, position: Double) {
        
    }
    
    func setTerminalTitle(source: SwiftTerm.TerminalView, title: String) {
        self.title = title
    }
    
    func sizeChanged(source: SwiftTerm.TerminalView, newCols: Int, newRows: Int) {
        //tcom_set_size(Int32(newRows), Int32(newCols))
    }
    
    func hostCurrentDirectoryUpdate(source: SwiftTerm.TerminalView, directory: String?) {
        
    }
    
    func send(source: SwiftTerm.TerminalView, data: ArraySlice<UInt8>) {
        var array = Array(data)
        if let stdoutFD = stdinHandle?.fileDescriptor {
            write(stdoutFD, &array, array.count)
        }
        inputCallBack()
    }
    
    func requestOpenLink(source: SwiftTerm.TerminalView, link: String, params: [String : String]) {
        
    }
    
    func rangeChanged(source: SwiftTerm.TerminalView, startY: Int, endY: Int) {
        
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)

        guard traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) else { return }
        
        if self.isFirstResponder {
            _ = self.resignFirstResponder()
            _ = self.becomeFirstResponder()
        }
    }
}
