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

func ldeThemeColorGen(colorEntry: [String:Any]) -> UIColor {
    // Get light and dark mode
    let light: [String:Int] = colorEntry["light"] as! [String:Int];
    let dark: [String:Int] = colorEntry["dark"] as! [String:Int];
    
    // Now forcefully!
    return UIColor(light: (CGFloat(light["red"]!), CGFloat(light["green"]!), CGFloat(light["blue"]!)), dark: (CGFloat(dark["red"]!), CGFloat(dark["green"]!), CGFloat(dark["blue"]!)), alpha: Double(light["alpha"]!))
}

class LDETheme: Theme {
    var fontSize: CGFloat = CGFloat(UserDefaults.standard.double(forKey: "CEFontSize"))
    
    var font: UIFont {
        return UIFont.monospacedSystemFont(ofSize: fontSize, weight: .medium)
    }
    
    var lineNumberFont: UIFont {
        return UIFont.monospacedSystemFont(ofSize: fontSize * 0.85, weight: .regular)
    }
    
    let name: String
    let textColor: UIColor
    let backgroundColor: UIColor
    
    let gutterBackgroundColor: UIColor
    let gutterHairlineColor: UIColor
    
    let lineNumberColor: UIColor
    
    let selectedLineBackgroundColor: UIColor
    let selectedLinesLineNumberColor: UIColor
    let selectedLinesGutterBackgroundColor: UIColor
    
    var invisibleCharactersColor: UIColor {
        return textColor.withAlphaComponent(0.25)
    }
    
    let pageGuideHairlineColor: UIColor
    let pageGuideBackgroundColor: UIColor
    
    let markedTextBackgroundColor: UIColor
    let colorKeyword: UIColor
    let colorComment: UIColor
    let colorString: UIColor
    let colorNumber: UIColor
    let colorRegex: UIColor
    let colorFunction: UIColor
    let colorOperator: UIColor
    let colorProperty: UIColor
    let colorPunctuation: UIColor
    let colorDirective: UIColor
    let colorType: UIColor
    let colorConstantBuiltin: UIColor
    let colorMethod: UIColor
    let colorVariable: UIColor
    let colorParameter: UIColor
    let colorNamespace: UIColor
    let colorAttribute: UIColor
    let colorInclude: UIColor
    
    let appLabel: UIColor
    let appTableView: UIColor
    let appTableCell: UIColor
    
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
            selectedLineBackgroundColor = ldeThemeColorGen(colorEntry: theme["selectedLineBackground"] as! [String:Any])
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
