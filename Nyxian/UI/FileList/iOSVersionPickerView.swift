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
    "26.0", "26.1", "26.2", "26.3", "26.4"
]

fileprivate func numericValue(_ version: String) -> Double {
    let parts = version.split(separator: ".").compactMap { Double($0) }
    let major = parts.count > 0 ? parts[0] : 0
    let minor = parts.count > 1 ? parts[1] : 0
    let patch = parts.count > 2 ? parts[2] : 0
    return major * 1_000_000 + minor * 1_000 + patch
}

struct NXOSVersion: Comparable, CustomStringConvertible {
    let versionString: String
    let versionNumeric: Double
    
    private(set) var pickerVersionString: String
    
    static let hostVersion: NXOSVersion = NXOSVersion()!
    static let minimumBuildVersion: NXOSVersion = NXOSVersion(versionString: iOSVersions.first)!
    static let maximumBuildVersion: NXOSVersion = NXOSVersion(versionString: iOSVersions.last)!
    
    init?(versionString inputString: String?) {
        guard let inputString = inputString,
              NXOSVersion.isValidVersionString(inputString) else {
            return nil
        }
        versionString = inputString
        versionNumeric = numericValue(versionString)
        pickerVersionString = versionString
        pickerVersionString = iOSVersions.min(by: {
            abs(numericValue($0) - self.versionNumeric) < abs(numericValue($1) - self.versionNumeric)
        }) ?? pickerVersionString
    }
    
    init?() {
        self.init(versionString: UIDevice.current.systemVersion)
    }
    
    static private func isValidVersionString(_ version: String) -> Bool {
        let parts = version.split(separator: ".", omittingEmptySubsequences: false)
        guard (1...3).contains(parts.count) else { return false }
        return parts.allSatisfy { part in
            guard !part.isEmpty, let value = Int(part) else { return false }
            return value >= 0
        }
    }
    
    static func == (lhs: NXOSVersion, rhs: NXOSVersion) -> Bool {
        lhs.versionNumeric == rhs.versionNumeric
    }
    
    static func < (lhs: NXOSVersion, rhs: NXOSVersion) -> Bool {
        lhs.versionNumeric < rhs.versionNumeric
    }
    
    var description: String {
        return versionString
    }
}

class IOSVersionPickerViewController: UIThemedViewController, UIPickerViewDelegate, UIPickerViewDataSource {

    var selectedVersion: String
    var onVersionSelected: ((String) -> Void)?

    private let pickerView = UIPickerView()

    private let pickerTitle: String

    init(title: String, selectedVersion: String) {
        let osVersion: NXOSVersion = NXOSVersion(versionString: selectedVersion) ?? NXOSVersion.maximumBuildVersion
        let selectedVersion = osVersion.pickerVersionString
        self.pickerTitle = title
        self.selectedVersion = selectedVersion
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.title = pickerTitle
        
        pickerView.delegate = self
        pickerView.dataSource = self
        pickerView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(pickerView)
        
        let idx = iOSVersions.firstIndex(of: selectedVersion) ?? iOSVersions.count - 1
        pickerView.selectRow(idx, inComponent: 0, animated: false)
        
        NSLayoutConstraint.activate([
            pickerView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
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
