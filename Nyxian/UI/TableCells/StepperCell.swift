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
    var callback: (Int) -> Void = { _ in }
    
    let title: String
    
    let key: String
    let defaultValue: Int
    let minValue: Int
    let maxValue: Int
    var value: Int {
        get {
            if UserDefaults.standard.object(forKey: self.key) == nil {
                UserDefaults.standard.set(self.defaultValue, forKey: self.key)
            }
            
            return UserDefaults.standard.integer(forKey: self.key)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: self.key)
        }
    }
    
    var label: UILabel?
    
    init(
        title: String,
        key: String,
        defaultValue: Int,
        minValue: Int,
        maxValue: Int
    ) {
        self.title = title
        self.key = key
        self.defaultValue = defaultValue
        self.minValue = minValue
        self.maxValue = maxValue
        super.init(style: .default, reuseIdentifier: nil)
        
        _ = self.value
        
        self.setupViews()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupViews() {
        // disable selection
        self.selectionStyle = .none
        
        // First create the label
        self.label = UILabel()
        self.label?.text = "\(self.title): \(self.value)"
        self.label?.translatesAutoresizingMaskIntoConstraints = false
        self.contentView.addSubview(label!)
        
        // now the option button
        let stepper = UIStepper()
        stepper.minimumValue = Double(self.minValue)
        stepper.maximumValue = Double(self.maxValue)
        stepper.stepValue = 1
        stepper.value = Double(self.value)
        stepper.addTarget(self, action: #selector(stepperValueChanged), for: .valueChanged)
        stepper.translatesAutoresizingMaskIntoConstraints = false
        self.contentView.addSubview(stepper)
        
        // Now fix its constraints
        NSLayoutConstraint.activate([
            self.label!.topAnchor.constraint(equalTo: self.contentView.topAnchor),
            self.label!.bottomAnchor.constraint(equalTo: self.contentView.bottomAnchor),
            self.label!.leadingAnchor.constraint(equalTo: self.contentView.leadingAnchor, constant: 16),
            
            stepper.centerYAnchor.constraint(equalTo: self.contentView.centerYAnchor),
            stepper.leadingAnchor.constraint(equalTo: self.label!.trailingAnchor, constant: 16),
            stepper.trailingAnchor.constraint(equalTo: self.contentView.trailingAnchor, constant: -16)
        ])
    }
    
    @objc func stepperValueChanged(sender: UIStepper) {
        self.value = Int(sender.value)
        self.callback(self.value)
        self.label?.text = "\(self.title): \(Int(sender.value))"
    }
}
