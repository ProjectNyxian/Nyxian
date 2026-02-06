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
