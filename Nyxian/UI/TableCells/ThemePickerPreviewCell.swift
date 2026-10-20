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

import Runestone
import TreeSitter
import TreeSitterC
import UIKit

final class ThemePickerPreviewCell: UITableViewCell {
    let textView: TextView = {
        let settings = UserDefaults.standard
        let this = TextView()
        this.translatesAutoresizingMaskIntoConstraints = false
        return this
    }()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupView()
        setupLayout()
        registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (self: Self, previousTraitCollection: UITraitCollection) in
            self.updateBorderColor()
        }
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupView() {
        contentView.addSubview(textView)
        updateBorderColor()
    }

    private func setupLayout() {
        let heightConstraint = textView.heightAnchor.constraint(equalToConstant: 200)
        heightConstraint.priority = .defaultHigh
        NSLayoutConstraint.activate([
            textView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            textView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            textView.topAnchor.constraint(equalTo: contentView.topAnchor),
            textView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            heightConstraint
        ])
    }

    private func updateBorderColor() {
        layer.borderColor = UIColor.opaqueSeparator.cgColor
        layer.borderWidth = 1
    }
}

extension ThemePickerPreviewCell {
    struct ViewModel {
        let theme: LDETheme
        let text: String
    }
    
    func loadLanguage(language: UnsafePointer<TSLanguage>, highlightsURL: [URL]) -> TreeSitterLanguageMode {
        func combinedQuery(fromFilesAt fileURLs: [URL]) -> TreeSitterLanguage.Query? {
            let rawQuery = fileURLs.compactMap { try? String(contentsOf: $0) }.joined(separator: "\n")
            if !rawQuery.isEmpty {
                return TreeSitterLanguage.Query(string: rawQuery)
            } else {
                return nil
            }
        }
        
        let language = TreeSitterLanguage(language, highlightsQuery: combinedQuery(fromFilesAt: highlightsURL))
        let languageMode = TreeSitterLanguageMode(language: language)
        
        return languageMode
    }

    func populate(with viewModel: ViewModel) {
        let languageMode = loadLanguage(language: tree_sitter_c(), highlightsURL: [URL(fileURLWithPath:"\(Bundle.main.bundlePath)/TreeSitterC_TreeSitterC.bundle/queries/highlights.scm")])
        textView.setLanguageMode(languageMode)
        textView.theme = viewModel.theme
        textView.text = viewModel.text
        textView.backgroundColor = viewModel.theme.backgroundColor
        textView.insertionPointColor = viewModel.theme.textColor
        textView.selectionBarColor = viewModel.theme.textColor
        textView.selectionHighlightColor = viewModel.theme.textColor.withAlphaComponent(0.2)
        textView.textContainerInset = UIEdgeInsets(top: 4, left: 2, bottom: 4, right: 0)
        textView.isEditable = false
        textView.isSelectable = false
        textView.showLineNumbers = booleanDefaults(key: "LDEShowLineNumbers", defaultValue: true)
        textView.showSpaces = booleanDefaults(key: "LDEShowSpaces", defaultValue: true)
        textView.isLineWrappingEnabled = booleanDefaults(key: "LDEWrapLines", defaultValue: true)
        textView.showLineBreaks = booleanDefaults(key: "LDEShowLineBreaks", defaultValue: true)
        textView.lineSelectionDisplayType = .line
    }
    
    func switchTheme(theme: LDETheme) {
        textView.theme = theme
        textView.backgroundColor = theme.backgroundColor
        textView.insertionPointColor = theme.textColor
        textView.selectionBarColor = theme.textColor
        textView.selectionHighlightColor = theme.textColor.withAlphaComponent(0.2)
        textView.showLineNumbers = !textView.showLineNumbers /* hacky fix for the bug where font size doesnt update */
        textView.showLineNumbers = booleanDefaults(key: "LDEShowLineNumbers", defaultValue: true)
        textView.showSpaces = booleanDefaults(key: "LDEShowSpaces", defaultValue: true)
        textView.isLineWrappingEnabled = booleanDefaults(key: "LDEWrapLines", defaultValue: true)
        textView.showLineBreaks = booleanDefaults(key: "LDEShowLineBreaks", defaultValue: true)
        textView.lineSelectionDisplayType = .line
        textView.setNeedsLayout()
        textView.layoutIfNeeded()
    }
}
