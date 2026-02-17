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

class MainSplitViewController: UISplitViewController, UISplitViewControllerDelegate {
    let project: NXProject
    var masterVC: FileListViewController?
    var detailVC: SplitScreenDetailViewController?
    var lock: NSLock = NSLock()
    
    init(project: NXProject) {
        self.project = project
        super.init(style: .doubleColumn)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.delegate = self
        
        masterVC = FileListViewController(project: project)
        detailVC = SplitScreenDetailViewController(project: project)

        if let masterVC = masterVC,
           let detailVC = detailVC {
            let masterNav = UINavigationController(rootViewController: masterVC)
            let detailNav = UINavigationController(rootViewController: detailVC)
            
            self.viewControllers = [masterNav,detailNav]
        }

        if #available(iOS 14.5, *) {
            self.displayModeButtonVisibility = .never
        }
        
        if #available(iOS 16.0, *),
           self.project.projectConfig.type == NXProjectType.app.rawValue
        {
            LDEBringApplicationSessionToFrontAssosiatedWithBundleIdentifier(self.project.projectConfig.bundleid)
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        NotificationCenter.default.addObserver(self, selector: #selector(invokeBuild), name: Notification.Name("RunAct"), object: nil)
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        NotificationCenter.default.removeObserver(self)
    }
    
    override var keyCommands: [UIKeyCommand]? {
        let closeCommand = UIKeyCommand(title: "Close", action: #selector(self.detailVC?.closeCurrentTab), input: "W", modifierFlags: [.command])
        let runCommand = UIKeyCommand(title: "Run", action: #selector(self.invokeBuild), input: "R", modifierFlags: [.command])
        
        if #available(iOS 15.0, *) {
            closeCommand.wantsPriorityOverSystemBehavior = true
        }
        
        return [closeCommand, runCommand]
    }
    
    @objc func invokeBuild() {
        if let masterVC = masterVC,
           let detailVC = detailVC,
           lock.try() {
            
            masterVC.navigationItem.leftBarButtonItem?.isEnabled = false
            self.detailVC?.logView?.clearConsole()
            
            buildProjectWithArgumentUI(targetViewController: detailVC, project: detailVC.project, buildType: .RunningApp, outPipe: self.detailVC?.logView?.pipe, inPipe: self.detailVC?.logView?.stdinPipe) { [weak self] in
                guard let self = self else { return }
                masterVC.navigationItem.leftBarButtonItem?.isEnabled = true
                self.lock.unlock()
            }
        }
    }
}

class SplitScreenDetailViewController: UIViewController {
    let project: NXProject
    
    var lock: NSLock = NSLock()
    
    var logViewTopConstraint: NSLayoutConstraint? = nil
    var logView: LogTextView?
    
    var childVCMasterConstraints: [NSLayoutConstraint]?
    var childVCMaster: UIViewController?
    var childVC: UIViewController? {
        get {
            childVCMaster
        }
        set {
            self.lock.lock()
            defer { self.lock.unlock() }
            
            if let oldVC = childVCMaster {
                if oldVC == newValue {
                    return
                }
                
                // Animate oldVC out
                UIView.animate(withDuration: 0.3, animations: {
                    oldVC.view.alpha = 0
                }, completion: { _ in
                    oldVC.view.removeFromSuperview()
                    oldVC.removeFromParent()
                })
            }
            
            // releasing memory of previous SynpushServer
            if let oldValue: CodeEditorViewController = childVCMaster as? CodeEditorViewController,
               let coordinator: Coordinator = oldValue.coordinator {
                coordinator.debounce?.invalidate()
                oldValue.synpushServer?.releaseMemory()
            }
            
            // trying to get old constraints
            if let oldConstraints = self.childVCMasterConstraints {
                NSLayoutConstraint.deactivate(oldConstraints)
            }
            
            if self.project.projectConfig.type == NXProjectType.app.rawValue {
                self.logViewTopConstraint?.isActive = true
            }
            
            // setting to new view controller
            childVCMaster = newValue
            
            // reevaluing SynpushServer
            if let newValue: CodeEditorViewController = newValue as? CodeEditorViewController {
                newValue.textView.textContainerInset = UIEdgeInsets(top: 5, left: 5, bottom: 5, right: 0)
                if let coordinator: Coordinator = newValue.coordinator {
                    coordinator.textViewDidChange(newValue.textView)
                }
            }
            
            if let vc = newValue {
                self.addChild(vc)
                vc.view.alpha = 0
                
                self.view.addSubview(vc.view)
                
                vc.view.translatesAutoresizingMaskIntoConstraints = false
                
                var constraints: [NSLayoutConstraint] = []
                
                if #available(iOS 26.0, *) {
                    vc.view.layer.cornerRadius = 20
                    vc.view.layer.cornerCurve = .continuous
                    vc.view.layer.borderWidth = 1.0
                    vc.view.layer.borderColor = currentTheme?.backgroundColor.cgColor ?? UIColor.white.withAlphaComponent(0.2).cgColor
                    vc.view.layer.masksToBounds = true
                    
                    constraints = [
                        vc.view.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
                        vc.view.bottomAnchor.constraint(equalTo: (self.project.projectConfig.type == NXProjectType.app.rawValue) ? logView!.topAnchor : view.bottomAnchor, constant: -16),
                        vc.view.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 16),
                        vc.view.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -16),
                    ]
                    
                    if self.project.projectConfig.type == NXProjectType.app.rawValue {
                        self.logViewTopConstraint?.isActive = false
                        
                        constraints.append(contentsOf: [
                            logView!.heightAnchor.constraint(equalToConstant: 300)
                        ])
                    }
                    
                    NSLayoutConstraint.activate(constraints)
                    
                    self.childVCMasterConstraints = constraints
                } else {
                    /*
                     * on iOS prior 26 we wont do anything
                     * floating cuz its not designed for it
                     */
                    constraints = [
                        vc.view.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
                        vc.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
                        vc.view.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
                        vc.view.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor)
                    ]
                    
                    NSLayoutConstraint.activate(constraints)
                    
                    self.childVCMasterConstraints = constraints
                }
                
                UIView.animate(withDuration: 0.3) {
                    vc.view.alpha = 1
                }
            }
        }
    }
    var childButton: UIButtonTab?
    
    private let scrollView = FileTabBar()
    private let tabBarView = UIView()
    private var stack: FileTabStack {
        get {
            scrollView.stackView
        }
    }
    private var tabs: [UIButtonTab] = []
    
    func openPath(path: String, line: UInt64, column: UInt64, isReadOnly: Bool) {
        if let existingTab = tabs.first(where: { $0.path == path }) {
            self.childButton = existingTab
            self.childVC = existingTab.vc
            (self.childVC as! CodeEditorViewController).goto(line: line, column: column)
            updateTabSelection(selectedTab: existingTab)
            return
        }
        
        let open: (UIButtonTab) -> Void = { [weak self] button in
            guard let self = self else { return }
            self.childButton = button
            self.childVC = button.vc
            self.updateTabSelection(selectedTab: button)
        }
        
        let close: (UIButtonTab) -> Void = { [weak self] button in
            guard let self = self else { return }
            
            let wasSelected = self.childButton == button
            
            if self.childVC == button.vc {
                self.childVC = nil
            }
            guard let index = self.tabs.firstIndex(of: button) else { return }
            
            button.removeTarget(nil, action: nil, for: .allEvents)
            
            self.scrollView.removeArrangedSubview(button)
            button.removeFromSuperview()
            self.tabs.remove(at: index)
            
            if wasSelected {
                var newSelectedTab: UIButtonTab? = nil
                if self.tabs.count > 0 {
                    if index < self.tabs.count {
                        newSelectedTab = self.tabs[index]
                    } else if index - 1 >= 0 {
                        newSelectedTab = self.tabs[index - 1]
                    }
                }
                
                if let tabToSelect = newSelectedTab {
                    self.childButton = tabToSelect
                    self.childVC = tabToSelect.vc
                    self.updateTabSelection(selectedTab: tabToSelect)
                } else {
                    self.childButton = nil
                    self.childVC = nil
                    self.updateTabSelection(selectedTab: nil)
                }
            } else {
                self.updateTabSelection(selectedTab: self.childButton)
            }
        }
        
        let button = UIButtonTab(frame: CGRect(x: 0, y: 0, width: 100, height: 100),
                                 project: self.project,
                                 path: path,
                                 line: line,
                                 column: column,
                                 openAction: open,
                                 closeAction: close,
                                 isReadOnly: isReadOnly)
        
        self.scrollView.addArrangedSubview(button)
        self.tabs.append(button)
        
        self.updateTabSelection(selectedTab: button)
    }
    
    func closeTab(path: String) {
        guard let button = tabs.first(where: { $0.path == path }) else { return }
        guard let index = tabs.firstIndex(of: button) else { return }
        
        button.removeTarget(nil, action: nil, for: .allEvents)
        
        scrollView.removeArrangedSubview(button)
        button.removeFromSuperview()
        tabs.remove(at: index)
        
        if childButton == button {
            childVC = nil
            childButton = nil
            
            var newSelectedTab: UIButtonTab? = nil
            if tabs.count > 0 {
                if index < tabs.count {
                    newSelectedTab = tabs[index]
                } else if index - 1 >= 0 {
                    newSelectedTab = tabs[index - 1]
                }
            }
            
            if let tabToSelect = newSelectedTab {
                childButton = tabToSelect
                childVC = tabToSelect.vc
                updateTabSelection(selectedTab: tabToSelect)
            } else {
                updateTabSelection(selectedTab: nil)
            }
        } else {
            updateTabSelection(selectedTab: childButton)
        }
    }
    
    /*
     Initial Class
     */
    init(project: NXProject) {
        self.project = project
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.view.backgroundColor = currentTheme?.gutterBackgroundColor
        
        if self.project.projectConfig.type == NXProjectType.app.rawValue {
            /* setting up logview */
            logView = LogTextView()
            logView!.isEditable = true
            logView!.isSelectable = true
            logView!.layer.cornerRadius = 20
            logView!.layer.cornerCurve = .continuous
            logView!.layer.borderWidth = 1.0
            logView!.layer.borderColor = currentTheme?.backgroundColor.cgColor ?? UIColor.white.withAlphaComponent(0.2).cgColor
            logView!.layer.masksToBounds = true
            logView!.translatesAutoresizingMaskIntoConstraints = false
            logView!.backgroundColor = currentTheme?.backgroundColor
            logView!.textColor = currentTheme?.textColor
            self.view.addSubview(logView!)
            
            self.logViewTopConstraint = logView!.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor)
            self.logViewTopConstraint?.isActive = true
            
            NSLayoutConstraint.activate([
                logView!.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 16),
                logView!.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -16),
                logView!.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -16)
            ])
        }
        
        self.navigationItem.titleView = self.scrollView
        
        var barButtons: [UIBarButtonItem] = []
        barButtons.append(UIBarButtonItem(image: UIImage(systemName: "play.fill"), primaryAction: UIAction { _ in
            NotificationCenter.default.post(name: NSNotification.Name("RunAct"), object: nil)
        }))
        if self.project.projectConfig.type == NXProjectType.app.rawValue {
            barButtons.append(UIBarButtonItem(image: UIImage(systemName: "archivebox.fill"), primaryAction: UIAction { [weak self] _ in
                guard let self = self else { return }
                buildProjectWithArgumentUI(targetViewController: self, project: self.project, buildType: .InstallPackagedApp)
            }))
        }
        barButtons.append(UIBarButtonItem(image: UIImage(systemName: "exclamationmark.triangle.fill"), primaryAction: UIAction { [weak self] _ in
            guard let self = self else { return }
            let loggerView = UINavigationController(rootViewController: UIDebugViewController(project: self.project))
            loggerView.modalPresentationStyle = .formSheet
            self.present(loggerView, animated: true)
        }))
        self.navigationItem.rightBarButtonItems = barButtons
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        NotificationCenter.default.addObserver(self, selector: #selector(handleMyNotification(_:)), name: Notification.Name("FileListAct"), object: nil)
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        NotificationCenter.default.removeObserver(self)
    }
    
    @objc func handleMyNotification(_ notification: Notification) {
        guard let args = notification.object as? [String] else { return }
        if args.count > 1 {
            switch(args[0]) {
            case "open":
                self.openPath(path: args[1], line: UInt64(args[2]) ?? 0, column: UInt64(args[3]) ?? 0, isReadOnly: (args.count >= 5 && args[4] == "1"))
                break
            case "close":
                self.closeTab(path: args[1])
                break
            default:
                break
            }
        }
    }
    
    private func updateTabSelection(selectedTab: UIButtonTab?) {
        let selectedColor: UIColor
        
        if #available(iOS 26.0, *) {
            selectedColor = currentTheme?.gutterBackgroundColor ?? UIColor.systemGray4
        } else {
            selectedColor = (currentTheme?.gutterBackgroundColor ?? UIColor.systemGray4).brighter(by: 10)
        }
        
        let unselectedColor: UIColor = .clear
        
        for tab in tabs {
            let targetColor: UIColor = (tab == selectedTab) ? selectedColor : unselectedColor
            UIView.animate(withDuration: 0.25) {
                tab.backgroundColor = targetColor
            }
        }
    }
    
    @objc func closeCurrentTab() {
        if let childButton = self.childButton {
            childButton.closeAction(childButton)
        }
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if let vc = childVCMaster {
            vc.view.layer.borderColor = currentTheme?.backgroundColor.cgColor ?? UIColor.white.withAlphaComponent(0.2).cgColor
        }
    }
}

