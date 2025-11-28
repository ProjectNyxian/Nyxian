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

import UIKit

class NXTextFieldTableCell: UITableViewCell, UITextFieldDelegate {
    var textField: UITextField!
    let title: String
    let hint: String
    let key: String?
    let defaultValue: String
    let writeHandler: (String) -> Void

    private var pvalue: String = ""
    var value: String {
        get {
            if let key = key {
                return UserDefaults.standard.string(forKey: key) ?? defaultValue
            } else {
                return pvalue
            }
        }
        set {
            self.writeHandler(newValue)
            if let key = key {
                UserDefaults.standard.set(newValue, forKey: key)
            } else {
                pvalue = newValue
            }
        }
    }
    
    var text: String {
        get {
            return self.textField.text ?? ""
        }
        set {
            self.textField.text = newValue
        }
    }

    init(title: String,
         hint: String,
         key: String?,
         defaultValue: String,
         writeHandler: @escaping (String) -> Void = { _ in }) {
        self.title = title
        self.key = key
        self.defaultValue = defaultValue
        self.writeHandler = writeHandler
        self.hint = hint
        super.init(style: .default, reuseIdentifier: nil)
        
        if let key = key {
            if UserDefaults.standard.object(forKey: key) == nil {
                UserDefaults.standard.set(defaultValue, forKey: key)
            }
        }

        setupViews(initialValue: value)
    }
    
    convenience init(title: String, hint: String) {
        self.init(title: title, hint: hint, key: nil, defaultValue: "")
    }
    
    convenience init(title: String, hint: String, writeHandler: @escaping (String) -> Void) {
        self.init(title: title, hint: hint, key: nil, defaultValue: "", writeHandler: writeHandler)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupViews(initialValue: String) {
        selectionStyle = .none

        let label = UILabel()
        label.text = title
        label.translatesAutoresizingMaskIntoConstraints = false
        label.setContentCompressionResistancePriority(.required, for: .horizontal)
        contentView.addSubview(label)

        textField = UITextField()
        textField.placeholder = self.hint
        textField.text = initialValue
        textField.textAlignment = .right
        textField.delegate = self
        textField.translatesAutoresizingMaskIntoConstraints = false
        textField.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        contentView.addSubview(textField)

        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            label.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),

            textField.leadingAnchor.constraint(equalTo: label.trailingAnchor, constant: 12),
            textField.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            textField.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            textField.heightAnchor.constraint(equalToConstant: 30)
        ])
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesEnded(touches, with: event)
        textField.becomeFirstResponder()
    }

    func textFieldDidEndEditing(_ textField: UITextField) {
        self.value = textField.text ?? ""
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        self.value = textField.text ?? ""
        return true
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        textField.text = nil
    }
}
