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

struct Credit {
    let name: String
    let role: String
    let githubURL: String
}

class CreditCell: UITableViewCell {
    static let identifier = "CreditCell"
    
    private let imageShadowContainer: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = .clear
        view.layer.shadowColor = UIColor.black.cgColor
        view.layer.shadowOffset = CGSize(width: 0, height: 4)
        view.layer.shadowRadius = 12
        view.layer.shadowOpacity = 0.3
        return view
    }()
    
    let profileImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.layer.cornerRadius = 18
        imageView.layer.borderWidth = 1
        imageView.layer.borderColor = UIColor.white.withAlphaComponent(0.5).cgColor
        return imageView
    }()
    
    private let shineGradientLayer: CAGradientLayer = {
        let gradient = CAGradientLayer()
        gradient.colors = [
            UIColor.white.withAlphaComponent(0.6).cgColor,
            UIColor.white.withAlphaComponent(0.3).cgColor,
            UIColor.clear.cgColor,
            UIColor.white.withAlphaComponent(0.1).cgColor
        ]
        gradient.locations = [0.0, 0.3, 0.7, 1.0]
        gradient.startPoint = CGPoint(x: 0, y: 0)
        gradient.endPoint = CGPoint(x: 1, y: 1)
        return gradient
    }()
    
    private let shineView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.isUserInteractionEnabled = false
        view.layer.cornerRadius = 18
        view.clipsToBounds = true
        return view
    }()
    
    let nameLabel: UILabel = {
        let label = UILabel()
        label.font = .boldSystemFont(ofSize: 16)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    let roleLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 14)
        label.textColor = .secondaryLabel
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let textStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 2
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        
        selectionStyle = .none
        
        textStack.addArrangedSubview(nameLabel)
        textStack.addArrangedSubview(roleLabel)
        
        contentView.addSubview(imageShadowContainer)
        imageShadowContainer.addSubview(profileImageView)
        imageShadowContainer.addSubview(shineView)
        contentView.addSubview(textStack)

        shineView.layer.addSublayer(shineGradientLayer)
        
        NSLayoutConstraint.activate([
            imageShadowContainer.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            imageShadowContainer.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            imageShadowContainer.widthAnchor.constraint(equalToConstant: 60),
            imageShadowContainer.heightAnchor.constraint(equalToConstant: 60),
            profileImageView.topAnchor.constraint(equalTo: imageShadowContainer.topAnchor),
            profileImageView.leadingAnchor.constraint(equalTo: imageShadowContainer.leadingAnchor),
            profileImageView.trailingAnchor.constraint(equalTo: imageShadowContainer.trailingAnchor),
            profileImageView.bottomAnchor.constraint(equalTo: imageShadowContainer.bottomAnchor),
            shineView.topAnchor.constraint(equalTo: profileImageView.topAnchor),
            shineView.leadingAnchor.constraint(equalTo: profileImageView.leadingAnchor),
            shineView.trailingAnchor.constraint(equalTo: profileImageView.trailingAnchor),
            shineView.bottomAnchor.constraint(equalTo: profileImageView.bottomAnchor),
            textStack.leadingAnchor.constraint(equalTo: profileImageView.trailingAnchor, constant: 16),
            textStack.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            textStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16)
        ])
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        imageShadowContainer.layer.shadowPath = UIBezierPath(
            roundedRect: imageShadowContainer.bounds,
            cornerRadius: 30
        ).cgPath
        shineGradientLayer.frame = shineView.bounds
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        profileImageView.image = nil
        nameLabel.text = nil
        roleLabel.text = nil
    }
}
