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

class KernelLogViewController: UIViewController {

    private let scrollView: UIScrollView = {
        let sv = UIScrollView()
        sv.translatesAutoresizingMaskIntoConstraints = false
        sv.alwaysBounceHorizontal = true
        sv.alwaysBounceVertical = true
        sv.showsHorizontalScrollIndicator = true
        sv.showsVerticalScrollIndicator = true
        return sv
    }()

    private let label: UILabel = {
        let lbl = UILabel()
        lbl.font = UIFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        lbl.numberOfLines = 0
        lbl.lineBreakMode = .byClipping
        lbl.translatesAutoresizingMaskIntoConstraints = false
        return lbl
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Kernel Log"
        view.backgroundColor = .systemBackground

        setupLayout()
        setupNavigationItems()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        refreshLog()
    }

    private func setupLayout() {
        view.addSubview(scrollView)
        scrollView.addSubview(label)
        
        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            label.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            label.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            label.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            label.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor)
        ])
    }

    private func setupNavigationItems() {
        navigationItem.rightBarButtonItems = [
            UIBarButtonItem(title: "Copy",
                            style: .plain,
                            target: self,
                            action: #selector(copyLog)),
            UIBarButtonItem(title: "Refresh",
                            style: .plain,
                            target: self,
                            action: #selector(refreshLog))
        ]
    }

    @objc private func refreshLog() {
        if let log = klog_dump() {
            label.text = log as String
        } else {
            label.text = "Kernel logging disabled."
        }
        self.scrollView.layoutSubviews()
    }

    @objc private func copyLog() {
        UIPasteboard.general.string = label.text
        let alert = UIAlertController(title: "Copied",
                                      message: "The log has been copied to the clipboard.",
                                      preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}
