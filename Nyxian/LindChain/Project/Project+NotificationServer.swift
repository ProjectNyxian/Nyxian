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

import Foundation
import UIKit

func getTopViewController(base: UIViewController? = UIApplication.shared.connectedScenes
    .compactMap { $0 as? UIWindowScene }
    .flatMap { $0.windows }
    .first(where: { $0.isKeyWindow })?.rootViewController) -> UIViewController? {
    
    if let nav = base as? UINavigationController {
        return getTopViewController(base: nav.visibleViewController)
    }
    
    if let tab = base as? UITabBarController {
        return getTopViewController(base: tab.selectedViewController)
    }
    
    if let presented = base?.presentedViewController {
        return getTopViewController(base: presented)
    }
    
    return base
}

@objc class NotificationServer: NSObject {
    @objc enum NotifLevel: Int {
        case note = 0
        case warning = 1
        case error = 2
    }
    
    static func getTitleForNotif(level: NotifLevel) -> String {
        switch level {
        case .note: return "Note"
        case .warning: return "Warning"
        case .error: return "Error"
        }
    }
    
    @objc static func NotifyUser(
        level: NotifLevel,
        notification: String,
        delay: Double = 0.0
    ) {
        DispatchQueue.global().asyncAfter(deadline: .now() + delay) {
            DispatchQueue.main.async {
                if let rootVC = getTopViewController() {
                    let alert: UIAlertController = UIAlertController(
                        title: getTitleForNotif(level: level),
                        message: notification,
                        preferredStyle: .alert
                    )
                    
                    alert.addAction(UIAlertAction(title: "Close", style: .cancel))
                    
                    rootVC.present(alert, animated: true)
                }
            }
        }
    }
}
