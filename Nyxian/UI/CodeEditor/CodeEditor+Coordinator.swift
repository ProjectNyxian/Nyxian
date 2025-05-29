/*
 Copyright (C) 2025 SeanIsTethered

 This file is part of Nyxian.

 FridaCodeManager is free software: you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.

 FridaCodeManager is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 GNU General Public License for more details.

 You should have received a copy of the GNU General Public License
 along with FridaCodeManager. If not, see <https://www.gnu.org/licenses/>.
*/

import Foundation
import UIKit
import Runestone
//gas/@testable import Runestone

// MARK: - COORDINATOR
class Coordinator: NSObject, TextViewDelegate {
    private let parent: CodeEditorViewController
    private var message: [UIView] = []
    private var line: [UInt64] = []
    
    private var iDoStuff: Bool = false
    private var iDidInvalid: Bool = false
    private var needsAnotherRun: Bool = false

    private let debounce: Debouncer
    
    init(parent: CodeEditorViewController) {
        self.parent = parent
        self.debounce = Debouncer(delay: 1.5)
        super.init()
        guard self.parent.synpushServer != nil else { return }
        self.textViewDidChange(self.parent.textView)
        
        ctrl1Pressed = {
            guard let textRange = parent.textView.selectedTextRange else { return }
            let cursorPosition = parent.textView.offset(from: parent.textView.beginningOfDocument, to: textRange.start)
            let textUpToCursor = (parent.textView.text as NSString).substring(to: cursorPosition)
            let lineNumber = textUpToCursor.components(separatedBy: .newlines).count
            
            let copymessage = self.message
            
            for item in copymessage {
                if let button = item as? NeoButton {
                    if button.isOnLine == lineNumber {
                        button.actionTap()
                    }
                }
            }
        }
    }
    
