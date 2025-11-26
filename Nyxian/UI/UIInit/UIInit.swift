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

var currentTheme: LindDEThemer?
var currentNavigationBarAppearance = UINavigationBarAppearance()
var currentTabBarAppearance = UITabBarAppearance()

func RevertUI() {
    currentTheme = getCurrentSelectedTheme()
    
    guard let currentTheme = currentTheme else { return }
    
    if #unavailable(iOS 26.0) {
        currentNavigationBarAppearance.backgroundColor = currentTheme.gutterBackgroundColor
        currentNavigationBarAppearance.titleTextAttributes = [NSAttributedString.Key.foregroundColor: currentTheme.textColor]
        currentNavigationBarAppearance.buttonAppearance.normal.titleTextAttributes = [NSAttributedString.Key.foregroundColor: currentTheme.textColor]
        currentNavigationBarAppearance.backButtonAppearance = UIBarButtonItemAppearance()
        currentNavigationBarAppearance.backButtonAppearance.normal.titleTextAttributes = [.foregroundColor : currentTheme.textColor]
        
        UINavigationBar.appearance().compactAppearance = currentNavigationBarAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = currentNavigationBarAppearance
        
        if #available(iOS 15.0, *) {
            currentTabBarAppearance.configureWithOpaqueBackground()
            currentTabBarAppearance.backgroundColor = currentTheme.gutterBackgroundColor
            UITabBar.appearance().standardAppearance = currentTabBarAppearance
            UITabBar.appearance().scrollEdgeAppearance = currentTabBarAppearance
        }
    }
    
    UITableView.appearance().backgroundColor = currentTheme.gutterBackgroundColor
    UITableViewCell.appearance().backgroundColor = currentTheme.backgroundColor
    
    UILabel.appearance().textColor = currentTheme.textColor
    UIView.appearance().tintColor = currentTheme.textColor
    
    NotificationCenter.default.post(name: Notification.Name("uiColorChangeNotif"), object: nil, userInfo: nil)
}
