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
import UIKit
import Runestone
import CoreCompiler

// MARK: - COORDINATOR
class Coordinator: NSObject, TextViewDelegate {
    private(set) weak var parent: CodeEditorViewController?
    private var entries: [CFIndex:(NeoButton?,UIView?)] = [:]
    
    private(set) var isProcessing: Bool = false
    private(set) var isInvalidated: Bool = false
    private(set) var needsAnotherProcess: Bool = false

    private(set) var debounce: LDEDebouncer?
    private(set) var diag: [CCKDiagnostic] = []
    private let vtkey: [CCDiagnosticLevel:(String,UIColor)] = [
        .note: ("info.circle.fill", UIColor.blue.withAlphaComponent(0.3)),
        .warning: ("exclamationmark.triangle.fill", UIColor.orange.withAlphaComponent(0.3)),
        .error: ("xmark.octagon.fill", UIColor.red.withAlphaComponent(0.3))
    ]
    
    init(parent: CodeEditorViewController) {
        self.parent = parent
        super.init()
        guard self.parent?.synpushServer != nil else { return }
        self.debounce = LDEDebouncer(delay: 1.5, with: DispatchQueue.main, withTarget: self, with: #selector(typecheckCode))
        if let textView = self.parent?.textView {
            self.textViewDidChange(textView)
        }
    }
    
    @objc func typecheckCode() {
        self.isProcessing = true
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            guard let parent = self.parent else { return }
            guard let server = parent.synpushServer else { return }
            
            parent.project?.projectConfig.reloadIfNeeded()
            let flags: [String] = parent.isReadOnly ? NXProjectConfig.sdkCompilerFlags() as! [String] : parent.project?.projectConfig.compilerFlags as! [String]
            
            server.reparseFile(self.parent?.textView.text, withArgs: flags)
            let diag = self.parent?.synpushServer?.getDiagnostics() ?? []
            
            DispatchQueue.main.async {
                self.diag = diag
                self.updateDiag()
            }
        }
    }
    
    func textViewDidChange(_ textView: TextView) {
        if(!textView.text.isEmpty) {
            self.parent?.document?.updateChangeCount(.done)
        }
        guard self.parent?.synpushServer != nil else { return }
        if !self.isInvalidated {
            self.isInvalidated = true
            for item in self.entries {
                UIView.animate(withDuration: 0.3) {
                    item.value.1?.backgroundColor = UIColor.systemGray.withAlphaComponent(0.3)
                    item.value.0?.backgroundColor = UIColor.systemGray.withAlphaComponent(1.0)
                    item.value.0?.isUserInteractionEnabled = false
                    item.value.0?.errorview?.alpha = 0.0
                } completion: { _ in
                    item.value.0?.errorview?.removeFromSuperview()
                }
            }
        }
        
        self.redrawDiag()
        
        if self.isProcessing {
            self.needsAnotherProcess = true
            return
        }
        
        self.debounce?.debounce()
    }
    
    var isAutoIndenting = false
    
    func textViewDidChangeSelection(_ textView: TextView) {
        if self.isInvalidated {
            self.debounce?.debounce()
        }
    }
    
    func redrawDiag() {
        guard let parent = self.parent else { return }
        
        if !self.entries.isEmpty {
            for item in self.entries {
                guard let rect = parent.textView.rectForLine(Int(item.key)) else {
                    UIView.animate(withDuration: 0.3, animations: {
                        item.value.0?.alpha = 0
                        item.value.1?.alpha = 0
                    }, completion: { _ in
                        item.value.0?.removeFromSuperview()
                        item.value.1?.removeFromSuperview()
                        self.entries.removeValue(forKey: item.key)
                    })
                    return
                }
                item.value.0?.frame = CGRect(x: 0, y: rect.origin.y, width: parent.textView.gutterWidth, height: rect.height)
                item.value.1?.frame = CGRect(x: 0, y: rect.origin.y, width: parent.textView.bounds.size.width, height: rect.height)
            }
        }
    }
    
