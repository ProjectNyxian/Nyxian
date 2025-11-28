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

class PickerTableCell: UITableViewCell {
    let options: [String]
    let key: String
    let defaultValue: Int
    var callback: (Int) -> Void = { _ in }

    private let label = UILabel()
    private let button = UIButton(type: .system)

    var value: Int {
        get {
            if UserDefaults.standard.object(forKey: key) == nil {
                UserDefaults.standard.set(defaultValue, forKey: key)
            }
            return UserDefaults.standard.integer(forKey: key)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: key)
            callback(newValue)
            button.setTitle(options[newValue], for: .normal)
            refreshMenuItems()
        }
    }

    init(options: [String], title: String, key: String, defaultValue: Int) {
        self.options = options
        self.key = key
        self.defaultValue = defaultValue
        super.init(style: .default, reuseIdentifier: nil)

        setupViews(title: title)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func setupViews(title: String) {
        selectionStyle = .none

        label.text = title
        label.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(label)

        let config = UIImage.SymbolConfiguration(pointSize: 12, weight: .semibold)
        let image = UIImage(systemName: "chevron.up.chevron.down", withConfiguration: config)

        button.setTitle(options[value], for: .normal)
        button.setImage(image, for: .normal)
        button.semanticContentAttribute = .forceRightToLeft
        button.translatesAutoresizingMaskIntoConstraints = false

        contentView.addSubview(button)
        
        refreshMenuItems()
        button.showsMenuAsPrimaryAction = true

        NSLayoutConstraint.activate([
            label.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            label.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),

            button.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            button.leadingAnchor.constraint(greaterThanOrEqualTo: label.trailingAnchor, constant: 8),
            button.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16)
        ])
    }

    func refreshMenuItems() {
        button.menu = UIMenu(children: options.enumerated().map { index, option in
            UIAction(
                title: option,
                state: index == value ? .on : .off
            ) { _ in
                self.value = index
            }
        })
    }
}
