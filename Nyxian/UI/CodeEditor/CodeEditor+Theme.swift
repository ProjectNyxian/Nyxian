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

import UIKit
import Runestone

enum HighlightName: String {
    case comment
    case constantBuiltin = "constant.builtin"
    case constantCharacter = "constant.character"
    case constantMacro = "constant.macro"
    case constructor
    case function
    case functionBuiltin = "function.builtin"
    case functionMacro = "function.macro"
    case functionMacroBuiltin = "function.macro.builtin"
    case include
    case keyword
    case keywordCoroutine = "keyword.coroutine"
    case keywordFunction = "keyword.function"
    case keywordOperator = "keyword.operator"
    case method
    case methodCall = "method.call"
    case namespace
    case number
    case `operator`
    case parameter
    case parameterBuiltin = "parameter.builtin"
    case preproc
    case property
    case punctuation
    case punctuationBracket = "punctuation.bracket"
    case punctuationSpecial = "punctuation.special"
    case storageclass
    case string
    case stringSpecial = "string.special"
    case tag
    case type
    case typeBuiltin = "type.builtin"
    case typeQualifier = "type.qualifier"
    case variable
    case variableBuiltin = "variable.builtin"
    case attribute
    case exception
    case textUri = "text.uri"
    
    init?(_ rawHighlightName: String) {
        var comps = rawHighlightName.split(separator: ".")
        while !comps.isEmpty {
            let candidateRawHighlightName = comps.joined(separator: ".")
            if let highlightName = Self(rawValue: candidateRawHighlightName) {
                self = highlightName
                return
            }
            comps.removeLast()
        }
        return nil
    }
}


///
/// Functions to encode and decode Color as RGB String
///

func gibDynamicColor(light: UIColor, dark: UIColor) -> UIColor {
    return UIColor(dynamicProvider: { traits in
        switch traits.userInterfaceStyle {
        case .light, .unspecified:
            return light
            
        case .dark:
            return dark
            
        @unknown default:
            assertionFailure("Unknown userInterfaceStyle: \(traits.userInterfaceStyle)")
            return light
        }
    })
}

extension UIColor {
    convenience init(light: (CGFloat, CGFloat, CGFloat), dark: (CGFloat, CGFloat, CGFloat), alpha: Double = 1.0) {
        let light: UIColor = neoRGB(light.0, light.1, light.2).withAlphaComponent(alpha)
        let dark: UIColor = neoRGB(dark.0, dark.1, dark.2).withAlphaComponent(alpha)
        
        self.init(dynamicProvider: { traits in
            switch traits.userInterfaceStyle {
            case .light, .unspecified:
                return light
                
            case .dark:
                return dark
                
            @unknown default:
                assertionFailure("Unknown userInterfaceStyle: \(traits.userInterfaceStyle)")
                return light
            }
        })
    }
}

func neoRGB(_ red: CGFloat,_ green: CGFloat,_ blue: CGFloat ) -> UIColor {
    return UIColor(red: red/255.0, green: green/255.0, blue: blue/255.0, alpha: 1.0)
}

func ldeRGBStringToColor(_ str: String) -> UIColor {
    let parts = str.split(separator: ":").compactMap { Double($0) }
    guard parts.count == 3 else {
        assertionFailure("Malformed LDE color string: \(str)")
        return .clear
    }
    return neoRGB(parts[0], parts[1], parts[2])
}

func ldeThemeColorGen(colorEntry: Any) -> UIColor {
    // New format
    if let dict = colorEntry as? [String: String],
       let lightStr = dict["light"],
       let darkStr = dict["dark"] {
        return gibDynamicColor(
            light: ldeRGBStringToColor(lightStr),
            dark: ldeRGBStringToColor(darkStr)
        )
    }
    
    // Fallback to old format
    if let dict = colorEntry as? [String: Any],
       let light = dict["light"] as? [String: Int],
       let dark = dict["dark"] as? [String: Int] {
        return UIColor(
            light: (CGFloat(light["red"]!), CGFloat(light["green"]!), CGFloat(light["blue"]!)),
            dark:  (CGFloat(dark["red"]!),  CGFloat(dark["green"]!),  CGFloat(dark["blue"]!)),
            alpha: Double(light["alpha"] ?? 10) / 10.0
        )
    }
    
    assertionFailure("Unknown color entry format: \(colorEntry)")
    return .clear
}

@objc class LDETheme: NSObject, Theme {
    @objc static var currentTheme: LDETheme? = nil
    
