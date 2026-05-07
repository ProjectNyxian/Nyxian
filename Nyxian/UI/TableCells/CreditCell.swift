/*
 SPDX-License-Identifier: AGPL-3.0-or-later

 Copyright (C) 2025 - 2026 mach-port-t

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
            cornerRadius: 18
        ).cgPath
        shineGradientLayer.frame = shineView.bounds
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        profileImageView.image = nil
        nameLabel.text = nil
        roleLabel.text = nil
        profileImageView.layer.borderColor = UIColor.white.withAlphaComponent(0.5).cgColor
        profileImageView.layer.borderWidth = 1
        imageShadowContainer.layer.shadowColor = UIColor.black.cgColor
        imageShadowContainer.layer.shadowOpacity = 0.3
        imageShadowContainer.layer.shadowRadius = 12
    }
    
    func configureImage(_ image: UIImage?) {
        profileImageView.image = image
        
        guard let image = image else {
            profileImageView.layer.borderColor = UIColor.white.withAlphaComponent(0.0).cgColor
            imageShadowContainer.layer.shadowColor = UIColor.black.cgColor
            imageShadowContainer.layer.shadowOpacity = 0.3
            return
        }
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let accent = image.dominantAccentColor() else { return }
            DispatchQueue.main.async {
                guard let self, self.profileImageView.image === image else { return }
                let border = accent.withAlphaComponent(0.4)
                self.profileImageView.layer.borderColor = border.cgColor
                self.profileImageView.layer.borderWidth = 1.5
            }
        }
    }
}

extension UIImage {
    func dominantAccentColor(sampleSize: Int = 24) -> UIColor? {
        guard let cgImage = cgImage else { return nil }
        let w = sampleSize, h = sampleSize
        var pixels = [UInt8](repeating: 0, count: w * h * 4)
        
        guard let ctx = CGContext(
            data: &pixels, width: w, height: h,
            bitsPerComponent: 8, bytesPerRow: w * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        
        ctx.interpolationQuality = .medium
        ctx.draw(cgImage, in: CGRect(x: 0, y: 0, width: w, height: h))
        
        let cx = CGFloat(w - 1) / 2
        let cy = CGFloat(h - 1) / 2
        let maxDist = sqrt(cx * cx + cy * cy)
        
        var bestScore: CGFloat = -1
        var best = UIColor.gray
        
        for y in 0..<h {
            for x in 0..<w {
                let i = (y * w + x) * 4
                let a = CGFloat(pixels[i + 3]) / 255
                guard a > 0.5 else { continue }
                
                let r = CGFloat(pixels[i])     / 255
                let g = CGFloat(pixels[i + 1]) / 255
                let b = CGFloat(pixels[i + 2]) / 255
                
                let c = UIColor(red: r, green: g, blue: b, alpha: 1)
                var hue: CGFloat = 0, sat: CGFloat = 0, bri: CGFloat = 0, al: CGFloat = 0
                c.getHue(&hue, saturation: &sat, brightness: &bri, alpha: &al)
                
                let brightnessWeight = max(0, 1 - abs(bri - 0.55) * 1.5)
                
                let dx = CGFloat(x) - cx
                let dy = CGFloat(y) - cy
                let edgeWeight = sqrt(dx * dx + dy * dy) / maxDist
                
                let score = sat * brightnessWeight * edgeWeight
                
                if score > bestScore {
                    bestScore = score
                    best = c
                }
            }
        }
        
        var hue: CGFloat = 0, sat: CGFloat = 0, bri: CGFloat = 0, al: CGFloat = 0
        best.getHue(&hue, saturation: &sat, brightness: &bri, alpha: &al)
        return UIColor(hue: hue, saturation: min(1, max(sat, 0.4)), brightness: min(max(bri, 0.5), 0.85), alpha: 1)
    }
}
