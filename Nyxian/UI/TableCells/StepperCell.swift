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

class StepperTableCell: UITableViewCell {
    private let key: String
    private let minValue: Int
    private let maxValue: Int
    private let defaultValue: Int

    var callback: (Int) -> Void = { _ in }

    var value: Int {
        get {
            if UserDefaults.standard.object(forKey: key) == nil {
                UserDefaults.standard.set(defaultValue, forKey: key)
            }
            return UserDefaults.standard.integer(forKey: key)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: key)
        }
    }

    init(title: String, key: String, defaultValue: Int, minValue: Int, maxValue: Int) {
        self.key = key
        self.minValue = minValue
        self.maxValue = maxValue
        self.defaultValue = defaultValue
        super.init(style: .value1, reuseIdentifier: nil)

        selectionStyle = .none
        textLabel?.text = title

        let stepper = UIStepper()
        stepper.minimumValue = Double(minValue)
        stepper.maximumValue = Double(maxValue)
        stepper.value = Double(value)
        stepper.addTarget(self, action: #selector(stepperChanged(_:)), for: .valueChanged)

        accessoryView = stepper
        detailTextLabel?.text = "\(value)"
    }

    @objc private func stepperChanged(_ sender: UIStepper) {
        value = Int(sender.value)
        callback(value)
        detailTextLabel?.text = "\(value)"
    }

    required init?(coder: NSCoder) { fatalError() }
}