    @objc var fontSize: CGFloat {
        return UserDefaults.standard.object(forKey: "LDEFontSize") == nil ? 12.0 : CGFloat(UserDefaults.standard.integer(forKey: "LDEFontSize"))
    }
    
    @objc var font: UIFont {
        return UIFont.monospacedSystemFont(ofSize: fontSize, weight: .semibold)
    }
    
    @objc var lineNumberFont: UIFont {
        return UIFont.monospacedSystemFont(ofSize: fontSize * 0.85, weight: .medium)
    }
    
    @objc let name: String
    @objc let textColor: UIColor
    @objc let backgroundColor: UIColor
    
    @objc let gutterBackgroundColor: UIColor
    @objc let gutterHairlineColor: UIColor
    
    @objc let lineNumberColor: UIColor
    
    @objc let selectedLineBackgroundColor: UIColor
    @objc let selectedLinesLineNumberColor: UIColor
    @objc let selectedLinesGutterBackgroundColor: UIColor
    
    @objc var invisibleCharactersColor: UIColor {
        return textColor.withAlphaComponent(0.25)
    }
    
    @objc let pageGuideHairlineColor: UIColor
    @objc let pageGuideBackgroundColor: UIColor
    
    @objc let markedTextBackgroundColor: UIColor
    @objc let colorKeyword: UIColor
    @objc let colorComment: UIColor
    @objc let colorString: UIColor
    @objc let colorNumber: UIColor
    @objc let colorRegex: UIColor
    @objc let colorFunction: UIColor
    @objc let colorOperator: UIColor
    @objc let colorProperty: UIColor
    @objc let colorPunctuation: UIColor
    @objc let colorDirective: UIColor
    @objc let colorType: UIColor
    @objc let colorConstantBuiltin: UIColor
    @objc let colorMethod: UIColor
    @objc let colorVariable: UIColor
    @objc let colorParameter: UIColor
    @objc let colorNamespace: UIColor
    @objc let colorAttribute: UIColor
    @objc let colorInclude: UIColor
    
    @objc let appLabel: UIColor
    @objc let appTableView: UIColor
    @objc let appTableCell: UIColor
    
