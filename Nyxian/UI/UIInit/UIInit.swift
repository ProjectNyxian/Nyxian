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

var currentNavigationBarAppearance = UINavigationBarAppearance()
var currentTabBarAppearance = UITabBarAppearance()

func RevertUI() {
    LDETheme.currentTheme = LDEThemeReader.shared.currentlySelectedTheme()
    
    guard let currentTheme = LDETheme.currentTheme else { return }
    
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
    
    UILabel.appearance(whenContainedInInstancesOf: [UITableViewCell.self]).textColor = currentTheme.textColor
    UILabel.appearance(whenContainedInInstancesOf: [UIButton.self]).textColor = currentTheme.textColor
    UIView.appearance().tintColor = currentTheme.appLabel
    
    NotificationCenter.default.post(name: Notification.Name("uiColorChangeNotif"), object: nil, userInfo: nil)
}
