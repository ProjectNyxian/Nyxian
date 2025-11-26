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

@objc class UIThemedTableViewController: UITableViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        self.view.backgroundColor = currentTheme?.gutterBackgroundColor
        NotificationCenter.default.addObserver(self, selector: #selector(handleMyNotification(_:)), name: Notification.Name("uiColorChangeNotif"), object: nil)
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        NotificationCenter.default.removeObserver(self)
    }
    
    @objc func handleMyNotification(_ notification: Notification) {
        self.view.backgroundColor = currentTheme?.gutterBackgroundColor
        self.tableView.backgroundColor = currentTheme?.gutterBackgroundColor
        
        for cell in tableView.visibleCells {
            cell.backgroundColor = currentTheme?.backgroundColor
        }
    }
}

@objc class UIThemedTabBarController: UITabBarController, UITabBarControllerDelegate {
    override func viewDidLoad() {
        super.viewDidLoad()
        self.delegate = self
        
        NotificationCenter.default.addObserver(self, selector: #selector(handleMyNotification(_:)), name: Notification.Name("uiColorChangeNotif"), object: nil)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        self.view.backgroundColor = currentTheme?.gutterBackgroundColor
        super.viewDidAppear(animated)
    }
    
    @objc func handleMyNotification(_ notification: Notification) {
        
        let blurEffect = UIBlurEffect(style: .systemMaterial)
        
        if let viewControllers = self.viewControllers {
            for case let nav as UINavigationController in viewControllers {
                nav.navigationBar.standardAppearance = currentNavigationBarAppearance
                nav.navigationBar.scrollEdgeAppearance = currentNavigationBarAppearance
                nav.navigationBar.scrollEdgeAppearance?.backgroundEffect = blurEffect
            }
        }
        
        if #unavailable(iOS 26.0) {
            if #available(iOS 15.0, *) {
                let appearance = UITabBarAppearance()
                appearance.configureWithOpaqueBackground()
                appearance.backgroundColor = currentTheme?.gutterBackgroundColor
                self.tabBar.standardAppearance = appearance
                self.tabBar.scrollEdgeAppearance = appearance
                UITabBar.appearance().scrollEdgeAppearance = appearance
                UITabBar.appearance().scrollEdgeAppearance?.backgroundEffect = blurEffect
            }
        }
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