class UIButtonTab: UIButton {
    let path: String
    let vc: CodeEditorViewController
    let closeAction: (UIButtonTab) -> Void
    
    init(frame: CGRect,
         project: NXProject,
         path: String,
         line: UInt64,
         column: UInt64,
         openAction: @escaping (UIButtonTab) -> Void,
         closeAction: @escaping (UIButtonTab) -> Void,
         isReadOnly: Bool) {
        self.path = path
        self.vc = CodeEditorViewController(project: project, path: path, line: line, column: column, isReadOnly: isReadOnly)
        self.closeAction = closeAction
        
        super.init(frame: frame)
        
        self.translatesAutoresizingMaskIntoConstraints = false;
        
        NSLayoutConstraint.activate([
            self.heightAnchor.constraint(equalToConstant: 30)
        ])
        
        self.contentEdgeInsets = UIEdgeInsets(top: 0, left: 32, bottom: 0, right: 10)
        self.setTitle(vc.path.URLGet().lastPathComponent, for: .normal)
        self.setTitleColor(currentTheme?.textColor, for: .normal)
        self.titleLabel?.font = .systemFont(ofSize: 13)
        self.contentHorizontalAlignment = .center
        self.contentVerticalAlignment = .center
        self.titleLabel?.textAlignment = .center
        
        if #available(iOS 26.0, *) {
            self.layer.cornerRadius = 15
            self.layer.cornerCurve = .continuous
        } else {
            self.layer.cornerRadius = 10
            self.layer.cornerCurve = .continuous
        }
        
