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
import MobileDevelopmentKit

fileprivate var _NXSDK: MDKSDK? = nil
fileprivate var NXSDK: MDKSDK? {
    get {
        if(_NXSDK == nil) {
            _NXSDK = MDKSDK(forDirectoryURL: NXBootstrap.shared().sdkURL)
        }
        return _NXSDK
    }
}

fileprivate var _NXOSVersionSupportedBuildVersions: [String] = []
@objc class NXOSVersion: NSObject {
    @objc static var NXOSVersionSupportedBuildVersionsRaw: [MDKOSVersion] {
        get {
            if let sdk = NXSDK,
               let supportedVersion = sdk.supportedVersions {
                return supportedVersion
            }
            if let fallbackMin = MDKOSVersion(versionString: "15.0"),
               let fallbackMax = MDKOSVersion(versionString: "27.0"){
                return [fallbackMin, fallbackMax]
            }
            return []
        }
    }
    @objc static var NXOSVersionSupportedBuildVersions: [String] {
        get {
            if !_NXOSVersionSupportedBuildVersions.isEmpty {
                return _NXOSVersionSupportedBuildVersions
            }
            
            if let sdk = NXSDK,
               let supportedVersions = sdk.supportedVersions {
                for version in supportedVersions {
                    _NXOSVersionSupportedBuildVersions.append(version.versionString)
                }
                return _NXOSVersionSupportedBuildVersions
            }
            
            return ["15.0", "27.0"]
        }
    }
}

class IOSVersionPickerViewController: NXUIViewController, UIPickerViewDelegate, UIPickerViewDataSource {
    var selectedVersion: String
    var onVersionSelected: ((String) -> Void)?

    private let pickerView = UIPickerView()

    private let pickerTitle: String

    private let versions: [String]
    
    init(title: String, selectedVersion: String) {
        let osVersion: MDKOSVersion = MDKOSVersion(versionString: selectedVersion) ?? MDKOSVersion(versionString: NXOSVersion.NXOSVersionSupportedBuildVersions.last!)!
        self.pickerTitle = title
        self.selectedVersion = osVersion.versionString
        self.versions = Self.list(injecting: osVersion)
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError() }

    private static func list(injecting target: MDKOSVersion) -> [String] {
        let supported = NXOSVersion.NXOSVersionSupportedBuildVersions
        guard !supported.contains(target.versionString) else {
            return supported
        }
        
        var insertIdx = supported.count
        for (i, s) in supported.enumerated() {
            guard let v = MDKOSVersion(versionString: s) else {
                continue
            }
            if v.versionNumeric > target.versionNumeric {
                insertIdx = i
                break
            }
        }
        var result = supported
        result.insert(target.versionString, at: insertIdx)
        return result
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.title = pickerTitle
        
        pickerView.delegate = self
        pickerView.dataSource = self
        pickerView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(pickerView)
        
        let idx = versions.firstIndex(of: selectedVersion) ?? versions.count - 1
        pickerView.selectRow(idx, inComponent: 0, animated: false)
        
        NSLayoutConstraint.activate([
            pickerView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            pickerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            pickerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])
    }

    func numberOfComponents(in pickerView: UIPickerView) -> Int { 1 }

    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        versions.count
    }

    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        "iOS \(versions[row])"
    }

    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        selectedVersion = versions[row]
        onVersionSelected?(selectedVersion)
    }
}
