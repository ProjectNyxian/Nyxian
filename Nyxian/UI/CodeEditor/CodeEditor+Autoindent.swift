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

import Runestone

extension Coordinator {
    func textView(_ textView: TextView,
                  shouldChangeTextIn range: NSRange,
                  replacementText text: String) -> Bool {
        guard !isAutoIndenting,
              self.parent?.autoindent ?? false else { return true }
        
        let nsText = textView.text as NSString
        
        let closingDelimiters: Set<Character> = ["}", ")", "]"]
        let closerToOpener: [Character: Character] = ["}": "{", ")": "(", "]": "["]
        
        if text.count == 1, let typedChar = text.first, closingDelimiters.contains(typedChar) {
            guard let opener = closerToOpener[typedChar] else { return true }
            
            let fullText = textView.text
            let insertionIdx = fullText.utf16.index(fullText.utf16.startIndex, offsetBy: range.location)
            let searchText = String(fullText.utf16[..<insertionIdx])!
            
            guard let matchIdx = findMatchingOpener(in: searchText, opener: opener, closer: typedChar) else { return true }
            
            let openerLine  = lineContaining(index: matchIdx, in: searchText)
            let targetIndent = String(openerLine.prefix(while: { $0 == "\t" }))
            
            let lineStart = currentLineStart(at: range.location, in: nsText)
            let currentLine = nsText.substring(with: NSRange(location: lineStart, length: range.location - lineStart))
            let existingIndent = String(currentLine.prefix(while: { $0 == "\t" }))
            
            guard existingIndent != targetIndent else { return true }
            
            let replaceRange = NSRange(location: lineStart, length: existingIndent.utf16.count)
            let replacement = targetIndent + text
            
            guard let startPos = textView.position(from: textView.beginningOfDocument, offset: replaceRange.location),
                  let endPos = textView.position(from: textView.beginningOfDocument, offset: replaceRange.location + replaceRange.length),
                  let textRange = textView.textRange(from: startPos, to: endPos) else { return true }
            
            isAutoIndenting = true
            textView.replace(textRange, withText: replacement)
            isAutoIndenting = false
            
            let newOffset = replaceRange.location + replacement.utf16.count
            if let pos = textView.position(from: textView.beginningOfDocument, offset: newOffset) {
                textView.selectedTextRange = textView.textRange(from: pos, to: pos)
            }
            
            return false
        }
        
        guard text == "\n" else { return true }
        
        let precedingText = nsText.substring(to: range.location)
        guard !isInsideStringLiteral(precedingText) else { return true }
        
        let lineStart = currentLineStart(at: range.location, in: nsText)
        let currentLine = nsText.substring(with: NSRange(location: lineStart, length: range.location - lineStart))
        
        let analysisLine = stripTrailingLineComment(currentLine)
        let trimmedBefore = analysisLine.trimmingCharacters(in: .whitespaces)
        let baseIndent = String(currentLine.prefix(while: { $0 == "\t" }))
        
        let lastChar = trimmedBefore.last
        let openerToCloser: [Character: Character] = ["{": "}", "(": ")", "[": "]"]
        let expectedCloser: Character? = lastChar.flatMap { openerToCloser[$0] }
        let opensBlock = lastChar == "{" || lastChar == "(" || lastChar == "["
        
        let charAfterCursor: Character? = range.location < nsText.length ? Character(UnicodeScalar(nsText.character(at: range.location))!) : nil
        
        var contentIndent = baseIndent
        if opensBlock { contentIndent += "\t" }
        
        let insertion: String
        let cursorOffset: Int
        
        if let closer = expectedCloser, charAfterCursor == closer {
            insertion = "\n" + contentIndent + "\n" + baseIndent
            cursorOffset = 1 + contentIndent.count
        } else {
            insertion = "\n" + contentIndent
            cursorOffset = insertion.count
        }
        
        guard let startPos = textView.position(from: textView.beginningOfDocument, offset: range.location),
              let endPos = textView.position(from: textView.beginningOfDocument, offset: range.location + range.length),
              let textRange = textView.textRange(from: startPos, to: endPos) else { return true }
        
        isAutoIndenting = true
        textView.replace(textRange, withText: insertion)
        isAutoIndenting = false
        
        let newOffset = range.location + cursorOffset
        if let pos = textView.position(from: textView.beginningOfDocument, offset: newOffset) {
            textView.selectedTextRange = textView.textRange(from: pos, to: pos)
        }
        
        return false
    }
    
    private func findMatchingOpener(in text: String, opener: Character, closer: Character) -> String.Index? {
        var depth = 0
        var idx = text.endIndex
        var inStr = false
        
        while idx > text.startIndex {
            text.formIndex(before: &idx)
            let ch = text[idx]
            
            if ch == "\"" {
                var bsCount = 0
                var bsIdx   = idx
                while bsIdx > text.startIndex {
                    text.formIndex(before: &bsIdx)
                    if text[bsIdx] == "\\" { bsCount += 1 } else { break }
                }
                if bsCount % 2 == 0 { inStr.toggle() }
                continue
            }
            
            guard !inStr else { continue }
            
            if ch == closer {
                depth += 1
            } else if ch == opener {
                if depth == 0 { return idx }
                depth -= 1
            }
        }
        return nil
    }
    
    private func currentLineStart(at location: Int, in nsText: NSString) -> Int {
        let preceding = nsText.substring(to: location)
        if let nl = preceding.lastIndex(of: "\n") {
            return preceding.distance(from: preceding.startIndex, to: nl) + 1
        }
        return 0
    }
    
    private func lineContaining(index: String.Index, in text: String) -> String {
        let lineStart = text[..<index].lastIndex(of: "\n").map {
            text.index(after: $0)
        } ?? text.startIndex

        let lineEnd = text[index...].firstIndex(of: "\n") ?? text.endIndex
        return String(text[lineStart..<lineEnd])
    }
    
    private func isInsideStringLiteral(_ text: String) -> Bool {
        var inside = false
        var idx = text.startIndex
        while idx < text.endIndex {
            let ch = text[idx]
            if ch == "\\" && inside {
                let next = text.index(after: idx)
                if next < text.endIndex { idx = text.index(after: next); continue }
            }
            if ch == "\"" { inside.toggle() }
            idx = text.index(after: idx)
        }
        return inside
    }
    
    private func stripTrailingLineComment(_ line: String) -> String {
        var inside = false
        var idx = line.startIndex
        while idx < line.endIndex {
            let ch = line[idx]
            if ch == "\\" && inside {
                let next = line.index(after: idx)
                if next < line.endIndex { idx = line.index(after: next); continue }
            }
            if ch == "\"" {
                inside.toggle()
            } else if ch == "/" && !inside {
                let next = line.index(after: idx)
                if next < line.endIndex && line[next] == "/" {
                    return String(line[..<idx])
                }
            }
            idx = line.index(after: idx)
        }
        return line
    }
}