    init?(plistPath: String) {
        // Gaining plist access
        if let data = try? Data(contentsOf: URL(fileURLWithPath: plistPath)),
           let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any] {
            // Now reading "LDEThemes dictionary"
            let theme: [String:Any] = plist["LDETheme"] as! [String:Any]
            let app: [String:Any] = theme["app"] as! [String:Any]
            let highlighting: [String:Any] = theme["highlighting"] as! [String:Any]
            
            name = URL(fileURLWithPath: plistPath).deletingPathExtension().lastPathComponent
            
            // First highlight
            colorKeyword = ldeThemeColorGen(colorEntry: highlighting["keyword"] as! [String:Any])
            colorComment = ldeThemeColorGen(colorEntry: highlighting["comment"] as! [String:Any])
            colorString = ldeThemeColorGen(colorEntry: highlighting["string"] as! [String:Any])
            colorNumber = ldeThemeColorGen(colorEntry: highlighting["number"] as! [String:Any])
            colorRegex = ldeThemeColorGen(colorEntry: highlighting["regex"] as! [String:Any])
            colorFunction = ldeThemeColorGen(colorEntry: highlighting["function"] as! [String:Any])
            colorOperator = ldeThemeColorGen(colorEntry: highlighting["operator"] as! [String:Any])
            colorProperty = ldeThemeColorGen(colorEntry: highlighting["property"] as! [String:Any])
            colorPunctuation = ldeThemeColorGen(colorEntry: highlighting["punctuation"] as! [String:Any])
            colorDirective = ldeThemeColorGen(colorEntry: highlighting["directive"] as! [String:Any])
            colorType = ldeThemeColorGen(colorEntry: highlighting["type"] as! [String:Any])
            colorConstantBuiltin = ldeThemeColorGen(colorEntry: highlighting["constant"] as! [String:Any])
            colorMethod = ldeThemeColorGen(colorEntry: highlighting["method"] as! [String:Any])
            colorVariable = ldeThemeColorGen(colorEntry: highlighting["variable"] as! [String:Any])
            colorParameter = ldeThemeColorGen(colorEntry: highlighting["parameter"] as! [String:Any])
            colorNamespace = ldeThemeColorGen(colorEntry: highlighting["namespace"] as! [String:Any])
            colorAttribute = ldeThemeColorGen(colorEntry: highlighting["attribute"] as! [String:Any])
            colorInclude = ldeThemeColorGen(colorEntry: highlighting["include"] as! [String:Any])
            
            // Now everything else
            textColor = ldeThemeColorGen(colorEntry: theme["text"] as! [String:Any])
            backgroundColor = ldeThemeColorGen(colorEntry: theme["background"] as! [String:Any])
            gutterBackgroundColor = ldeThemeColorGen(colorEntry: theme["gutterBackground"] as! [String:Any])
            gutterHairlineColor = ldeThemeColorGen(colorEntry: theme["gutterHairline"] as! [String:Any])
            lineNumberColor = ldeThemeColorGen(colorEntry: theme["lineNumber"] as! [String:Any])
            selectedLineBackgroundColor = (ldeThemeColorGen(colorEntry: theme["selectedLineBackground"] as! [String:Any])).withAlphaComponent(0.8)
            selectedLinesLineNumberColor = ldeThemeColorGen(colorEntry: theme["selectedLinesLineNumber"] as! [String:Any])
            selectedLinesGutterBackgroundColor = ldeThemeColorGen(colorEntry: theme["selectedLinesGutterBackground"] as! [String:Any])
            pageGuideHairlineColor = ldeThemeColorGen(colorEntry: theme["pageGuideHairline"] as! [String:Any])
            pageGuideBackgroundColor = ldeThemeColorGen(colorEntry: theme["pageGuideBackground"] as! [String:Any])
            markedTextBackgroundColor = ldeThemeColorGen(colorEntry: theme["markedTextBackground"] as! [String:Any])
            
            appLabel = ldeThemeColorGen(colorEntry: app["appLabel"] as! [String:Any])
            appTableView = ldeThemeColorGen(colorEntry: app["appTableViewBackground"] as! [String:Any])
            appTableCell = ldeThemeColorGen(colorEntry: app["appTableCellBackground"] as! [String:Any])
        } else {
            return nil
        }
    }
    
    func textColor(for highlightName: String) -> UIColor? {
        guard let highlightName = HighlightName(highlightName) else {
            return nil
        }
        switch highlightName {
        case .comment:
            return colorComment
        case .keyword, .keywordOperator, .keywordCoroutine, .storageclass, .exception:
            return colorKeyword
        case .keywordFunction:
            return colorPunctuation
        case .include, .preproc:
            return colorInclude
        case .type, .typeBuiltin, .typeQualifier:
            return colorType
        case .namespace:
            return colorNamespace
        case .function, .functionBuiltin, .functionMacro, .functionMacroBuiltin:
            return colorFunction
        case .method, .methodCall, .constructor:
            return colorMethod
        case .variable, .variableBuiltin:
            return colorVariable
        case .parameter, .parameterBuiltin:
            return colorParameter
        case .property:
            return colorProperty
        case .attribute:
            return colorAttribute
        case .string, .stringSpecial:
            return colorString
        case .number, .textUri:
            return colorNumber
        case .constantBuiltin, .constantCharacter, .constantMacro:
            return colorConstantBuiltin
        case .operator:
            return colorOperator
        case .punctuation, .punctuationBracket, .punctuationSpecial:
            return colorPunctuation
        case .tag:
            return colorString
        }
    }
    
    @objc static var current: LDETheme? {
        get {
            return currentTheme
        }
    }
}

class LDEThemeReader {
    static let shared: LDEThemeReader = LDEThemeReader()
    
    var themes: [LDETheme] = []
    
    var selectedThemeIndex: Int {
        get {
            return UserDefaults.standard.integer(forKey: "LDESelectedThemeIndex")
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "LDESelectedThemeIndex")
        }
    }
    
    init() {
        // Gaining plist access
        let path = "\(Bundle.main.bundlePath)/Shared/Themes/Themes.plist"
        if let data = try? Data(contentsOf: URL(fileURLWithPath: path)),
           let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any] {
            // Now reading "LDEThemes dictionary"
            let themesFiles: [String] = plist["LDEThemes"] as! [String]
            
            if(themesFiles.count < selectedThemeIndex) {
                selectedThemeIndex = 0
            }
            
            // Now loading each theme
            for file in themesFiles {
                themes.append(LDETheme(plistPath: "\(Bundle.main.bundlePath)/Shared/Themes/".appending(file))!)
            }
        }
    }
    
    func currentlySelectedTheme() -> LDETheme {
        return themes[selectedThemeIndex]
    }
}
