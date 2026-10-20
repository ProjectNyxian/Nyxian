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

import SwiftTerm
import UIKit

@objc protocol TerminalViewDelegateObjC: AnyObject {
    @objc optional func sizeChanged(source: TerminalView, newCols: Int, newRows: Int)
    @objc optional func setTerminalTitle(source: TerminalView, title: String)
    @objc optional func hostCurrentDirectoryUpdate(source: TerminalView, directory: String?)
    @objc optional func send(source: TerminalView, data: Data)
    @objc optional func scrolled(source: TerminalView, position: Double)
    @objc optional func requestOpenLink(source: TerminalView, link: String, params: [String: String])
    @objc optional func bell(source: TerminalView)
    @objc optional func clipboardCopy(source: TerminalView, content: Data)
    @objc optional func iTermContent(source: TerminalView, content: Data)
    @objc optional func rangeChanged(source: TerminalView, startY: Int, endY: Int)
}

@objc class TerminalViewObjC: TerminalView {
    @objc var ttyHandle: FileHandle?
    
    private var _objcDelegateAdapter: ObjCDelegateAdapter?
    @objc public weak var objcDelegate: (any TerminalViewDelegateObjC)? {
        didSet {
            if let d = objcDelegate {
                _objcDelegateAdapter = ObjCDelegateAdapter(d)
                self.terminalDelegate = _objcDelegateAdapter
            } else {
                self.delegate = nil
            }
        }
    }
    
    private class ObjCDelegateAdapter: TerminalViewDelegate {
        weak var objcDelegate: TerminalViewDelegateObjC?
        
        init(_ delegate: TerminalViewDelegateObjC) {
            self.objcDelegate = delegate
        }
        
        func sizeChanged(source: TerminalView, newCols: Int, newRows: Int) {
            objcDelegate?.sizeChanged?(source: source, newCols: newCols, newRows: newRows)
        }
        func setTerminalTitle(source: TerminalView, title: String) {
            objcDelegate?.setTerminalTitle?(source: source, title: title)
        }
        func hostCurrentDirectoryUpdate(source: TerminalView, directory: String?) {
            objcDelegate?.hostCurrentDirectoryUpdate?(source: source, directory: directory)
        }
        func send(source: TerminalView, data: ArraySlice<UInt8>) {
            objcDelegate?.send?(source: source, data: Data(data))
        }
        func scrolled(source: TerminalView, position: Double) {
            objcDelegate?.scrolled?(source: source, position: position)
        }
        func requestOpenLink(source: TerminalView, link: String, params: [String: String]) {
            objcDelegate?.requestOpenLink?(source: source, link: link, params: params)
        }
        func bell(source: TerminalView) {
            objcDelegate?.bell?(source: source)
        }
        func clipboardCopy(source: TerminalView, content: Data) {
            objcDelegate?.clipboardCopy?(source: source, content: content)
        }
        func iTermContent(source: TerminalView, content: ArraySlice<UInt8>) {
            objcDelegate?.iTermContent?(source: source, content: Data(content))
        }
        func rangeChanged(source: TerminalView, startY: Int, endY: Int) {
            objcDelegate?.rangeChanged?(source: source, startY: startY, endY: endY)
        }
    }
    
    @objc public init (
        frame: CGRect,
        masterFD: Int32
    ){
        self.ttyHandle = FileHandle(fileDescriptor: masterFD, closeOnDealloc: false)
        
        super.init(frame: frame)
        
        self.isOpaque = false;
        self.backgroundColor = LDETheme.currentTheme?.backgroundColor ?? .secondarySystemBackground
        self.nativeForegroundColor = LDETheme.currentTheme?.textColor ?? gibDynamicColor(light: .label, dark: self.nativeForegroundColor)
        self.caretTextColor = LDETheme.currentTheme?.textColor ?? gibDynamicColor(light: .label, dark: self.nativeForegroundColor)
        self.font = UIFont.monospacedSystemFont(ofSize: (UIDevice.current.userInterfaceIdiom == .pad) ? 14 : 10, weight: .regular)
        
        self.ttyHandle?.readabilityHandler = { [weak self] fileHandle in
            guard let self = self else { return }
            let data = fileHandle.availableData
            guard !data.isEmpty else { return }
            
            DispatchQueue.main.async {
                self.feed(byteArray: ArraySlice<UInt8>(data))
            }
        }
        
        registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (self: Self, previousTraitCollection: UITraitCollection) in
            guard self.traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) else { return }
            
            if self.isFirstResponder {
                _ = self.resignFirstResponder()
                _ = self.becomeFirstResponder()
            }
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func willMove(toWindow newWindow: UIWindow?) {
        super.willMove(toWindow: newWindow)
        if(newWindow == nil) {
            NotificationCenter.default.removeObserver(self)
        } else {
            NotificationCenter.default.addObserver(self, selector: #selector(handleThemeChange(_:)), name: Notification.Name("uiColorChangeNotif"), object: nil)
        }
        handleThemeChange(nil)
    }
    
    @objc func handleThemeChange(_ notification: Notification?) {
        self.backgroundColor = LDETheme.currentTheme?.backgroundColor ?? .secondarySystemBackground
        self.nativeForegroundColor = LDETheme.currentTheme?.textColor ?? gibDynamicColor(light: .label, dark: self.nativeForegroundColor)
        self.caretTextColor = LDETheme.currentTheme?.textColor ?? gibDynamicColor(light: .label, dark: self.nativeForegroundColor)
    }
}
