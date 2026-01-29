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
import TreeSitter
import TreeSitterC
import TreeSitterObjc
import TreeSitterXML
import GameController

func booleanDefaults(key: String, defaultValue: Bool) -> Bool {
    if UserDefaults.standard.object(forKey: key) == nil {
        return defaultValue
    }
    return UserDefaults.standard.bool(forKey: key)
}

// MARK: - OnDissapear Container
class CodeEditorViewController: UIViewController {
    private(set) var path: String
    private(set) var textView: TextView
    private(set) var project: NXProject?
    private(set) var synpushServer: SynpushServer?
    private(set) var coordinator: Coordinator?
    private(set) var database: DebugDatabase?
    private(set) var line: UInt64?
    private(set) var column: UInt64?
    private(set) var floatingToolbar: UIToolbar?
    private(set) var floatingToolbarBottomConstraint: NSLayoutConstraint?
    
    init(
        project: NXProject?,
        path: String,
        line: UInt64? = nil,
        column: UInt64? = nil
    ) {
        self.path = path
        
        self.textView = TextView()
        
        self.project = project
        self.line = line
        self.column = column
        
        if let project = project {
            let cachePath = project.cachePath!
            
            self.database = DebugDatabase.getDatabase(ofPath: "\(cachePath)/debug.json")
            
            let suffix = self.path.URLGet().pathExtension
            if ["c", "m", "cpp", "mm", "h", "hpp"].contains(suffix) {
                project.projectConfig.reloadIfNeeded()
                var flags = project.projectConfig.generateCompilerFlags() as! [String]
                
                if suffix == "h" {
                    flags.append(contentsOf: ["-x", "objective-c"])
                } else if ["hpp","hh"].contains(suffix) {
                    flags.append(contentsOf: ["-x", "c++"])
                }
                
                self.synpushServer = SynpushServer(self.path, args: flags)
            }
        }
        
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        if #unavailable(iOS 26.0) {
            self.navigationController?.navigationBar.compactAppearance = currentNavigationBarAppearance
            self.navigationController?.navigationBar.scrollEdgeAppearance = currentNavigationBarAppearance
        }
        
        do {
            self.textView.text = try String(contentsOf: URL(fileURLWithPath: self.path), encoding: .utf8)
        } catch {
            if UIDevice.current.userInterfaceIdiom == .pad {
                // FIXME: Handle file closes
            } else {
                self.dismiss(animated: true)
            }
        }
        
        let fileURL = URL(fileURLWithPath: self.path)
        self.title = fileURL.lastPathComponent
        
        let saveButton: UIBarButtonItem = UIBarButtonItem()
        saveButton.tintColor = .label
        saveButton.title = "Save"
        saveButton.target = self
        saveButton.action = #selector(saveText)
        self.navigationItem.setRightBarButton(saveButton, animated: true)
        
        if UIDevice.current.userInterfaceIdiom != .pad {
            let closeButton: UIBarButtonItem = UIBarButtonItem()
            closeButton.tintColor = .label
            closeButton.title = "Close"
            closeButton.target = self
            closeButton.action = #selector(closeEditor)
            self.navigationItem.setLeftBarButton(closeButton, animated: true)
        }
        
        let theme: LDETheme = currentTheme ?? LDEThemeReader.shared.currentlySelectedTheme()
        theme.fontSize = UserDefaults.standard.object(forKey: "LDEFontSize") == nil ? 10.0 : CGFloat(UserDefaults.standard.integer(forKey: "LDEFontSize"))
            
        self.view.backgroundColor = .systemBackground
        self.textView.backgroundColor = theme.backgroundColor
        self.textView.theme = theme
            
        self.navigationController?.navigationBar.prefersLargeTitles = false
        self.navigationController?.navigationBar.standardAppearance = currentNavigationBarAppearance
        self.navigationController?.navigationBar.scrollEdgeAppearance = currentNavigationBarAppearance
        
        self.textView.showLineNumbers = booleanDefaults(key: "LDEShowLineNumbers", defaultValue: true)
        self.textView.showSpaces = booleanDefaults(key: "LDEShowSpaces", defaultValue: true)
        self.textView.isLineWrappingEnabled = booleanDefaults(key: "LDEWrapLines", defaultValue: true)
        self.textView.showLineBreaks = booleanDefaults(key: "LDEShowLineBreaks", defaultValue: true)
        self.textView.lineSelectionDisplayType = .line
        
