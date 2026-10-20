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

