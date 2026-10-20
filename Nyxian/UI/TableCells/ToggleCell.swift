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

import Foundation
import UIKit

class ToggleTableCell: UITableViewCell {
    static let reuseIdentifier = "ToggleTableCell"
    
    var callback: (Bool) -> Void = { _ in }
    
    private(set) var toggle: NXUISwitch = {
        let toggle = NXUISwitch()
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
    
    
    @objc private func toggleChanged(_ sender: UISwitch) {
        value = sender.isOn
        callback(sender.isOn)
    }
}
