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
