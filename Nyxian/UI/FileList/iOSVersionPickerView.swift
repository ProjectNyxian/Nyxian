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

fileprivate var _NXOSVersionSupportedBuildVersions: [String] = []
var NXOSVersionSupportedBuildVersions: [String] {
    get {
        if !_NXOSVersionSupportedBuildVersions.isEmpty {
            return _NXOSVersionSupportedBuildVersions
        }
        
        let sdkURL = NXBootstrap.shared().sdkURL
        let settingsURL = sdkURL.appendingPathComponent("SDKSettings.plist")
        if let root: [String:Any] = NSDictionary(contentsOf: settingsURL) as? [String:Any] {
            /* modern SDK handling */
            if let supported: [String:Any] = root["SupportedTargets"] as? [String:Any],
               let platformEntry: [String:Any] = supported["iphoneos"] as? [String:Any],
               let validDeploymentTargets: [String] = platformEntry["ValidDeploymentTargets"] as? [String] {
                _NXOSVersionSupportedBuildVersions = validDeploymentTargets
                return _NXOSVersionSupportedBuildVersions
            }
            
            /* legacy SDK handling */
            if let validDeploymentTargets: [String] = root["ValidDeploymentTargets"] as? [String] {
                _NXOSVersionSupportedBuildVersions = validDeploymentTargets
                return _NXOSVersionSupportedBuildVersions
            }
        }
        
        return ["26.4"]
    }
}

fileprivate func numericValue(_ version: String) -> Double {
    let parts = version.split(separator: ".").compactMap { Double($0) }
    let major = parts.count > 0 ? parts[0] : 0
    let minor = parts.count > 1 ? parts[1] : 0
    let patch = parts.count > 2 ? parts[2] : 0
    return major * 1_000_000 + minor * 1_000 + patch
}

@objc class NXOSVersion: NSObject, Comparable {
    @objc let versionString: String
    @objc let versionNumeric: Double
    
    @objc private(set) var pickerVersionString: String
    
    @objc static let hostVersion: NXOSVersion = NXOSVersion()
    @objc static var minimumBuildVersion: NXOSVersion {
        get {
            return NXOSVersion(versionString: NXOSVersionSupportedBuildVersions.first)!
        }
    }
    @objc static var maximumBuildVersion: NXOSVersion {
        get {
            NXOSVersion(versionString: NXOSVersionSupportedBuildVersions.last)!
        }
    }
    
    @objc init?(versionString inputString: String?) {
        var inputString = inputString ?? "9.0"
        if !NXOSVersion.isValidVersionString(inputString) {
            inputString = "9.0"
        }
        versionString = inputString
        versionNumeric = numericValue(versionString)
        pickerVersionString = versionString
        let numeric = versionNumeric
        pickerVersionString = NXOSVersionSupportedBuildVersions.min(by: {
            abs(numericValue($0) - numeric) < abs(numericValue($1) - numeric)
        }) ?? pickerVersionString
    }
    
    @objc override convenience init() {
        self.init(versionString: UIDevice.current.systemVersion)!
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
    
    @objc override var description: String {
        return versionString
    }
    
    @objc override func isEqual(_ object: Any?) -> Bool {
        guard let other = object as? NXOSVersion else { return false }
        return versionNumeric == other.versionNumeric
    }

    @objc override var hash: Int {
        versionNumeric.hashValue
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
        
        let idx = NXOSVersionSupportedBuildVersions.firstIndex(of: selectedVersion) ?? NXOSVersionSupportedBuildVersions.count - 1
        pickerView.selectRow(idx, inComponent: 0, animated: false)
        
        NSLayoutConstraint.activate([
            pickerView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            pickerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            pickerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])
    }

    func numberOfComponents(in pickerView: UIPickerView) -> Int { 1 }

    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        NXOSVersionSupportedBuildVersions.count
    }

    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        "iOS \(NXOSVersionSupportedBuildVersions[row])"
    }

    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        selectedVersion = NXOSVersionSupportedBuildVersions[row]
        onVersionSelected?(selectedVersion)
    }
}