    func textViewDidChange(_ textView: TextView) {
        guard self.parent.synpushServer != nil else { return }
        if !self.iDidInvalid {
            self.iDidInvalid = true
            let copymessage = self.message
            
            for item in copymessage {
                if let button = item as? NeoButton {
                    UIView.animate(withDuration: 0.3) {
                        button.backgroundColor = UIColor.systemGray.withAlphaComponent(1.0)
                        button.isUserInteractionEnabled = false
                        button.errorview?.alpha = 0.0
                    } completion: { _ in
                        button.errorview?.removeFromSuperview()
                    }
                    continue
                }
                UIView.animate(withDuration: 0.3) {
                    item.backgroundColor = UIColor.systemGray.withAlphaComponent(0.3)
                }
            }
        }
        
        if self.iDoStuff {
            self.needsAnotherRun = true
            return
        }
        
        self.debounce.debounce {
            self.iDoStuff = true
            
            DispatchQueue.global(qos: .userInitiated).async {
                self.parent.synpushServer!.reparseFile(textView.text)
                let diag = self.parent.synpushServer!.getDiagnostics()
                
                let textView = self.parent.textView
                
                let waitonmebaby: DispatchSemaphore = DispatchSemaphore(value: 0)
                
                DispatchQueue.main.async {
                    UIView.animate(withDuration: 0.3, animations: {
                        for item in self.message {
                            item.alpha = 0
                        }
                    }, completion: { _ in
                        for item in self.message {
                            item.removeFromSuperview()
                        }
                        self.message.removeAll()
                        self.line.removeAll()
                        waitonmebaby.signal()
                    })
                }
                
                waitonmebaby.wait()
                
                if let diag = diag {
                    for item in diag {
                        if item.line == 0 { continue }
                        if self.line.contains(item.line) { continue }
                        
                        var rect: CGRect?
                        
                        DispatchQueue.main.sync {
                            rect = textView.rectForLine(Int(item.line))
                        }
                        
                        self.line.append(item.line)
                        
                        let highlightColor: UIColor
                        let sfname: String
                        
                        switch (item.type) {
                        case 0:
                            highlightColor = UIColor.blue.withAlphaComponent(0.3)
                            sfname = "info.circle.fill"
                        case 1:
                            highlightColor = UIColor.orange.withAlphaComponent(0.3)
                            sfname = "exclamationmark.triangle.fill"
                        case 2:
                            highlightColor = UIColor.red.withAlphaComponent(0.3)
                            sfname = "xmark.seal.fill"
                        default:
                            highlightColor = UIColor.clear
                            sfname = ""
                        }
                        
                        if let rect = rect {
                            DispatchQueue.main.async {
                                let view: UIView = UIView(frame: CGRect(x: 0, y: rect.origin.y, width: textView.bounds.size.width, height: rect.height))
                                view.backgroundColor = highlightColor
                                view.isUserInteractionEnabled = false
                                
                                let button = NeoButton(frame: CGRect(x: 0, y: rect.origin.y, width: self.parent.textView.gutterWidth/* - self.parent.textView.theme.gutterHairlineWidth*/, height: rect.height))
                                button.isOnLine = item.line
                                
                                button.backgroundColor = highlightColor.withAlphaComponent(1.0)
                                let image = self.resizeImage(image: UIImage(systemName: sfname)!, targetSize: CGSize(width: self.parent.textView.theme.font.pointSize, height: self.parent.textView.theme.font.pointSize), tintColor: self.parent.textView.theme.gutterBackgroundColor /*UIColor.systemBackground*/)
                                button.setImage(image, for: .normal)
                                
                                var widthConstraint: NSLayoutConstraint?
                                
                                button.setAction {
                                    button.stateview = !button.stateview
                                    
                                    if button.stateview {
                                        DispatchQueue.main.async {
                                            let shift: CGFloat = self.parent.textView.gutterWidth
                                            let finalWidth = textView.bounds.width / 1.5

                                            let modHeight = rect.height + 10
                                            
                                            let preview = ErrorPreview(
                                                parent: self,
                                                frame: CGRect.zero,
                                                message: item.message,
                                                color: highlightColor,
                                                minH: modHeight
                                            )
                                            preview.translatesAutoresizingMaskIntoConstraints = false
                                            button.errorview = preview

                                            preview.alpha = 0
                                            textView.addSubview(preview)
                                            
                                            widthConstraint = preview.widthAnchor.constraint(equalToConstant: 0)
                                            NSLayoutConstraint.activate([
                                                preview.leadingAnchor.constraint(equalTo: textView.leadingAnchor, constant: shift),
                                                preview.topAnchor.constraint(equalTo: textView.topAnchor, constant: rect.origin.y),
                                                widthConstraint!
                                            ])

                                            textView.layoutIfNeeded()
                                            
                                            UIView.animate(
                                                withDuration: 0.5,
                                                delay: 0,
                                                usingSpringWithDamping: 0.8,
                                                initialSpringVelocity: 0.5,
                                                options: [.curveEaseOut],
                                                animations: {
                                                    preview.alpha = 1
                                                    widthConstraint!.constant = finalWidth
                                                    textView.layoutIfNeeded()
                                                },
                                                completion: nil
                                            )
                                        }
                                    } else {
                                        if let preview = button.errorview {
                                            DispatchQueue.main.async {
                                                UIView.animate(
                                                    withDuration: 0.3,
                                                    delay: 0,
                                                    options: [.curveEaseIn],
                                                    animations: {
                                                        preview.alpha = 0
                                                        widthConstraint!.constant = 0
                                                        preview.superview?.layoutIfNeeded()
                                                    },
                                                    completion: { _ in
                                                        preview.removeFromSuperview()
                                                    }
                                                )
                                            }
                                        }
                                    }
                                }
                                
                                view.alpha = 0
                                button.alpha = 0
                                self.message.append(view)
                                self.message.append(button)
                                
                                let textInputView = textView.getTextInputView()
                                textInputView?.addSubview(view)
                                textInputView?.sendSubviewToBack(view)
                                textInputView?.gutterContainerView.isUserInteractionEnabled = true
                                textInputView?.gutterContainerView.addSubview(button)
                                
                                UIView.animate(withDuration: 0.3, animations: {
                                    view.alpha = 1
                                    button.alpha = 1
                                }, completion: { _ in
                                    button.isUserInteractionEnabled = true
                                })
                                
                            }
                        }
                    }
                }
                
                DispatchQueue.main.async {
                    self.iDoStuff = false
                    self.iDidInvalid = false
                    
                    if self.needsAnotherRun {
                        self.needsAnotherRun = false
                        self.textViewDidChange(self.parent.textView)
                    } else {
                        if let diag = diag {
                            var color: UIColor
                            
                            color = gibDynamicColor(light: .systemGray5, dark: .systemGray6)
                            
                            var severity: Int = -1
                            for item in diag {
                                switch item.type {
                                case 0:
                                    if severity < 0 {
                                        color = .blue.withAlphaComponent(0.8)
                                        severity = 0
                                    }
                                    break
                                case 1:
                                    if severity < 1 {
                                        color = .orange.withAlphaComponent(0.8)
                                        severity = 1
                                    }
                                    break
                                case 2:
                                    if severity < 2 {
                                        color = .red.withAlphaComponent(0.8)
                                        severity = 2
                                    }
                                    break
                                default:
                                    break
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    
    func resizeImage(image: UIImage, targetSize: CGSize, tintColor: UIColor) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: targetSize)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: targetSize))
            tintColor.setFill()
            UIRectFillUsingBlendMode(CGRect(origin: .zero, size: targetSize), .sourceAtop)
        }
    }
    
    class ErrorPreview: UIView {
        var textView: UITextView
        var heigth: CGFloat = 0.0

        init(parent: Coordinator, frame: CGRect, message: String, color: UIColor, minH: CGFloat) {
            textView = UITextView()
            super.init(frame: .zero)

            self.backgroundColor = parent.parent.textView.theme.gutterBackgroundColor
            self.layer.borderColor = color.withAlphaComponent(1.0).cgColor
            self.layer.borderWidth = 1
            self.layer.cornerRadius = 10
            self.layer.maskedCorners = [
                .layerMaxXMinYCorner,
                .layerMaxXMaxYCorner,
                .layerMinXMaxYCorner
            ]

            textView.translatesAutoresizingMaskIntoConstraints = false
            textView.text = message
            textView.font = parent.parent.textView.theme.font
            textView.font = textView.font?.withSize((textView.font?.pointSize ?? 10) / 1.25)
            textView.textColor = UIColor.label
            textView.backgroundColor = .clear
            textView.isEditable = false
            textView.isScrollEnabled = false
            textView.textContainerInset = UIEdgeInsets(top: 1, left: 1, bottom: 1, right: 1)

            self.addSubview(textView)

            NSLayoutConstraint.activate([
                textView.leadingAnchor.constraint(equalTo: self.leadingAnchor, constant: 8),
                textView.trailingAnchor.constraint(equalTo: self.trailingAnchor, constant: -8),
                textView.topAnchor.constraint(equalTo: self.topAnchor, constant: 8),
                textView.bottomAnchor.constraint(equalTo: self.bottomAnchor, constant: -8),
                self.heightAnchor.constraint(greaterThanOrEqualToConstant: minH)
            ])
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
    }
    
    class NeoButton: UIButton {
        var isOnLine: UInt64 = 0
        var actionTap: () -> Void
        var stateview: Bool = false
        var errorview: ErrorPreview? = nil
        
        let hitTestEdgeInsets = UIEdgeInsets(top: -10, left: -10, bottom: -10, right: -10)
        
        override init(frame: CGRect) {
            self.actionTap = {}
            super.init(frame: frame)
            self.addAction(UIAction { _ in self.actionTap() }, for: UIControl.Event.touchDown)
        }
        
        override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
            let relativeFrame = self.bounds
            let hitFrame = relativeFrame.inset(by: hitTestEdgeInsets)
            return hitFrame.contains(point)
        }
        
        func setAction(action: @escaping () -> Void) {
            self.actionTap = action
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        override func willMove(toSuperview newSuperview: UIView?) {
            if newSuperview == nil {
                if self.stateview {
                    actionTap()
                }
            }
            super.willMove(toSuperview: newSuperview)
        }
    }
    
    class Debouncer {
        private var workItem: DispatchWorkItem?
        private let queue: DispatchQueue
        private let delay: TimeInterval

        init(delay: TimeInterval, queue: DispatchQueue = .main) {
            self.delay = delay
            self.queue = queue
        }

        func debounce(action: @escaping () -> Void) {
            workItem?.cancel()

            workItem = DispatchWorkItem(block: action)

            if let workItem = workItem {
                queue.asyncAfter(deadline: .now() + delay, execute: workItem)
            }
        }
    }
}

// MARK: - Test
var ctrlSPressed: (Int) -> Void = { _ in }
var ctrl1Pressed: () -> Void = {}
var ctrlPPressed: () -> Void = {}
extension Runestone.TextView {
    func rectForLine(_ lineNumber: Int) -> CGRect? {
        let mirror = Mirror(reflecting: self)
        guard let lmAny = mirror.descendant("textInputView", "layoutManager"),
              let layoutManager = lmAny as? LayoutManager
        else {
            return nil
        }
        
        let lmMirror = Mirror(reflecting: layoutManager)
        guard let lineManager = lmMirror.descendant("lineManager") as? LineManager
        else {
            return nil
        }
        
        let index = lineNumber - 1
        guard index >= 0,
              index < lineManager.lineCount
        else {
            return nil
        }
        
        let targetLine = lineManager.line(atRow: lineNumber - 1)
        let endOffset = targetLine.location + targetLine.data.length
        layoutManager.layoutLines(toLocation: endOffset)
        
        let line = lineManager.line(atRow: index)
        
        let minY = line.yPosition
        let height = line.data.lineHeight
        let inset = layoutManager.textContainerInset
        let width = layoutManager.scrollViewWidth
        
        return CGRect(x: 0,
                      y: inset.top + minY,
                      width: width,
                      height: height)
    }
    
    func getTextInputView() -> TextInputView? {
        let mirror = Mirror(reflecting: self)
        guard let tiview = mirror.descendant("textInputView"),
              let textInputView = tiview as? TextInputView
        else {
            return nil
        }
        
        return textInputView
    }
    
    open override var keyCommands: [UIKeyCommand]? {
        return [
            UIKeyCommand(
                title: "Save",
                action: #selector(handleCtrlS),
                input: "S",
                modifierFlags: [.control]
            ),
            UIKeyCommand(
                title: "Shortcut 1",
                action: #selector(handleCtrl1),
                input: "1",
                modifierFlags: [.control]
            ),
            UIKeyCommand(
                title: "Play",
                action: #selector(handleCtrlP),
                input: "P",
                modifierFlags: [.control]
            )
        ]
    }
    
    @objc private func handleCtrlS() {
        print("Ctrl + S detected — Save action triggered.")
        ctrlSPressed(0)
    }

    @objc private func handleCtrl1() {
        print("Ctrl + 1 detected — Shortcut 1 triggered.")
        ctrl1Pressed()
    }
    
    @objc private func handleCtrlP() {
        print("Ctrl + P detected — Shortcut 1 triggered.")
        ctrlPPressed()
    }
}