        self.textView.showsHorizontalScrollIndicator = false;
        if #available(iOS 17.4, *) {
            self.textView.bouncesHorizontally = false
        }
        
        self.textView.lineHeightMultiplier = 1.3
        self.textView.keyboardType = .asciiCapable
        self.textView.smartQuotesType = .no
        self.textView.smartDashesType = .no
        self.textView.smartInsertDeleteType = .no
        self.textView.autocorrectionType = .no
        self.textView.autocapitalizationType = .none
        self.textView.textContainerInset = UIEdgeInsets(top: 2, left: 2, bottom: 2, right: 0)
        
        func loadLanguage(language: UnsafePointer<TSLanguage>, highlightsURL: [URL]) {
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
            
            self.textView.setLanguageMode(languageMode)
        }
        
        switch fileURL.pathExtension {
        case "m","h":
            loadLanguage(language: tree_sitter_objc(), highlightsURL: [
                "\(Bundle.main.bundlePath)/TreeSitterC_TreeSitterC.bundle/queries/highlights.scm".URLGet(),
                "\(Bundle.main.bundlePath)/Shared/ObjCFix/highlights.scm".URLGet()
            ])
            break
        case "c":
            loadLanguage(language: tree_sitter_c(), highlightsURL: [
                "\(Bundle.main.bundlePath)/TreeSitterC_TreeSitterC.bundle/queries/highlights.scm".URLGet()
            ])
            break
        case "xml","plist":
            loadLanguage(language: tree_sitter_xml(), highlightsURL: [
                "\(Bundle.main.bundlePath)/TreeSitterXML_TreeSitterXML.bundle/xml/highlights.scm".URLGet()
            ])
            break
        default:
            break
        }
            
        self.textView.translatesAutoresizingMaskIntoConstraints = false
        self.view.addSubview(textView)
        
        NSLayoutConstraint.activate([
            textView.topAnchor.constraint(equalTo: view.topAnchor),
            textView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            textView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            textView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
        
        if UIDevice.current.userInterfaceIdiom == .phone {
            self.setupToolbar(textView: self.textView)
        } else if #unavailable(iOS 26.0) {
            if GCKeyboard.coalesced == nil {
                self.setupToolbar(textView: self.textView)
            }
        }
        
        self.coordinator = Coordinator(parent: self)
        self.textView.editorDelegate = self.coordinator
        
        self.goto(line: line, column: column)
    }
    
    func goto(line: UInt64?, column: UInt64?) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            guard var line = line else { return }
            guard var column = column else { return }
            
            if line == 0 {
                return
            }
            
            line -= 1
            column -= 1
            
            let lines = self.textView.text.components(separatedBy: .newlines)
            guard line < lines.count else { return }

            let lineText = lines[Int(line)]
            let clampedColumn = min(Int(column), lineText.count)

            let offset = lines.prefix(Int(line)).reduce(0) { $0 + $1.count + 1 } + clampedColumn

            guard let rect = self.textView.rectForLine(Int(line)) else { return }

            let targetOffsetY = rect.origin.y - self.textView.textContainerInset.top
            let maxOffsetY = self.textView.contentSize.height - self.textView.bounds.height
            let clampedOffsetY = max(min(targetOffsetY, maxOffsetY), 0)

            let targetOffset = CGPoint(x: 0, y: clampedOffsetY)
            self.textView.setContentOffset(targetOffset, animated: true)

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                guard let start = self.textView.position(from: self.textView.beginningOfDocument, offset: offset) else { return }
                let range = self.textView.textRange(from: start, to: start)
                self.textView.selectedTextRange = range
                self.textView.becomeFirstResponder()
            }
        }
    }
    
    func setupToolbar(textView: TextView) {
        let theme: LDETheme = LDEThemeReader.shared.currentlySelectedTheme()
        
        func spawnSeperator() -> UIBarButtonItem {
            return UIBarButtonItem(customView: UIView(frame: CGRect(x: 0, y: 0, width: 5, height: 1)))
        }
        
        func getAdditionalButtons(buttons: [String]) -> [UIBarButtonItem] {
            var array: [UIBarButtonItem] = [spawnSeperator()]
            for button in buttons {
                array.append(contentsOf: [
                    UIBarButtonItem(customView: SymbolButton(symbolName: button, width: 25.0) {
                        textView.replace(textView.selectedTextRange!, withText: button)
                    }),
                    spawnSeperator()])
            }
            return array;
        }
        
        let tabBarButton = UIBarButtonItem(customView: SymbolButton(symbolName: "arrow.right.to.line", width: 35.0) {
            textView.replace(textView.selectedTextRange!, withText: "\t")
        })
        let hideBarButton = UIBarButtonItem(customView: SymbolButton(symbolName: "keyboard.chevron.compact.down", width: 35.0) {
            textView.resignFirstResponder()
        })
        
        var items: [UIBarButtonItem] = [
            tabBarButton,
            UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        ]
        
        if #unavailable(iOS 26.0) {
            items.append(contentsOf: getAdditionalButtons(buttons: ["(",")","{","}","[","]",";"]))
        }
        
        items.append(UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil))
        
        if #unavailable(iOS 26.0) {
            items.append(spawnSeperator())
        }
        
        items.append(hideBarButton)
        
        if #available(iOS 26.0, *) {
            textView.inputAccessoryView = nil
            let toolbar = UIToolbar()
            toolbar.translatesAutoresizingMaskIntoConstraints = false
            let appearance = UIToolbarAppearance()
            appearance.configureWithTransparentBackground()
            toolbar.standardAppearance = appearance
            toolbar.scrollEdgeAppearance = appearance
            
            toolbar.items = items
            toolbar.isHidden = true
            
            view.addSubview(toolbar)
            
            let bottomConstraint = toolbar.bottomAnchor.constraint(equalTo: view.bottomAnchor)
            NSLayoutConstraint.activate([
                toolbar.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 8),
                toolbar.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -8),
                toolbar.heightAnchor.constraint(equalToConstant: 50),
                bottomConstraint
            ])
            
            self.floatingToolbar = toolbar
            self.floatingToolbarBottomConstraint = bottomConstraint
        } else {
            let toolbar = UIToolbar()
            toolbar.sizeToFit()
            
            if #available(iOS 15.0, *) {
                let appearance = UIToolbarAppearance()
                appearance.configureWithOpaqueBackground()
                appearance.backgroundColor = theme.gutterBackgroundColor
                toolbar.standardAppearance = appearance
                toolbar.scrollEdgeAppearance = appearance
            } else {
                toolbar.barTintColor = theme.gutterBackgroundColor
            }
            
            toolbar.items = items
            textView.inputAccessoryView = toolbar
        }
    }

    @objc func keyboardWillShow(notification: NSNotification) {
        guard let userInfo = notification.userInfo,
              let keyboardFrame = userInfo[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect,
              let duration = userInfo[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double else { return }

        let bottomInset: CGFloat

        if #available(iOS 26.0, *), let floatingToolbar = self.floatingToolbar {
            bottomInset = (keyboardFrame.height - view.safeAreaInsets.bottom) + (floatingToolbar.frame.height + 10)
            floatingToolbar.isHidden = false
            floatingToolbarBottomConstraint?.constant = -(keyboardFrame.height + 8)
            UIView.animate(withDuration: duration) { self.view.layoutIfNeeded() }
        } else {
            bottomInset = keyboardFrame.height
        }

        textView.contentInset.bottom = bottomInset
        textView.verticalScrollIndicatorInsets.bottom = bottomInset
    }

    @objc func keyboardWillHide(notification: NSNotification) {
        guard let userInfo = notification.userInfo,
              let duration = userInfo[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double else {
            textView.contentInset = .zero
            textView.scrollIndicatorInsets = .zero
            return
        }

        textView.contentInset = .zero
        textView.verticalScrollIndicatorInsets = .zero

        if #available(iOS 26.0, *), let floatingToolbar = self.floatingToolbar {
            UIView.animate(withDuration: duration) {
                self.floatingToolbarBottomConstraint?.constant = 100
                self.view.layoutIfNeeded()
            } completion: { _ in
                floatingToolbar.isHidden = true
            }
        }
    }
    
    @objc func saveText() {
        defer {
            try? self.textView.text.write(to: URL(fileURLWithPath: self.path), atomically: true, encoding: .utf8)
        }
        
        guard let project = self.project,
              let database = self.database,
              let _ = self.synpushServer,
              let coordinator = self.coordinator else { return }
        
        database.setFileDebug(ofPath: self.path, synItems: coordinator.diag)
        database.saveDatabase(toPath: "\(project.cachePath!)/debug.json")
    }
    
    @objc func closeEditor() {
        NotificationCenter.default.post(name: Notification.Name("CodeEditorDismissed"), object: nil)
        self.dismiss(animated: true)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow), name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide), name: UIResponder.keyboardWillHideNotification, object: nil)
        
        if UIDevice.current.userInterfaceIdiom == .pad && self.textView.inputAccessoryView != nil {
            NotificationCenter.default.addObserver(self, selector: #selector(hardwareKeyboardDidConnect), name: .GCKeyboardDidConnect, object: nil)
            NotificationCenter.default.addObserver(self, selector: #selector(hardwareKeyboardDidDisconnect), name: .GCKeyboardDidDisconnect, object: nil)
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        NotificationCenter.default.removeObserver(self)
    }
    
    @objc private func hardwareKeyboardDidConnect(_ notification: Notification) {
        textView.inputAccessoryView = nil
        textView.reloadInputViews()
    }
        
    @objc private func hardwareKeyboardDidDisconnect(_ notification: Notification) {
        setupToolbar(textView: textView)
        textView.reloadInputViews()
    }
    
    override var keyCommands: [UIKeyCommand]? {
        return [
            UIKeyCommand(title: "Save File",
                         action: #selector(saveText),
                         input: "S",
                         modifierFlags: .command)
        ]
    }
}
