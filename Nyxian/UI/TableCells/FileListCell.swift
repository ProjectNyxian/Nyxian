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

class FileListCell: UITableViewCell {
    static let reuseIdentifier = "FileListCell"
    
    private let iconView = UIView()
    private let iconLabel = UILabel()
    private let iconImageView = UIImageView()
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupViews()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupViews() {
        iconView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(iconView)
        
        iconLabel.font = .systemFont(ofSize: 20, weight: .light)
        iconLabel.translatesAutoresizingMaskIntoConstraints = false
        iconView.addSubview(iconLabel)
        
        iconImageView.contentMode = .scaleAspectFit
        iconImageView.translatesAutoresizingMaskIntoConstraints = false
        iconView.addSubview(iconImageView)
        
        NSLayoutConstraint.activate([
            iconView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 15),
            iconView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 25),
            iconView.heightAnchor.constraint(equalToConstant: 25),
            
            iconLabel.centerXAnchor.constraint(equalTo: iconView.centerXAnchor),
            iconLabel.centerYAnchor.constraint(equalTo: iconView.centerYAnchor),
            
            iconImageView.centerXAnchor.constraint(equalTo: iconView.centerXAnchor),
            iconImageView.centerYAnchor.constraint(equalTo: iconView.centerYAnchor),
            iconImageView.heightAnchor.constraint(equalToConstant: 20)
        ])
        
        textLabel?.translatesAutoresizingMaskIntoConstraints = false
        if let textLabel = textLabel {
            NSLayoutConstraint.activate([
                textLabel.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 12),
                textLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor)
            ])
        }
        
        separatorInset = .zero
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        iconLabel.text = nil
        iconLabel.textColor = nil
        iconImageView.image = nil
        iconImageView.tintColor = nil
        
        iconView.subviews.forEach { subview in
            if subview != iconLabel && subview != iconImageView {
                subview.removeFromSuperview()
            }
        }
    }
    
    func configure(with entry: FileListEntry) {
        let url = URL(fileURLWithPath: entry.path)
        let ext = url.pathExtension.lowercased()
        
        accessoryType = (entry.type == .dir) ? .disclosureIndicator : .none
        textLabel?.text = url.deletingPathExtension().lastPathComponent
        
        iconLabel.isHidden = true
        iconImageView.isHidden = true
        
        if entry.type == .file {
            switch ext {
            case "c":
                configureTextIcon(text: "c", color: .systemBlue)
            case "h":
                configureTextIcon(text: "h", color: .systemGray)
            case "cpp":
                configureStackedIcon(base: "c", color: .systemBlue)
            case "hpp":
                configureStackedIcon(base: "h", color: .systemBlue)
            case "m":
                configureTextIcon(text: "m", color: .systemPurple)
            case "mm":
                configureStackedIcon(base: "m", color: .systemBlue)
            case "plist":
                configureImageIcon(name: "tablecells.fill")
            case "zip", "tar", "zst":
                configureImageIcon(name: "doc.fill")
            case "ipa":
                configureImageIcon(name: "app.gift.fill")
            case "png", "jpg", "jpeg", "gif", "svg":
                configureImageIcon(name: "photo.fill")
            default:
                if #unavailable(iOS 17.0) {
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
        iconImageView.image = UIImage(systemName: name)
        if let tintColor = tintColor {
            iconImageView.tintColor = tintColor
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
        
        let offset: CGPoint = base == "m" ? CGPoint(x: 9, y: -6) : CGPoint(x: 8, y: -5)
        NSLayoutConstraint.activate([
            plusLabel.leadingAnchor.constraint(equalTo: iconLabel.trailingAnchor, constant: offset.x),
            plusLabel.topAnchor.constraint(equalTo: iconLabel.topAnchor, constant: offset.y)
        ])
    }
}
