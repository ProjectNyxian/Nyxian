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
import UniformTypeIdentifiers

class ImportTableCell: UITableViewCell, UIDocumentPickerDelegate {

    private weak var parent: UIViewController?
    private(set) var url: URL?

    private let importButton = UIButton(type: .system)
    private let filenameLabel = UILabel()

    init(parent: UIViewController) {
        self.parent = parent
        super.init(style: .default, reuseIdentifier: nil)
        setupViews()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupViews() {
        selectionStyle = .none

        importButton.setTitle("Import", for: .normal)
        importButton.setTitleColor(UIColor.systemBlue, for: .normal)
        importButton.contentHorizontalAlignment = .left
        importButton.addTarget(self, action: #selector(openPicker), for: .touchUpInside)
        importButton.titleLabel?.font = UIFont.systemFont(ofSize: 17)

        contentView.addSubview(importButton)

        filenameLabel.text = ""
        filenameLabel.textColor = .secondaryLabel
        filenameLabel.textAlignment = .right
        contentView.addSubview(filenameLabel)
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        let bounds = contentView.bounds
        let inset: CGFloat = 16

        // Import button fills full height, standard Apple style
        importButton.frame = CGRect(
            x: inset,
            y: 0,
            width: bounds.width / 2,
            height: bounds.height
        )

        // Filename label sits on the right
        filenameLabel.frame = CGRect(
            x: bounds.width / 2,
            y: 0,
            width: bounds.width / 2 - inset,
            height: bounds.height
        )
    }

    @objc private func openPicker() {
        guard let parent else { return }
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.data], asCopy: true)
        picker.delegate = self
        parent.present(picker, animated: true)
    }

    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard let u = urls.first else { return }
        url = u
        
        // Fade-out → text change → fade-in
        UIView.animate(withDuration: 0.25, animations: {
            self.filenameLabel.alpha = 0.0
        }) { _ in
            self.filenameLabel.text = u.lastPathComponent
            
            UIView.animate(withDuration: 0.25) {
                self.filenameLabel.alpha = 1.0
            }
        }
    }
}