        self.layer.masksToBounds = true
        
        self.addAction(UIAction { [weak self] _ in
            guard let s = self else { return }
            openAction(s)
        }, for: .touchUpInside)
        
        let ext = URL(fileURLWithPath: path).pathExtension.lowercased()
        
        let iconImageView: UIImageView = UIImageView()
        iconImageView.translatesAutoresizingMaskIntoConstraints = false
        iconImageView.contentMode = .center
        iconImageView.clipsToBounds = true
        self.addSubview(iconImageView)
        
        NSLayoutConstraint.activate([
            iconImageView.centerYAnchor.constraint(equalTo: self.centerYAnchor),
            iconImageView.leadingAnchor.constraint(equalTo: self.leadingAnchor, constant: 5),
            iconImageView.heightAnchor.constraint(equalTo: self.heightAnchor, constant: -10),
            iconImageView.widthAnchor.constraint(equalTo: iconImageView.heightAnchor)
        ])
        
        let label = UILabel()
        label.font = .systemFont(ofSize: 15, weight: .light)
        label.translatesAutoresizingMaskIntoConstraints = false
        label.textAlignment = .center
        
        switch ext {
        case "c":
            label.text = "c"
            label.textColor = .systemBlue
            iconImageView.addSubview(label)
        case "h":
            label.text = "h"
            label.textColor = .systemGray
            iconImageView.addSubview(label)
        case "cpp":
            FileListViewController.addStackedLabel(to: iconImageView, base: "c", offset: CGPoint(x: 8, y: -5), color: .systemBlue)
        case "hpp":
            FileListViewController.addStackedLabel(to: iconImageView, base: "h", offset: CGPoint(x: 8, y: -5), color: .systemBlue)
        case "m":
            label.text = "m"
            label.textColor = .systemPurple
            iconImageView.addSubview(label)
        case "mm":
            FileListViewController.addStackedLabel(to: iconImageView, base: "m", offset: CGPoint(x: 9, y: -6), color: .systemBlue)
        case "plist":
            FileListViewController.addSystemImage(to: iconImageView, name: "tablecells.fill", height: 13)
        case "zip","tar","zst":
            FileListViewController.addSystemImage(to: iconImageView, name: "doc.fill", height: 13)
        case "ipa":
            FileListViewController.addSystemImage(to: iconImageView, name: "app.gift.fill", height: 13)
        case "png","jpg","jpeg","gif","svg":
            FileListViewController.addSystemImage(to: iconImageView, name: "photo.fill")
        default:
            if #unavailable(iOS 17.0) {
                FileListViewController.addSystemImage(to: iconImageView, name: "text.alignleft")
            } else {
                FileListViewController.addSystemImage(to: iconImageView, name: "text.page.fill")
            }
        }
        
        if label.superview != nil {
            NSLayoutConstraint.activate([
                label.centerXAnchor.constraint(equalTo: iconImageView.centerXAnchor),
                label.centerYAnchor.constraint(equalTo: iconImageView.centerYAnchor),
                label.heightAnchor.constraint(equalTo: iconImageView.heightAnchor),
                label.widthAnchor.constraint(equalTo: iconImageView.heightAnchor)
            ])
        }
        
        // Open before making the menu
        openAction(self)
        
        // Making menu
        var items: [UIMenuElement] = []
        var buttons: [UIBarButtonItem] = []
        for item in vc.navigationItem.rightBarButtonItems ?? [] {
            if let title = item.title {
                items.append(UIAction(title: title, image: item.image, handler: { [weak self] _ in
                    guard let s = self else { return }
                    s.vc.perform(item.action)
                }))
            } else {
                buttons.append(item)
            }
        }
        
        let contextMenu = UIMenu(options: .displayInline, children: [
            UIMenu(options: .displayInline, children: items),
            UIMenu(options: .displayInline, children: [
                UIAction(title: "Close (Cmd + W)", handler: { [weak self] _ in
                    guard let s = self else { return }
                    closeAction(s)
                })
            ])
        ])
        
        self.storedMenu = contextMenu
        let menuInteraction = UIContextMenuInteraction(delegate: self)
        self.addInteraction(menuInteraction)
    }
    
    private var storedMenu: UIMenu?
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func contextMenuInteraction(_ interaction: UIContextMenuInteraction, configurationForMenuAtLocation location: CGPoint) -> UIContextMenuConfiguration? {
        return UIContextMenuConfiguration(identifier: nil, previewProvider: nil) { [weak self] _ in
            return self?.storedMenu
        }
    }
}

extension UIColor {
    func darker(by percentage: CGFloat = 30.0) -> UIColor {
        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        var alpha: CGFloat = 0

        guard self.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha) else {
            return self
        }

        let newBrightness = max(brightness - percentage/100, 0)
        return UIColor(hue: hue, saturation: saturation, brightness: newBrightness, alpha: alpha)
    }
    func brighter(by percentage: CGFloat = 30.0) -> UIColor {
        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        var alpha: CGFloat = 0
        
        guard self.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha) else {
            return self
        }
        
        let newBrightness = min(brightness + percentage/100, 1)
        return UIColor(hue: hue, saturation: saturation, brightness: newBrightness, alpha: alpha)
    }
}

