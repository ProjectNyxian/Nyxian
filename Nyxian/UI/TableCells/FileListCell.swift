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

class FileIcon: UIView {
    private let iconView = UIView()
    private let iconLabel = UILabel()
    private let iconImageView = UIImageView()
    
    init(withFontSize fontSize: CGFloat) {
        super.init(frame: CGRect.zero)
        
        iconView.translatesAutoresizingMaskIntoConstraints = false
        self.addSubview(iconView)
        
        iconLabel.font = .systemFont(ofSize: fontSize, weight: .light)
        iconLabel.translatesAutoresizingMaskIntoConstraints = false
        iconView.addSubview(iconLabel)
        
        iconImageView.contentMode = .scaleAspectFit
        iconImageView.translatesAutoresizingMaskIntoConstraints = false
        iconView.addSubview(iconImageView)
        
        NSLayoutConstraint.activate([
            iconView.centerXAnchor.constraint(equalTo: self.centerXAnchor),
            iconView.centerYAnchor.constraint(equalTo: self.centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 25),
            iconView.heightAnchor.constraint(equalToConstant: 25),
            
            iconLabel.centerXAnchor.constraint(equalTo: iconView.centerXAnchor),
            iconLabel.centerYAnchor.constraint(equalTo: iconView.centerYAnchor),
            
            iconImageView.centerXAnchor.constraint(equalTo: iconView.centerXAnchor),
            iconImageView.centerYAnchor.constraint(equalTo: iconView.centerYAnchor),
            iconImageView.heightAnchor.constraint(equalToConstant: 20)
        ])
    }
    
    func configure(with entry: FileListEntry) {
        let url = URL(fileURLWithPath: entry.path)
        let ext = url.pathExtension.lowercased()
        
        iconView.subviews.filter { $0 is UILabel && $0 != iconLabel }.forEach { $0.removeFromSuperview() }
        
        iconLabel.isHidden = true
        iconImageView.isHidden = true
        
        if entry.type == .file {
            switch ext {
            case "swift":
                configureImageIcon(name: "swift", tintColor: .systemOrange)
            case "c":
                configureTextIcon(text: "c", color: .systemPurple)
            case "h":
                configureTextIcon(text: "h", color: .systemGray)
            case "cpp":
                configureStackedIcon(base: "c", color: .systemBlue)
            case "hpp":
                configureStackedIcon(base: "h", color: .systemGray)
            case "m":
                configureTextIcon(text: "m", color: .systemPurple)
            case "mm":
                configureStackedIcon(base: "m", color: .systemBlue)
            case "plist","xml":
                configureImageIcon(name: "tablecells.fill")
            case "zip", "tar", "zst":
                configureImageIcon(name: "archivebox.fill")
            case "ipa":
                configureImageIcon(name: "app.gift.fill")
            case "png", "jpg", "jpeg", "gif", "svg":
                configureImageIcon(name: "photo.fill")
            case "dylib":
                configureImageIcon(name: "building.columns.fill")
            default:
                if #unavailable(iOS 18.0) {
                    configureImageIcon(name: "text.alignleft")
                } else {
                    configureImageIcon(name: "text.page.fill")
                }
            }
        } else {
            configureImageIcon(name: "folder.fill")
        }
    }
    
    private func configureTextIcon(text: String, color: UIColor) {
        iconLabel.text = text
        iconLabel.textColor = color
        iconLabel.isHidden = false
    }
    
    private func configureImageIcon(name: String, tintColor: UIColor? = nil) {
        if(self.iconLabel.font.pointSize == 20) {
            iconImageView.image = UIImage(systemName: name)
        } else {
            let symbolConfig = UIImage.SymbolConfiguration(pointSize: self.iconLabel.font.pointSize - 2, weight: .regular)
            iconImageView.image = UIImage(systemName: name, withConfiguration: symbolConfig)
        }
        if let tintColor = tintColor {
            iconImageView.tintColor = tintColor
        } else {
            iconImageView.tintColor = currentTheme?.textColor
        }
        iconImageView.isHidden = false
    }
    
    private func configureStackedIcon(base: String, color: UIColor) {
        iconLabel.text = base
        iconLabel.textColor = color
        iconLabel.isHidden = false
        
        let plusLabel = UILabel()
        plusLabel.text = "+"
        plusLabel.font = .systemFont(ofSize: 10, weight: .light)
        plusLabel.textColor = color
        plusLabel.translatesAutoresizingMaskIntoConstraints = false
        
        iconView.addSubview(plusLabel)
        
        NSLayoutConstraint.activate([
            plusLabel.leadingAnchor.constraint(equalTo: iconLabel.trailingAnchor),
            plusLabel.firstBaselineAnchor.constraint(equalTo: iconLabel.firstBaselineAnchor, constant: -9)
        ])
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

class FileListCell: UITableViewCell {
    static let reuseIdentifier = "FileListCell"
    
    private let fileIcon = FileIcon(withFontSize: 20)
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupViews()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupViews() {
        fileIcon.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(fileIcon)
        
        NSLayoutConstraint.activate([
            fileIcon.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 15),
            fileIcon.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            fileIcon.widthAnchor.constraint(equalToConstant: 25),
            fileIcon.heightAnchor.constraint(equalToConstant: 25)
        ])
        
        textLabel?.translatesAutoresizingMaskIntoConstraints = false
        if let textLabel = textLabel {
            NSLayoutConstraint.activate([
                textLabel.leadingAnchor.constraint(equalTo: fileIcon.trailingAnchor, constant: 12),
                textLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -12),
                textLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor)
            ])
        }
        
        separatorInset = .zero
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        textLabel?.text = nil
    }
    
    func configure(with entry: FileListEntry) {
        let url = URL(fileURLWithPath: entry.path)
        textLabel?.text = url.deletingPathExtension().lastPathComponent
        accessoryType = (entry.type == .dir) ? .disclosureIndicator : .none
        
        fileIcon.configure(with: entry)
    }
}
