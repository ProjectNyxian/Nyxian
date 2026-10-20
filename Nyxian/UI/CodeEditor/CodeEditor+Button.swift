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

import UIKit
import AudioToolbox

class SymbolButton: UIButton {
    private var actionHandler: (() -> Void)?
    private var longActionHandler: (() -> Void)?
    private var currentAnimator: UIViewPropertyAnimator?
    
    init(symbolName: String, width: CGFloat, actionHandler: @escaping () -> Void, longActionHandler: (() -> Void)? = nil) {
        self.actionHandler = actionHandler
        super.init(frame: .zero)
        
        let image = UIImage(systemName: symbolName)
        if image != nil {
            self.setImage(image, for: .normal)
        } else {
            self.setTitle(symbolName, for: .normal)
            self.titleLabel?.font = UIFont.systemFont(ofSize: 16)
            self.setTitleColor(.label, for: .normal)
        }
        
        let theme: LDETheme = LDEThemeReader.shared.currentlySelectedTheme()
        
        self.addTarget(self, action: #selector(didTapButton), for: .touchUpInside)
        
        if let longActionHandler = longActionHandler {
            let longPress = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress(_:)))
            longPress.minimumPressDuration = 0.5
            self.addGestureRecognizer(longPress)
            self.longActionHandler = longActionHandler
        }
        
        self.tintColor = theme.textColor //.label
        self.setTitleColor(theme.textColor, for: .normal)
        
        if #unavailable(iOS 26.0) {
            self.addTarget(self, action: #selector(touchDown), for: .touchDown)
            self.addTarget(self, action: #selector(touchUp), for: [.touchUpInside, .touchDragExit, .touchCancel])
            
            self.layer.cornerRadius = 5
            self.layer.borderWidth = 1
            self.layer.borderColor = theme.gutterHairlineColor.cgColor
            self.backgroundColor = theme.gutterBackgroundColor
        }
        
        NSLayoutConstraint.activate([
            self.widthAnchor.constraint(equalToConstant: width),
            self.heightAnchor.constraint(equalToConstant: 35)
        ])
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    @objc private func didTapButton() {
        actionHandler?()
        AudioServicesPlaySystemSound(1104)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
    
    @objc func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
        if gesture.state == .began {
            longActionHandler?()
            AudioServicesPlaySystemSound(1104)
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }
    }
    
    @objc private func touchDown() {
        currentAnimator?.stopAnimation(true)
        currentAnimator = UIViewPropertyAnimator(duration: 0.1, curve: .easeInOut) {
            self.transform = CGAffineTransform(scaleX: 0.9, y: 0.9)
        }
        currentAnimator?.startAnimation()
    }
    
    @objc private func touchUp() {
        currentAnimator?.stopAnimation(true)
        currentAnimator = UIViewPropertyAnimator(duration: 0.1, curve: .easeInOut) {
            self.transform = CGAffineTransform.identity
        }
        currentAnimator?.startAnimation()
    }
    
    override func willMove(toWindow newWindow: UIWindow?) {
        if newWindow == nil {
            self.gestureRecognizers?.forEach { gesture in
                self.removeGestureRecognizer(gesture)
            }
        }
    }
}
