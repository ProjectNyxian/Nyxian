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

class SceneDelegate: UIResponder, UIWindowSceneDelegate, UITabBarControllerDelegate {

    var window: UIWindow?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = (scene as? UIWindowScene) else { return }
        
        window = LDEWindowServer.shared(with: windowScene)
        
#if JAILBREAK_ENV
        // jailbroken check
        let ret = shell("whoami", 0, nil, nil)
        if(ret != 0) {
            // creating exception view, instead of silently crashing
            let label: UILabel = UILabel()
            label.text = "Either incorrectly entitled or not supported bootstrap\n\njbroot: \(IGottaNeedTheActualJBRootMate() ?? "Unknown")\ntest exec ret: \(ret)"
            label.frame = window?.bounds ?? UIScreen.main.bounds
            label.numberOfLines = 0
            label.textAlignment = .center
            window?.addSubview(label)
            window?.makeKeyAndVisible()
            window?.bringSubviewToFront(label)
            return
        }
#endif // JAILBREAK_ENV
        
        Bootstrap.shared.bootstrap()
        
        let tabViewController: UIThemedTabViewController = UIThemedTabViewController()
        
        let contentViewController: ContentViewController = ContentViewController(path: Bootstrap.shared.bootstrapPath("/Projects"))
        let settingsViewController: SettingsViewController = SettingsViewController(style: .insetGrouped)
        
        let projectsNavigationController: UINavigationController = UINavigationController(rootViewController: contentViewController)
        let settingsNavigationController: UINavigationController = UINavigationController(rootViewController: settingsViewController)
        
        projectsNavigationController.tabBarItem = UITabBarItem(title: "Projects", image: UIImage(systemName: "square.grid.2x2.fill"), tag: 0)
        settingsNavigationController.tabBarItem = UITabBarItem(title: "Settings", image: UIImage(systemName: "gear"), tag: 1)
        
        var viewControllers: [UIViewController] = [projectsNavigationController, settingsNavigationController]
        
        if UIDevice.current.userInterfaceIdiom == UIUserInterfaceIdiom.phone
        {
            if #available(iOS 26.0, *) {
                let fakeViewController: UIViewController = UIViewController()
                fakeViewController.tabBarItem = UITabBarItem(tabBarSystemItem: .search, tag: 2)
                fakeViewController.tabBarItem.title = "Switcher"
                fakeViewController.tabBarItem.image = UIImage(systemName: "iphone.app.switcher")
                viewControllers.append(fakeViewController)
            }
        }
        
        tabViewController.viewControllers = viewControllers
        tabViewController.delegate = self;
        
        window?.rootViewController = tabViewController
        window?.makeKeyAndVisible()
    }
    
    func tabBarController(_ tabBarController: UITabBarController,
                          shouldSelect viewController: UIViewController) -> Bool {
        if viewController.tabBarItem.tag == 2 {
            LDEWindowServer.shared().showAppSwitcherExternal()
            return false
        }
        return true
    }
    
    func sceneDidDisconnect(_ scene: UIScene) { }
    func sceneDidBecomeActive(_ scene: UIScene) { }
    func sceneWillResignActive(_ scene: UIScene) { }
    func sceneWillEnterForeground(_ scene: UIScene) { }
    func sceneDidEnterBackground(_ scene: UIScene) { }
}
