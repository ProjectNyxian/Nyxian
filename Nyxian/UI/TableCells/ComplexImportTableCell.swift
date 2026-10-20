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

final class ComplexImportTableCell: UITableViewCell, UIDocumentPickerDelegate {
    
    private weak var parent: UIViewController?
    private(set) var url: URL?
    private let iconContainer = UIView()
    private let iconView = UIImageView()
    private let titleLabel = UILabel()
    private let filenameLabel = UILabel()
    private let accessoryIcon = UIImageView()
    private lazy var labelsStack = UIStackView(
        arrangedSubviews: [
            titleLabel,
            filenameLabel
        ]
    )
    
    init(parent: UIViewController) {
        self.parent = parent
        
        super.init(style: .default, reuseIdentifier: nil)
        
        setupViews()
        setupConstraints()
        updateAppearance(animated: false)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupViews() {
        selectionStyle = .none
        contentView.backgroundColor = .clear
        
        let tap = UITapGestureRecognizer(target: self, action: #selector(openPicker))
        
        contentView.addGestureRecognizer(tap)
        contentView.isUserInteractionEnabled = true
        
        iconContainer.translatesAutoresizingMaskIntoConstraints = false
        iconContainer.backgroundColor = .systemBlue.withAlphaComponent(0.12)
        iconContainer.layer.cornerRadius = 12
        iconContainer.layer.cornerCurve = .continuous
        
        contentView.addSubview(iconContainer)
        
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.contentMode = .scaleAspectFit
        iconView.tintColor = .systemBlue
        
        iconContainer.addSubview(iconView)
        
        titleLabel.font = .preferredFont(forTextStyle: .body)
        titleLabel.adjustsFontForContentSizeCategory = true
        titleLabel.textColor = .label
        titleLabel.numberOfLines = 1
        
        filenameLabel.font = .preferredFont(forTextStyle: .footnote)
        filenameLabel.adjustsFontForContentSizeCategory = true
        filenameLabel.textColor = .secondaryLabel
        filenameLabel.numberOfLines = 1
        filenameLabel.lineBreakMode = .byTruncatingMiddle
        
        labelsStack.translatesAutoresizingMaskIntoConstraints = false
        labelsStack.axis = .vertical
        labelsStack.alignment = .fill
        labelsStack.spacing = 3
        
        contentView.addSubview(labelsStack)
        
        accessoryIcon.translatesAutoresizingMaskIntoConstraints = false
        accessoryIcon.contentMode = .scaleAspectFit
        accessoryIcon.tintColor = .tertiaryLabel
        
        contentView.addSubview(accessoryIcon)
        
        isAccessibilityElement = true
        accessibilityTraits = .button
    }
    
    private func setupConstraints() {
        NSLayoutConstraint.activate([
            contentView.heightAnchor.constraint(greaterThanOrEqualToConstant: 72),
            
            iconContainer.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            iconContainer.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            iconContainer.widthAnchor.constraint(equalToConstant: 44),
            iconContainer.heightAnchor.constraint(equalToConstant: 44),
            
            iconView.centerXAnchor.constraint(equalTo: iconContainer.centerXAnchor),
            iconView.centerYAnchor.constraint(equalTo: iconContainer.centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 24),
            iconView.heightAnchor.constraint(equalToConstant: 24),
            
            labelsStack.leadingAnchor.constraint(equalTo: iconContainer.trailingAnchor, constant: 14),
            labelsStack.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            
            labelsStack.topAnchor.constraint(greaterThanOrEqualTo: contentView.topAnchor, constant: 12),
            labelsStack.bottomAnchor.constraint(lessThanOrEqualTo: contentView.bottomAnchor, constant: -12),
            
            accessoryIcon.leadingAnchor.constraint(equalTo: labelsStack.trailingAnchor, constant: 12),
            accessoryIcon.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            accessoryIcon.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            accessoryIcon.widthAnchor.constraint(equalToConstant: 20),
            accessoryIcon.heightAnchor.constraint(equalToConstant: 20)
        ])
    }
    
    private func updateAppearance(animated: Bool) {
        let changes = {
            if let url = self.url {
                self.titleLabel.text = "Certificate Selected"
                self.filenameLabel.text = url.lastPathComponent
                
                self.iconView.image = UIImage(systemName: "checkmark.seal.fill")
                self.iconContainer.backgroundColor = UIColor.systemGreen.withAlphaComponent(0.12)
                self.iconView.tintColor = .systemGreen
                
                self.accessoryIcon.image = UIImage(systemName: "chevron.right")
                self.accessoryIcon.tintColor = .tertiaryLabel
                
                self.accessibilityLabel = "Selected certificate"
                self.accessibilityValue = url.lastPathComponent
                self.accessibilityHint = "Double tap to choose another certificate"
            } else {
                self.titleLabel.text = "Select Certificate"
                self.filenameLabel.text = "PKCS#12 certificate (.p12 or .pfx)"
                
                self.iconView.image = UIImage(systemName: "key.viewfinder")
                self.iconContainer.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.12)
                self.iconView.tintColor = .systemBlue
                
                self.accessoryIcon.image = UIImage(systemName: "chevron.right")
                self.accessoryIcon.tintColor = .tertiaryLabel
                
                self.accessibilityLabel = "Choose certificate"
                self.accessibilityValue = nil
                self.accessibilityHint = "Opens the file picker"
            }
        }
        
        guard animated else {
            changes()
            return
        }
        
        UIView.transition(with: contentView, duration: 0.25, options: [.transitionCrossDissolve, .allowAnimatedContent], animations: changes)
    }
    
    @objc private func openPicker() {
        guard let parent else {
            return
        }
        
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.data], asCopy: true)
        
        picker.delegate = self
        picker.allowsMultipleSelection = false
        parent.present(picker, animated: true)
    }
    
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard let selectedURL = urls.first else { return }
        url = selectedURL
        updateAppearance(animated: true)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
    
    override func setHighlighted(_ highlighted: Bool, animated: Bool) {
        super.setHighlighted(highlighted, animated: animated)
        UIView.animate(withDuration: 0.15, delay: 0, options: [.allowUserInteraction, .beginFromCurrentState]) {
            self.contentView.alpha = highlighted ? 0.55 : 1.0
        }
    }
}
