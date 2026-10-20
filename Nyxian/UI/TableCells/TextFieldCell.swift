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
