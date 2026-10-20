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
import ObjectiveC.runtime

extension UIViewController {
    func presentConfirmationAlert(
        title: String,
        message: String,
        confirmTitle: String = "Confirm",
        confirmStyle: UIAlertAction.Style = .default,
        confirmHandler: @escaping () -> Void,
        addHandler: Bool = true
    ) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        if addHandler {
            alert.addAction(UIAlertAction(title: confirmTitle, style: confirmStyle) { _ in
                confirmHandler()
            })
        }
        
        self.present(alert, animated: true)
    }
}

extension UIBarButtonItem {
    static let swizzleBarButtonitem: Void = {
        let originalSel  = Selector(("init"))
        let swizzledSel  = #selector(UIBarButtonItem.themed_init)

        guard
            let original  = class_getInstanceMethod(UIBarButtonItem.self, originalSel),
            let swizzled  = class_getInstanceMethod(UIBarButtonItem.self, swizzledSel)
        else { return }

        method_exchangeImplementations(original, swizzled)
    }()

    @objc func themed_init() -> UIBarButtonItem {
        let item = self.themed_init()

        if #available(iOS 26.0, *) {
            item.tintColor = LDETheme.currentTheme?.textColor
            // FIXME: notif changes dont work as exptected
        }
        return item
    }
}

extension UIViewController {
    static let swizzlePresentAndDismissOnce: Void = {
        swizzle(UIViewController.self, original: #selector(UIViewController.present(_:animated:completion:)), swizzled: #selector(UIViewController.swizzled_present(_:animated:completion:)))
    }()
    
    private static func swizzle(_ cls: AnyClass, original: Selector, swizzled: Selector) {
        guard let originalMethod = class_getInstanceMethod(cls, original),
              let swizzledMethod = class_getInstanceMethod(cls, swizzled) else { return }
        
        let didAdd = class_addMethod(cls, original, method_getImplementation(swizzledMethod), method_getTypeEncoding(swizzledMethod))
        
        if didAdd {
            class_replaceMethod(cls, swizzled, method_getImplementation(originalMethod), method_getTypeEncoding(originalMethod))
        } else {
            method_exchangeImplementations(originalMethod, swizzledMethod)
        }
    }
    
    @objc func swizzled_present(_ viewControllerToPresent: UIViewController, animated: Bool, completion: (() -> Void)? = nil) {
        let isSheet = viewControllerToPresent.modalPresentationStyle == .formSheet ||
                      viewControllerToPresent.modalPresentationStyle == .pageSheet
        
        if isSheet {
            NXWindowServer.shared().unfocusFocusedWindow()
        }
        
        swizzled_present(viewControllerToPresent, animated: animated, completion: completion)
    }
}
