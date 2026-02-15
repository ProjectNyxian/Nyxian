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
        
        if #unavailable(iOS 15.0) {
            self.navigationController?.navigationBar.standardAppearance = currentNavigationBarAppearance
            self.navigationController?.navigationBar.scrollEdgeAppearance = currentNavigationBarAppearance
        }
        
        super.viewDidLoad()
        
        self.tableView.separatorColor = currentTheme?.gutterHairlineColor
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
