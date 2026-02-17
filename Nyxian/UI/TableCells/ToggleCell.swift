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

class ToggleTableCell: UITableViewCell {
    static let reuseIdentifier = "ToggleTableCell"
    
    var callback: (Bool) -> Void = { _ in }
    
    private(set) var toggle: UISwitch = {
        let toggle = UISwitch()
        return toggle
    }()
    
    private var key: String = ""
    private var defaultValue: Bool = false
    
    var value: Bool {
        get {
            if UserDefaults.standard.object(forKey: key) == nil {
                UserDefaults.standard.set(defaultValue, forKey: key)
            }
            return UserDefaults.standard.bool(forKey: key)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: key)
        }
    }
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        selectionStyle = .none
        toggle.addTarget(self, action: #selector(toggleChanged(_:)), for: .valueChanged)
        accessoryView = toggle
        
        NotificationCenter.default.addObserver(self, selector: #selector(handleThemeChange), name: Notification.Name("uiColorChangeNotif"), object: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    func configure(title: String, key: String, defaultValue: Bool, callback: @escaping (Bool) -> Void = { _ in }) {
        self.key = key
        self.defaultValue = defaultValue
        self.callback = callback
        textLabel?.text = title
        toggle.isOn = UserDefaults.standard.object(forKey: key) as? Bool ?? defaultValue
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        key = ""
        defaultValue = false
        callback = { _ in }
        textLabel?.text = nil
        toggle.isOn = false
    }
    
    private func applyTheme() {
        toggle.onTintColor = currentTheme?.appLabel
        toggle.thumbTintColor = currentTheme?.appTableCell
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        applyTheme()
    }
    
    override func traitCollectionDidChange(_ previous: UITraitCollection?) {
        super.traitCollectionDidChange(previous)
        applyTheme()
    }
    
    @objc private func toggleChanged(_ sender: UISwitch) {
        value = sender.isOn
        callback(sender.isOn)
    }
    
    @objc private func handleThemeChange() {
        applyTheme()
    }
}
