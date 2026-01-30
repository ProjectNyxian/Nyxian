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

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
            updateBorderColor()
        }
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
        let languageMode = loadLanguage(language: tree_sitter_c(), highlightsURL: ["\(Bundle.main.bundlePath)/TreeSitterC_TreeSitterC.bundle/queries/highlights.scm".URLGet()])
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
        theme.fontSize = UserDefaults.standard.object(forKey: "LDEFontSize") == nil ? 10.0 : CGFloat(UserDefaults.standard.integer(forKey: "LDEFontSize"))
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
