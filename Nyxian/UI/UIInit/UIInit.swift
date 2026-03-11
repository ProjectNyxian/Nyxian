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

import UIKit

var currentTheme: LDETheme?
var currentNavigationBarAppearance = UINavigationBarAppearance()
var currentTabBarAppearance = UITabBarAppearance()

func RevertUI() {
    currentTheme = LDEThemeReader.shared.currentlySelectedTheme()
    
    guard let currentTheme = currentTheme else { return }
    
    if #unavailable(iOS 26.0) {
        currentNavigationBarAppearance.backgroundColor = currentTheme.gutterBackgroundColor
        currentNavigationBarAppearance.titleTextAttributes = [NSAttributedString.Key.foregroundColor: currentTheme.textColor]
        currentNavigationBarAppearance.buttonAppearance.normal.titleTextAttributes = [NSAttributedString.Key.foregroundColor: currentTheme.textColor]
        currentNavigationBarAppearance.backButtonAppearance = UIBarButtonItemAppearance()
        currentNavigationBarAppearance.backButtonAppearance.normal.titleTextAttributes = [.foregroundColor : currentTheme.textColor]
        
        currentTabBarAppearance.configureWithOpaqueBackground()
        currentTabBarAppearance.backgroundColor = currentTheme.gutterBackgroundColor
    }
    
    UITableView.appearance().backgroundColor = currentTheme.appTableView
    UITableViewCell.appearance().backgroundColor = currentTheme.appTableCell
    
    UILabel.appearance(whenContainedInInstancesOf: [UITableViewCell.self]).textColor = currentTheme.appLabel
    UILabel.appearance(whenContainedInInstancesOf: [UIButton.self]).textColor = currentTheme.appLabel
    UIView.appearance().tintColor = currentTheme.appLabel
    
    NotificationCenter.default.post(name: Notification.Name("uiColorChangeNotif"), object: nil, userInfo: nil)
}
