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

@objc class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        window = LDEWindowServer.shared()
        
        let tabViewController: UIThemedTabBarController = UIThemedTabBarController()
        
        let contentViewController: ContentViewController = ContentViewController(path: "\(NSHomeDirectory())/Documents/Projects")
        let settingsViewController: SettingsViewController = SettingsViewController(style: .insetGrouped)
        
        let projectsNavigationController: UINavigationController = UINavigationController(rootViewController: contentViewController)
        let settingsNavigationController: UINavigationController = UINavigationController(rootViewController: settingsViewController)
        
        projectsNavigationController.tabBarItem = UITabBarItem(title: "Projects", image: UIImage(systemName: "square.grid.2x2.fill"), tag: 0)
        settingsNavigationController.tabBarItem = UITabBarItem(title: "Settings", image: UIImage(systemName: "gear"), tag: 1)
        
        tabViewController.viewControllers = [projectsNavigationController, settingsNavigationController]
        
        window?.rootViewController = tabViewController
        window?.makeKeyAndVisible()

        return true
    }
}

@objc extension UIWindow {
    open override func isKind(of aClass: AnyClass) -> Bool {
        // Fix physical keyboard focus on iOS 17+
        aClass == _UIRootWindow.self || super.isKind(of: aClass)
    }
}
