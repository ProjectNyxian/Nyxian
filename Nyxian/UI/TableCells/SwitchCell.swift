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

class SwitchTableCell: UITableViewCell {
    var callback: (Bool) -> Void = { _ in }
    
    var toggle: UISwitch? = nil
    let key: String
    let defaultValue: Bool
    var value: Bool {
        get {
            if UserDefaults.standard.object(forKey: self.key) == nil {
                UserDefaults.standard.set(self.defaultValue, forKey: self.key)
            }
            
            return UserDefaults.standard.bool(forKey: self.key)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: self.key)
        }
    }
    
    init(title: String, key: String, defaultValue: Bool) {
        self.key = key
        self.defaultValue = defaultValue
        super.init(style: .default, reuseIdentifier: nil)
        
        selectionStyle = .none
        textLabel?.text = title
        
        let toggle = UISwitch()
        toggle.isOn = UserDefaults.standard.object(forKey: key) as? Bool ?? defaultValue
        toggle.addTarget(self, action: #selector(toggleChanged(_:)), for: .valueChanged)
        accessoryView = toggle
        self.toggle = toggle
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func applyTheme() {
        self.toggle?.onTintColor = currentTheme?.appLabel
        self.toggle?.thumbTintColor = currentTheme?.appTableCell
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        applyTheme()
    }
    
    override func traitCollectionDidChange(_ previous: UITraitCollection?) {
        super.traitCollectionDidChange(previous)
        applyTheme()
    }
    
    @objc private func toggleValueChanged(_ sender: UISwitch) {
        self.value = sender.isOn
        self.callback(self.value)
    }
    
    @objc private func toggleChanged(_ sender: UISwitch) {
        UserDefaults.standard.set(sender.isOn, forKey: key)
        callback(sender.isOn)
    }
}
