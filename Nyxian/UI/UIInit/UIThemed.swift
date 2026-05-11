/*
 SPDX-License-Identifier: AGPL-3.0-or-later

 Copyright (C) 2025 - 2026 mach-port-t

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

import UIKit

@objc class UIThemedTableViewController: UITableViewController {
    
    override func viewDidLoad() {
        if #unavailable(iOS 15.0) {
            self.navigationController?.navigationBar.standardAppearance = currentNavigationBarAppearance
            self.navigationController?.navigationBar.scrollEdgeAppearance = currentNavigationBarAppearance
        }
        
        super.viewDidLoad()
        self.view.backgroundColor = currentTheme?.appTableView
        self.tableView.separatorColor = currentTheme?.gutterHairlineColor
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.view.backgroundColor = currentTheme?.appTableView
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        self.view.backgroundColor = currentTheme?.appTableView
        
        if #unavailable(iOS 15.0) {
            self.navigationController?.navigationBar.standardAppearance = currentNavigationBarAppearance
            self.navigationController?.navigationBar.scrollEdgeAppearance = currentNavigationBarAppearance
        }
        
        self.tableView.separatorColor = currentTheme?.gutterHairlineColor
        
        NotificationCenter.default.addObserver(self, selector: #selector(handleMyNotification(_:)), name: Notification.Name("uiColorChangeNotif"), object: nil)
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        NotificationCenter.default.removeObserver(self)
    }
    
    @objc func handleMyNotification(_ notification: Notification) {
        self.view.backgroundColor = currentTheme?.appTableView
        self.tableView.backgroundColor = currentTheme?.appTableView
        
        if #unavailable(iOS 15.0) {
            self.navigationController?.navigationBar.standardAppearance = currentNavigationBarAppearance
            self.navigationController?.navigationBar.scrollEdgeAppearance = currentNavigationBarAppearance
        }
        
        self.tableView.separatorColor = currentTheme?.gutterHairlineColor
        
        for cell in tableView.visibleCells {
            cell.backgroundColor = currentTheme?.appTableCell
        }
    }
}

@objc class UIThemedViewController: UIViewController {
    
    override func viewDidLoad() {
        if #unavailable(iOS 15.0) {
            self.navigationController?.navigationBar.standardAppearance = currentNavigationBarAppearance
            self.navigationController?.navigationBar.scrollEdgeAppearance = currentNavigationBarAppearance
        }
        
        super.viewDidLoad()
        self.view.backgroundColor = currentTheme?.appTableView
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.view.backgroundColor = currentTheme?.appTableView
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        self.view.backgroundColor = currentTheme?.appTableView
        
        if #unavailable(iOS 15.0) {
            self.navigationController?.navigationBar.standardAppearance = currentNavigationBarAppearance
            self.navigationController?.navigationBar.scrollEdgeAppearance = currentNavigationBarAppearance
        }
        
        NotificationCenter.default.addObserver(self, selector: #selector(handleMyNotification(_:)), name: Notification.Name("uiColorChangeNotif"), object: nil)
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        NotificationCenter.default.removeObserver(self)
    }
    
    @objc func handleMyNotification(_ notification: Notification) {
        self.view.backgroundColor = currentTheme?.appTableView
        
        if #unavailable(iOS 15.0) {
            self.navigationController?.navigationBar.standardAppearance = currentNavigationBarAppearance
            self.navigationController?.navigationBar.scrollEdgeAppearance = currentNavigationBarAppearance
        }
    }
}

@objc class UIThemedTabViewController: UITabBarController {
    override func viewDidLoad() {
        
        if #unavailable(iOS 15.0) {
            self.tabBar.standardAppearance = currentTabBarAppearance
            self.tabBar.barTintColor = currentTheme?.gutterBackgroundColor
            self.tabBar.unselectedItemTintColor = currentTheme?.textColor
            self.tabBar.isTranslucent = false
        }
        
        super.viewDidLoad()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        self.view.backgroundColor = currentTheme?.appTableView
        
        if #unavailable(iOS 15.0) {
            self.tabBar.standardAppearance = currentTabBarAppearance
            self.tabBar.barTintColor = currentTheme?.gutterBackgroundColor
            self.tabBar.unselectedItemTintColor = currentTheme?.textColor
            self.tabBar.isTranslucent = false
        }
        
        NotificationCenter.default.addObserver(self, selector: #selector(handleMyNotification(_:)), name: Notification.Name("uiColorChangeNotif"), object: nil)
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        NotificationCenter.default.removeObserver(self)
    }
    
    @objc func handleMyNotification(_ notification: Notification) {
        self.view.backgroundColor = currentTheme?.appTableView
        
        if #unavailable(iOS 15.0) {
            self.tabBar.standardAppearance = currentTabBarAppearance
            self.tabBar.barTintColor = currentTheme?.gutterBackgroundColor
            self.tabBar.unselectedItemTintColor = currentTheme?.textColor
            self.tabBar.isTranslucent = false
        }
    }
}

class UIThemedSwitch: UISwitch {
    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }
    
    private func setup() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleThemeChange),
            name: Notification.Name("uiColorChangeNotif"),
            object: nil
        )
        applyTheme()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        applyTheme()
    }
    
    private func applyTheme() {
        onTintColor = currentTheme?.appLabel
        thumbTintColor = currentTheme?.appTableCell
    }
    
    override func traitCollectionDidChange(_ previous: UITraitCollection?) {
        super.traitCollectionDidChange(previous)
        applyTheme()
    }
    
    @objc private func handleThemeChange() {
        applyTheme()
    }
}

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
            item.tintColor = currentTheme?.textColor
            // FIXME: notif changes dont work as exptected
        }
        return item
    }
}

extension UIViewController {
    static let swizzlePresentAndDismissOnce: Void = {
        swizzle(UIViewController.self, original: #selector(UIViewController.present(_:animated:completion:)), swizzled: #selector(UIViewController.swizzled_present(_:animated:completion:)))
        swizzle(UIViewController.self, original: #selector(UIViewController.dismiss(animated:completion:)), swizzled: #selector(UIViewController.swizzled_dismiss(animated:completion:)))
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
        let isPicker = String(describing: type(of: viewControllerToPresent)).lowercased().contains("picker")
        
        if viewControllerToPresent is UIThemedViewController ||
           viewControllerToPresent is UIThemedTableViewController ||
           viewControllerToPresent is UINavigationController ||
           isPicker {
            NXWindowServer.shared().unfocusFocusedWindow()
            NXWindowServer.shared().windowsGetOutOfMyWay()
        }
        
        swizzled_present(viewControllerToPresent, animated: animated, completion: completion)
    }
    
    @objc func swizzled_dismiss(animated: Bool, completion: (() -> Void)? = nil) {
        let dismissedVC = self.presentedViewController ?? self
        let isPicker = String(describing: type(of: dismissedVC)).lowercased().contains("picker")
        
        let shouldRestore = (dismissedVC is UIThemedViewController ||
                             dismissedVC is UIThemedTableViewController ||
                             dismissedVC is UINavigationController ||
                             isPicker) &&
                            self.presentingViewController != nil
        
        if shouldRestore {
            swizzled_dismiss(animated: animated, completion: {
                NXWindowServer.shared().windowsGetInMyWay()
                completion?()
            })
        } else {
            swizzled_dismiss(animated: animated, completion: completion)
        }
    }
}
