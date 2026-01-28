/*
 Copyright (C) 2026 cr4zyengineer

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

class FileTabStack: UIStackView {
    init() {
        super.init(frame: .zero)
        setupView()
    }
    
    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupView() {
        self.axis = .horizontal
        self.alignment = .center
        self.distribution = .fillProportionally
        self.spacing = 0
        
        setContentHuggingPriority(.defaultLow, for: .horizontal)
        setContentCompressionResistancePriority(.required, for: .horizontal)
    }
    
    private func createSpacer(width: CGFloat) -> UIView {
        let spacer = UIView()
        spacer.backgroundColor = .clear
        spacer.translatesAutoresizingMaskIntoConstraints = false
        spacer.tag = 9999
        
        NSLayoutConstraint.activate([
            spacer.widthAnchor.constraint(equalToConstant: width),
            spacer.heightAnchor.constraint(equalToConstant: 24)
        ])
        
        return spacer
    }
    
    private func createSeparator() -> UIView {
        let separator = UIView()
        separator.backgroundColor = currentTheme?.gutterHairlineColor ?? UIColor.separator
        separator.translatesAutoresizingMaskIntoConstraints = false
        separator.tag = 8888
        
        NSLayoutConstraint.activate([
            separator.widthAnchor.constraint(equalToConstant: 1),
            separator.heightAnchor.constraint(equalToConstant: 24)
        ])
        
        return separator
    }
    
    private var tabCount: Int {
        return arrangedSubviews.filter { $0.tag != 9999 && $0.tag != 8888 }.count
    }
    
    override func addArrangedSubview(_ view: UIView) {
        if let last = arrangedSubviews.last, last.tag == 9999 {
            super.removeArrangedSubview(last)
            last.removeFromSuperview()
        }
        
        if tabCount == 0 {
            super.addArrangedSubview(createSpacer(width: 12))
        }
        
        if tabCount > 0 {
            super.addArrangedSubview(createSpacer(width: 8))
            super.addArrangedSubview(createSeparator())
            super.addArrangedSubview(createSpacer(width: 8))
        }
        
        super.addArrangedSubview(view)
        super.addArrangedSubview(createSpacer(width: 12))
    }
    
    override func removeArrangedSubview(_ view: UIView) {
        if view.tag == 9999 || view.tag == 8888 {
            super.removeArrangedSubview(view)
            return
        }
        
        guard let index = arrangedSubviews.firstIndex(of: view) else { return }
        
        super.removeArrangedSubview(view)
        view.removeFromSuperview()
        
        var viewsToRemove: [UIView] = []
        
        if tabCount == 0 {
            viewsToRemove = arrangedSubviews.filter { $0.tag == 9999 || $0.tag == 8888 }
        } else if tabCount == 1 {
            for subview in arrangedSubviews {
                if subview.tag == 8888 {
                    viewsToRemove.append(subview)
                    if let idx = arrangedSubviews.firstIndex(of: subview) {
                        if idx > 0 {
                            let before = arrangedSubviews[idx - 1]
                            if before.tag == 9999 && before.constraints.contains(where: { $0.constant == 8 }) {
                                viewsToRemove.append(before)
                            }
                        }
                        if idx < arrangedSubviews.count - 1 {
                            let after = arrangedSubviews[idx + 1]
                            if after.tag == 9999 && after.constraints.contains(where: { $0.constant == 8 }) {
                                viewsToRemove.append(after)
                            }
                        }
                    }
                }
            }
        } else {
            var idx = index - 1
            while idx >= 0 && viewsToRemove.count < 3 {
                let subview = arrangedSubviews[idx]
                if subview.tag == 9999 || subview.tag == 8888 {
                    viewsToRemove.insert(subview, at: 0)
                } else {
                    break
                }
                idx -= 1
            }
            
            if viewsToRemove.count < 3 {
                viewsToRemove.removeAll()
                idx = index
                while idx < arrangedSubviews.count && viewsToRemove.count < 3 {
                    let subview = arrangedSubviews[idx]
                    if subview.tag == 9999 || subview.tag == 8888 {
                        viewsToRemove.append(subview)
                    } else {
                        break
                    }
                    idx += 1
                }
            }
        }
        
        for subview in viewsToRemove {
            super.removeArrangedSubview(subview)
            subview.removeFromSuperview()
        }
    }
    
    override var intrinsicContentSize: CGSize {
        let width = arrangedSubviews.reduce(0) { $0 + $1.intrinsicContentSize.width }
        return CGSize(width: max(width, 100), height: 44)
    }
}

class FileTabBar: UIVisualEffectView {
    private let scrollView: UIScrollView
    private let stack: FileTabStack
    
    init() {
        self.stack = FileTabStack()
        self.scrollView = UIScrollView()
        if #available(iOS 26.0, *) {
            super.init(effect: UIGlassEffect(style: .regular))
        } else {
            super.init(effect: UIBlurEffect(style: .systemMaterial))
        }
        setupView()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupView() {
        if #available(iOS 26.0, *) {
            self.layer.cornerRadius = 20
            self.layer.cornerCurve = .continuous
        } else {
            self.layer.cornerRadius = 12
            self.layer.cornerCurve = .continuous
            self.layer.borderWidth = 0.5
            self.layer.borderColor = UIColor.white.withAlphaComponent(0.2).cgColor
            self.layer.shadowColor = UIColor.black.cgColor
            self.layer.shadowOpacity = 0.1
            self.layer.shadowOffset = CGSize(width: 0, height: 2)
            self.layer.shadowRadius = 4
        }
        
        self.translatesAutoresizingMaskIntoConstraints = false
        self.clipsToBounds = true
        
        self.scrollView.backgroundColor = UIColor.clear
        self.scrollView.showsHorizontalScrollIndicator = false
        self.scrollView.showsVerticalScrollIndicator = false
        self.scrollView.isScrollEnabled = true
        self.scrollView.translatesAutoresizingMaskIntoConstraints = false
        self.contentView.addSubview(self.scrollView)
        
        self.stack.translatesAutoresizingMaskIntoConstraints = false
        self.scrollView.addSubview(self.stack)
        
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: contentView.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            scrollView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            
            stack.topAnchor.constraint(equalTo: scrollView.topAnchor),
            stack.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            stack.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            stack.heightAnchor.constraint(equalToConstant: 44),
            
            stack.heightAnchor.constraint(equalTo: scrollView.heightAnchor)
        ])
    }
    
    func addTab(_ tab: UIView) {
        stack.addArrangedSubview(tab)
        layoutIfNeeded()
    }
    
    func removeTab(_ tab: UIView) {
        stack.removeArrangedSubview(tab)
        tab.removeFromSuperview()
        layoutIfNeeded()
    }
    
    var stackView: FileTabStack {
        return stack
    }
    
    override var intrinsicContentSize: CGSize {
        return CGSize(width: UIView.noIntrinsicMetric, height: 44)
    }
}