    func updateDiag() {
        guard let parent = self.parent else { return }
        if !self.entries.isEmpty {
            UIView.animate(withDuration: 0.3, animations: {
                for item in self.entries {
                    item.value.0?.alpha = 0
                    item.value.1?.alpha = 0
                }
            }, completion: { _ in
                for item in self.entries {
                    item.value.0?.removeFromSuperview()
                    item.value.1?.removeFromSuperview()
                }
                self.entries.removeAll()
                self.updateDiag()
            })
            return
        }
        
        for item in diag {
            guard self.entries[item.fileSourceLocation.location.line] == nil else { continue }
            self.entries[item.fileSourceLocation.location.line] = (nil, nil)
            
            guard let rect = parent.textView.rectForLine(Int(item.fileSourceLocation.location.line)) else { continue }
            guard let properties: (String,UIColor) = self.vtkey[item.level] else { continue }
            
            let view: UIView = UIView(frame: CGRect(x: 0, y: rect.origin.y, width: 3000, height: rect.height))
            view.backgroundColor = properties.1
            view.isUserInteractionEnabled = false
            
            let button = NeoButton(frame: CGRect(x: 0, y: rect.origin.y, width: parent.textView.gutterWidth, height: rect.height))
            button.backgroundColor = properties.1.withAlphaComponent(1.0)
            let configuration: UIImage.SymbolConfiguration = UIImage.SymbolConfiguration(pointSize: parent.textView.theme.lineNumberFont.pointSize)
            let image = UIImage(systemName: properties.0, withConfiguration: configuration)
            button.setImage(image, for: .normal)
            button.imageView?.tintColor = UIColor.label
            
            var widthConstraint: NSLayoutConstraint?
            
            button.setAction { [weak self, weak button, weak parent] in
                guard let self = self, let button = button, let parent = parent else { return }
                button.stateview = !button.stateview
                
                if button.stateview {
                    let shift: CGFloat = parent.textView.gutterWidth
                    let finalWidth = (parent.textView.bounds.width) / 1.5
                    let modHeight = rect.height + 10
                    
                    let preview = ErrorPreview(
                        parent: self,
                        frame: CGRect.zero,
                        message: item.message,
                        color: properties.1,
                        minH: modHeight
                    )
                    preview.translatesAutoresizingMaskIntoConstraints = false
                    button.errorview = preview
                    preview.alpha = 0
                    
                    if let textView = self.parent?.textView {
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
            
            view.alpha = 0
            button.alpha = 0
            self.entries[item.fileSourceLocation.location.line] = (button, view)
            
            if let textInputView = parent.textView.getTextInputView() {
                textInputView.addSubview(view)
                textInputView.sendSubviewToBack(view)
                textInputView.gutterContainerView.isUserInteractionEnabled = true
                textInputView.gutterContainerView.addSubview(button)
            }
            
            UIView.animate(withDuration: 0.3, animations: {
                view.alpha = 1
                button.alpha = 1
            }, completion: { _ in
                button.isUserInteractionEnabled = true
            })
        }
        
        self.isProcessing = false
        self.isInvalidated = false
        
        if self.needsAnotherProcess, let textView = self.parent?.textView {
            self.needsAnotherProcess = false
            self.textViewDidChange(textView)
        }
    }
    
    class ErrorPreview: UIView {
        var textView: UITextView
        var heigth: CGFloat = 0.0

        init(parent: Coordinator, frame: CGRect, message: String, color: UIColor, minH: CGFloat) {
            textView = UITextView()
            super.init(frame: .zero)

            self.backgroundColor = parent.parent?.textView.theme.gutterBackgroundColor
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
            textView.font = parent.parent?.textView.theme.font
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
        var actionTap: () -> Void
        var stateview: Bool = false
        var errorview: ErrorPreview? = nil
        
        let hitTestEdgeInsets = UIEdgeInsets(top: -10, left: -10, bottom: -10, right: -10)
        
        override init(frame: CGRect) {
            self.actionTap = {}
            super.init(frame: frame)
            self.addAction(UIAction { [weak self] _ in
                guard let self = self else { return }
                self.actionTap()
            }, for: UIControl.Event.touchDown)
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
}
