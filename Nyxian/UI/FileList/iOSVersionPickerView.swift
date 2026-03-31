/*
 SPDX-License-Identifier: AGPL-3.0-or-later

 Copyright (C) 2025 - 2026 cr4zyengineer

 This file is part of Nyxian.

 Nyxian is free software: you can redistribute it and/or modify
 it under the terms of the GNU Affero General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.

 Nyxian is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 GNU Affero General Public License for more details.

 You should have received a copy of the GNU Affero General Public License
 along with Nyxian. If not, see <https://www.gnu.org/licenses/>.
*/

import UIKit

let iOSVersions: [String] = [
    // Legacy (generally not recommended to use these)
    "4.0", "4.1", "4.2",
    "5.0", "5.1",
    "6.0", "6.1",
    
    // Tho unstable with the latest iOS there are posibilities of using those so I add them
    "7.0", "7.1",
    "8.0", "8.1", "8.2", "8.3", "8.4",
    "9.0", "9.1", "9.2", "9.3",
    "10.0", "10.1", "10.2", "10.3",
    
    // Slightly stabler and usable
    "11.0", "11.1", "11.2", "11.3", "11.4",
    "12.0", "12.1", "12.2", "12.3", "12.4", "12.5",
    
    // Works perfectly fine
    "13.0", "13.1", "13.2", "13.3", "13.4", "13.5", "13.6", "13.7",
    "14.0", "14.1", "14.2", "14.3", "14.4", "14.5", "14.6", "14.7", "14.8",
    "15.0", "15.1", "15.2", "15.3", "15.4", "15.5", "15.6", "15.7", "15.8",
    "16.0", "16.1", "16.2", "16.3", "16.4", "16.5", "16.6", "16.7",
    "17.0", "17.1", "17.2", "17.3", "17.4", "17.5", "17.6", "17.7",
    "18.0", "18.1", "18.2", "18.3", "18.4", "18.5", "18.6",
    "26.0", "26.1", "26.2", "26.3", "26.4", "26.5"
]

class IOSVersionPickerViewController: UIThemedViewController, UIPickerViewDelegate, UIPickerViewDataSource {

    var selectedVersion: String
    var onVersionSelected: ((String) -> Void)?

    private let pickerView = UIPickerView()
    private let titleLabel = UILabel()

    private let pickerTitle: String

    init(title: String, selectedVersion: String) {
        self.pickerTitle = title
        self.selectedVersion = selectedVersion
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.title = pickerTitle
        
        if #available(iOS 13.0, *) {
            view.backgroundColor = .systemGroupedBackground
        } else {
            view.backgroundColor = .groupTableViewBackground
        }
        
        titleLabel.text = pickerTitle
        titleLabel.font = .systemFont(ofSize: 13, weight: .medium)
        titleLabel.textColor = .secondaryLabel
        titleLabel.textAlignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(titleLabel)
        
        pickerView.delegate = self
        pickerView.dataSource = self
        pickerView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(pickerView)
        
        let idx = iOSVersions.firstIndex(of: selectedVersion) ?? iOSVersions.count - 1
        pickerView.selectRow(idx, inComponent: 0, animated: false)
        
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 24),
            titleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            titleLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            
            pickerView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            pickerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            pickerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])
    }

    func numberOfComponents(in pickerView: UIPickerView) -> Int { 1 }

    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        iOSVersions.count
    }

    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        "iOS \(iOSVersions[row])"
    }

    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        selectedVersion = iOSVersions[row]
        onVersionSelected?(selectedVersion)
    }
}
