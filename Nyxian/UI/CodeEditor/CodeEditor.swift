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
    
    private(set) var undoButton: UIButton?
    private(set) var redoButton: UIButton?
    
    private(set) var autoindent: Bool = false
    
    let isReadOnly: Bool
    
    init(
        project: NXProject?,
        path: String,
        line: UInt64? = nil,
        column: UInt64? = nil,
        isReadOnly: Bool = false
    ) {
        self.path = path
        
        self.textView = TextView()
        
        self.project = project
        self.line = line
        self.column = column
        self.isReadOnly = isReadOnly
        
        if !isReadOnly {
            if let project = project {
                let cachePath = project.cachePath!
                
                self.database = DebugDatabase.getDatabase(ofPath: "\(cachePath)/debug.json")
                
                let suffix = self.path.URLGet().pathExtension
                if ["c", "m", "cpp", "mm", "h", "hpp"].contains(suffix) {
                    self.synpushServer = SynpushServer(self.path)
                }
            }
        } else {
            let suffix = self.path.URLGet().pathExtension
            if ["c", "m", "cpp", "mm", "h", "hpp"].contains(suffix) {
                self.synpushServer = SynpushServer(self.path)
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
        
        if !self.isReadOnly {
            let saveButton: UIBarButtonItem = UIBarButtonItem()
            saveButton.tintColor = .label
            
            if UIDevice.current.userInterfaceIdiom == .pad {
                saveButton.title = "Save (Cmd + S)"
            } else {
                saveButton.title = "Save"
            }
            saveButton.target = self
            saveButton.action = #selector(saveText)
            self.navigationItem.setRightBarButton(saveButton, animated: true)
        }
        
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
        
        if synpushServer != nil {
            self.autoindent = booleanDefaults(key: "LDEAutoindent", defaultValue: true)
        }
        
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
        self.textView.isEditable = !self.isReadOnly
        
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
            guard let line = line, line > 0 else { return }
            let column = column.map { $0 > 0 ? $0 - 1 : 0 } ?? 0

            let lines = self.textView.text.components(separatedBy: .newlines)
            guard Int(line) <= lines.count else { return }

            let lineText = lines[Int(line - 1)]
            let clampedColumn = min(Int(column), lineText.count)
            let offset = lines.prefix(Int(line - 1)).reduce(0) { $0 + $1.count + 1 } + clampedColumn

            guard let rect = self.textView.rectForLine(Int(line)) else { return }

            guard let start = self.textView.position(from: self.textView.beginningOfDocument, offset: offset) else { return }
            self.textView.selectedTextRange = self.textView.textRange(from: start, to: start)
            self.textView.becomeFirstResponder()

            let visibleRect = CGRect(
                x: self.textView.contentOffset.x,
                y: self.textView.contentOffset.y,
                width: self.textView.bounds.width,
                height: self.textView.bounds.height
            )

            guard !visibleRect.contains(rect) else {
                self.flashLine(rect: rect)
                return
            }

            let targetOffsetY = rect.origin.y - self.textView.textContainerInset.top
            let maxOffsetY = max(self.textView.contentSize.height - self.textView.bounds.height, 0)
            let clampedOffsetY = max(min(targetOffsetY, maxOffsetY), 0)

            self.textView.contentOffset = CGPoint(x: 0, y: clampedOffsetY)
            self.flashLine(rect: rect)
        }
    }

    private func flashLine(rect: CGRect) {
        let fullWidthRect = CGRect(x: 0, y: rect.origin.y, width: textView.bounds.width, height: rect.height)

        let path = UIBezierPath(roundedRect: fullWidthRect.insetBy(dx: 4, dy: 1), cornerRadius: 4)

        let flashLayer = CAShapeLayer()
        flashLayer.path = path.cgPath
        flashLayer.fillColor = UIColor.systemYellow.withAlphaComponent(0.45).cgColor
        flashLayer.strokeColor = UIColor.systemYellow.cgColor
        flashLayer.lineWidth = 1.5
        flashLayer.opacity = 0.0

        textView.layer.addSublayer(flashLayer)

        let pulse = CAKeyframeAnimation(keyPath: "opacity")
        pulse.values = [0.0, 1.0, 1.0, 0.0]
        pulse.keyTimes = [0, 0.1, 0.6, 1.0]
        pulse.duration = 1.4
        pulse.timingFunctions = [
            CAMediaTimingFunction(name: .easeIn),
            CAMediaTimingFunction(name: .linear),
            CAMediaTimingFunction(name: .easeOut)
        ]

        CATransaction.begin()
        CATransaction.setCompletionBlock {
            flashLayer.removeFromSuperlayer()
        }
        flashLayer.add(pulse, forKey: "flashPulse")
        CATransaction.commit()
    }
    
    func setupToolbar(textView: TextView) {
        let theme: LDETheme = LDEThemeReader.shared.currentlySelectedTheme()
        
        func spawnSeparator() -> UIBarButtonItem {
            let separator = UIBarButtonItem(barButtonSystemItem: .fixedSpace, target: nil, action: nil)
            separator.width = 5
            return separator
        }
        
        func getAdditionalButtons(buttons: [String]) -> [UIBarButtonItem] {
            var array: [UIBarButtonItem] = [spawnSeparator()]
            for button in buttons {
                array.append(contentsOf: [
                    UIBarButtonItem(customView: SymbolButton(symbolName: button, width: 25.0) {
                        textView.replace(textView.selectedTextRange!, withText: button)
                    }),
                    spawnSeparator()])
            }
            return array;
        }
        
        let tabBarButton = UIBarButtonItem(customView: SymbolButton(symbolName: "arrow.right.to.line", width: 35.0) {
            guard let selectedRange = textView.selectedTextRange else { return }
            
            if let selectedText = textView.text(in: selectedRange), !selectedText.isEmpty {
                let lines = selectedText.components(separatedBy: .newlines)
                let indentedText = lines
                    .map { "\t" + $0 }
                    .joined(separator: "\n")
                
                let startPosition = selectedRange.start
                
                textView.replace(selectedRange, withText: indentedText)
                
                if let newEnd = textView.position(from: startPosition, offset: indentedText.count) {
                    textView.selectedTextRange = textView.textRange(from: startPosition, to: newEnd)
                }
            } else {
                textView.replace(selectedRange, withText: "\t")
            }
        } longActionHandler: {
            guard let selectedRange = textView.selectedTextRange else { return }
            
            if let selectedText = textView.text(in: selectedRange), !selectedText.isEmpty {
                let lines = selectedText.components(separatedBy: .newlines)
                let unindentedText = lines
                    .map { line in
                        if line.hasPrefix("\t") {
                            return String(line.dropFirst())
                        }
                        return line
                    }
                    .joined(separator: "\n")
                
                let startPosition = selectedRange.start
                
                textView.replace(selectedRange, withText: unindentedText)
                
                if let newEnd = textView.position(from: startPosition, offset: unindentedText.count) {
                    textView.selectedTextRange = textView.textRange(from: startPosition, to: newEnd)
                }
            } else {
                if let previousPosition = textView.position(from: selectedRange.start, offset: -1),
                   let rangeToCheck = textView.textRange(from: previousPosition, to: selectedRange.start),
                   let textToCheck = textView.text(in: rangeToCheck),
                   textToCheck == "\t" {
                    textView.replace(rangeToCheck, withText: "")
                }
            }
        })
        
        let hideBarButton = UIBarButtonItem(customView: SymbolButton(symbolName: "keyboard.chevron.compact.down", width: 35.0) {
            textView.resignFirstResponder()
        })
        
        var items: [UIBarButtonItem] = [
            tabBarButton,
            UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        ]
        
        let undoButton = SymbolButton(symbolName: "arrow.uturn.left", width: 35.0) {
            textView.undoManager?.undo()
        }
        
        let redoButton = SymbolButton(symbolName: "arrow.uturn.right", width: 35.0) {
            textView.undoManager?.redo()
        }
        
        self.redoButton = redoButton
        self.undoButton = undoButton
        
        if #unavailable(iOS 26.0) {
            items.append(contentsOf: getAdditionalButtons(buttons: ["{","}","[","]",";"]))
            items.append(UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil))
            items.append(UIBarButtonItem(customView: undoButton))
            items.append(spawnSeparator())
            items.append(UIBarButtonItem(customView: redoButton))
        }
        
        items.append(UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil))
        
        if #unavailable(iOS 26.0) {
            items.append(spawnSeparator())
        } else {
            let undoRedoContainer = UIStackView()
            undoRedoContainer.axis = .horizontal
            undoRedoContainer.spacing = 8
            undoRedoContainer.alignment = .center
            undoRedoContainer.translatesAutoresizingMaskIntoConstraints = false

            NSLayoutConstraint.activate([
                undoRedoContainer.heightAnchor.constraint(equalToConstant: 35)
            ])

            let separator = UIView()
            separator.translatesAutoresizingMaskIntoConstraints = false
            separator.backgroundColor = UIColor.separator.withAlphaComponent(0.5)
            separator.layer.cornerRadius = 0.5
            NSLayoutConstraint.activate([
                separator.widthAnchor.constraint(equalToConstant: 1),
                separator.heightAnchor.constraint(equalToConstant: 20)
            ])

            undoRedoContainer.addArrangedSubview(undoButton)
            undoRedoContainer.addArrangedSubview(separator)
            undoRedoContainer.addArrangedSubview(redoButton)

            items.append(UIBarButtonItem(customView: undoRedoContainer))
            items.append(spawnSeparator())
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
                toolbar.backgroundColor = theme.gutterBackgroundColor
                toolbar.isTranslucent = false
            }
            
            toolbar.items = items
            textView.inputAccessoryView = toolbar
        }
        
        self.updateUndoRedoButtons()
    }

    @objc private func updateUndoRedoButtons() {
        guard let undoManager = textView.undoManager else { return }
        
        undoButton?.isEnabled = undoManager.canUndo
        redoButton?.isEnabled = undoManager.canRedo
        undoButton?.imageView?.alpha = undoManager.canUndo ? 1.0 : 0.5
        redoButton?.imageView?.alpha = undoManager.canRedo ? 1.0 : 0.5
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
        if !self.isReadOnly {
            defer {
                try? self.textView.text.write(to: URL(fileURLWithPath: self.path), atomically: true, encoding: .utf8)
            }
            
            showSaveAnimation()
            
            guard let project = self.project,
                  let database = self.database,
                  let _ = self.synpushServer,
                  let coordinator = self.coordinator else { return }
            
            database.setFileDebug(ofPath: self.path, synItems: coordinator.diag)
            database.saveDatabase(toPath: "\(project.cachePath!)/debug.json")
        }
    }
    
    private func showSaveAnimation() {
        if UIDevice.current.userInterfaceIdiom == .pad {
            let layer = view.layer
            
            let originalColor = layer.borderColor ?? UIColor.clear.cgColor
            
            let flashColor = UIColor.label.cgColor
            
            let animation = CABasicAnimation(keyPath: "borderColor")
            animation.fromValue = flashColor
            animation.toValue = originalColor
            animation.duration = 0.35
            animation.timingFunction = CAMediaTimingFunction(name: .easeOut)
            
            layer.borderColor = originalColor
            layer.add(animation, forKey: "saveFlash")
        }
    }
    
    @objc func closeEditor() {
        NotificationCenter.default.post(name: Notification.Name("CodeEditorDismissed"), object: nil)
        self.dismiss(animated: true)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow), name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide), name: UIResponder.keyboardWillHideNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(updateUndoRedoButtons), name: .NSUndoManagerDidUndoChange, object: textView.undoManager)
        NotificationCenter.default.addObserver(self, selector: #selector(updateUndoRedoButtons), name: .NSUndoManagerDidRedoChange, object: textView.undoManager)
        NotificationCenter.default.addObserver(self, selector: #selector(updateUndoRedoButtons), name: .NSUndoManagerDidCloseUndoGroup, object: textView.undoManager)
        
        if #unavailable(iOS 26.0) {
            if UIDevice.current.userInterfaceIdiom == .pad {
                NotificationCenter.default.addObserver(self, selector: #selector(hardwareKeyboardDidConnect), name: .GCKeyboardDidConnect, object: nil)
                NotificationCenter.default.addObserver(self, selector: #selector(hardwareKeyboardDidDisconnect), name: .GCKeyboardDidDisconnect, object: nil)
            }
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
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        /* pwerform hardware keyboard check */
        if GCKeyboard.coalesced != nil {
            self.textView.becomeFirstResponder()
        }
    }
    
    @objc func jumpToDefinition() {
        guard let server = synpushServer else { return }
        guard let selectedRange = textView.selectedTextRange else { return }
        
        DispatchQueue.global(qos: .userInitiated).async {
            let flags: [String] = self.isReadOnly ? NXProjectConfig.sdkCompilerFlags() as! [String] : self.project?.projectConfig.compilerFlags as! [String]
            server.reparseFile(self.textView.text, withArgs: flags)
            
            DispatchQueue.main.async {
                let cursorPosition = selectedRange.start
                let offset = self.textView.offset(from: self.textView.beginningOfDocument, to: cursorPosition)
                
                let text = self.textView.text
                let (line, column) = self.offsetToLineColumn(text: text, offset: offset)
                
                DispatchQueue.global(qos: .userInitiated).async {
                    guard let def = server.getDefinitionAtLine(UInt32(line), column: UInt32(column)) else {
                        DispatchQueue.main.async {
                            self.showNoDefinitionFound()
                        }
                        return
                    }
                    
                    DispatchQueue.main.async {
                        self.openDefinition(def)
                    }
                }
            }
        }
    }
    
    private func offsetToLineColumn(text: String, offset: Int) -> (line: Int, column: Int) {
        var currentOffset = 0
        var line = 1
        var column = 1
        
        for (i, char) in text.enumerated() {
            if i == offset { break }
            if char == "\n" {
                line += 1
                column = 1
            } else {
                column += 1
            }
            currentOffset += 1
        }
        
        return (line, column)
    }
    
    private func openDefinition(_ def: Syndef) {
        /* check if definition is in the same file */
        if def.filepath == self.path {
            self.goto(line: UInt64(def.line), column: UInt64(def.column))
            return
        }
        
        /* check if file actually exists (could be a sdk header) */
        let fileExists = FileManager.default.fileExists(atPath: def.filepath)
        
        if !fileExists {
            showNoDefinitionFound()
            return
        }
        
        /* open in a new read-only editor if its a system header, writable if its in the project */
        let isInsideProject: Bool
        if let project = self.project, let projectPath = project.path {
            isInsideProject = def.filepath.hasPrefix(projectPath)
        } else {
            isInsideProject = false
        }
        
        if UIDevice.current.userInterfaceIdiom != .pad {
            let destEditor = CodeEditorViewController(project: isInsideProject ? self.project : nil, path: def.filepath, line: UInt64(def.line), column: UInt64(def.column), isReadOnly: !isInsideProject)
            let destEditorNav = UINavigationController(rootViewController: destEditor)
            destEditorNav.modalPresentationStyle = .pageSheet
            self.present(destEditorNav, animated: true);
        } else {
            NotificationCenter.default.post(name: Notification.Name("FileListAct"), object: ["open",def.filepath,"\(def.line)","\(def.column)", isInsideProject ? "0" : "1"])
        }
    }
    
    private func showNoDefinitionFound() {
        let alert = UIAlertController(
            title: "No Definition Found",
            message: "Could not find a definition for the symbol at the cursor.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        self.present(alert, animated: true)
    }
    
    override func buildMenu(with builder: any UIMenuBuilder) {
        super.buildMenu(with: builder)
        
        guard self.synpushServer != nil else {
            return
        }
        
        let myAction = UIAction(title: "Jump To Definition", image: UIImage(systemName: "cursorarrow")) { _ in
            self.jumpToDefinition()
        }

        builder.insertChild(UIMenu(options: .displayInline, children: [myAction]), atEndOfMenu: .standardEdit)
    }
}
