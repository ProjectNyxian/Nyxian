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

enum PosixSignal: CustomStringConvertible {
    case hangup
    case interrupt
    case quit
    case illegal
    case trap
    case abort
    case bus
    case fpe
    case kill
    case user1
    case segv
    case user2
    case pipe
    case alarm
    case terminate
    case child
    case cont
    case stop
    case tstp
    case ttin
    case ttou
    case urgent
    case xcpu
    case xfsz
    case vtalrm
    case prof
    case winch
    case sys
    
    var rawValue: Int32 {
        switch self {
            case .hangup: return SIGHUP
            case .interrupt: return SIGINT
            case .quit: return SIGQUIT
            case .illegal: return SIGILL
            case .trap: return SIGTRAP
            case .abort: return SIGABRT
            case .bus: return SIGBUS
            case .fpe: return SIGFPE
            case .kill: return SIGKILL
            case .user1: return SIGUSR1
            case .segv: return SIGSEGV
            case .user2: return SIGUSR2
            case .pipe: return SIGPIPE
            case .alarm: return SIGALRM
            case .terminate: return SIGTERM
            case .child: return SIGCHLD
            case .cont: return SIGCONT
            case .stop: return SIGSTOP
            case .tstp: return SIGTSTP
            case .ttin: return SIGTTIN
            case .ttou: return SIGTTOU
            case .urgent: return SIGURG
            case .xcpu: return SIGXCPU
            case .xfsz: return SIGXFSZ
            case .vtalrm: return SIGVTALRM
            case .prof: return SIGPROF
            case .winch: return SIGWINCH
            case .sys: return SIGSYS
        }
    }
    
    init?(rawValue: Int32) {
        switch rawValue {
            case SIGHUP: self = .hangup
            case SIGINT: self = .interrupt
            case SIGQUIT: self = .quit
            case SIGILL: self = .illegal
            case SIGTRAP: self = .trap
            case SIGABRT: self = .abort
            case SIGBUS: self = .bus
            case SIGFPE: self = .fpe
            case SIGKILL: self = .kill
            case SIGUSR1: self = .user1
            case SIGSEGV: self = .segv
            case SIGUSR2: self = .user2
            case SIGPIPE: self = .pipe
            case SIGALRM: self = .alarm
            case SIGTERM: self = .terminate
            case SIGCHLD: self = .child
            case SIGCONT: self = .cont
            case SIGSTOP: self = .stop
            case SIGTSTP: self = .tstp
            case SIGTTIN: self = .ttin
            case SIGTTOU: self = .ttou
            case SIGURG: self = .urgent
            case SIGXCPU: self = .xcpu
            case SIGXFSZ: self = .xfsz
            case SIGVTALRM: self = .vtalrm
            case SIGPROF: self = .prof
            case SIGWINCH: self = .winch
            case SIGSYS: self = .sys
            default: return nil
        }
    }

    var description: String {
        switch self {
            case .hangup: return "SIGHUP: Hangup detected on controlling terminal"
            case .interrupt: return "SIGINT: Interrupt from keyboard"
            case .quit: return "SIGQUIT: Quit from keyboard"
            case .illegal: return "SIGILL: Illegal Instruction"
            case .trap: return "SIGTRAP: Trace/breakpoint trap"
            case .abort: return "SIGABRT: Abort signal"
            case .bus: return "SIGBUS: Bus error (bad memory access)"
            case .fpe: return "SIGFPE: Floating-point exception"
            case .kill: return "SIGKILL: Kill signal (forced termination)"
            case .user1: return "SIGUSR1: User-defined signal 1"
            case .segv: return "SIGSEGV: Segmentation fault (invalid memory reference)"
            case .user2: return "SIGUSR2: User-defined signal 2"
            case .pipe: return "SIGPIPE: Broken pipe"
            case .alarm: return "SIGALRM: Timer signal from alarm()"
            case .terminate: return "SIGTERM: Termination signal"
            case .child: return "SIGCHLD: Child process stopped or terminated"
            case .cont: return "SIGCONT: Continue if stopped"
            case .stop: return "SIGSTOP: Stop process"
            case .tstp: return "SIGTSTP: Stop typed at terminal"
            case .ttin: return "SIGTTIN: Terminal input for background process"
            case .ttou: return "SIGTTOU: Terminal output for background process"
            case .urgent: return "SIGURG: Urgent condition on socket"
            case .xcpu: return "SIGXCPU: CPU time limit exceeded"
            case .xfsz: return "SIGXFSZ: File size limit exceeded"
            case .vtalrm: return "SIGVTALRM: Virtual alarm clock"
            case .prof: return "SIGPROF: Profiling timer expired"
            case .winch: return "SIGWINCH: Window resize signal"
            case .sys: return "SIGSYS: Bad system call"
        }
    }
}

class UIHitTestExtendedView: UIView {
    var hitTestInsets = UIEdgeInsets(top: -15, left: 0, bottom: -15, right: 0)

    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        // Too big fingers!!!
        let largerArea = bounds.inset(by: hitTestInsets)
        return largerArea.contains(point)
    }
}

class MainSplitViewController: UISplitViewController, UISplitViewControllerDelegate {
    let project: NXProject
    var masterVC: FileListViewController?
    var detailVC: SplitScreenDetailViewController?
    var lock: os_unfair_lock = os_unfair_lock()
    
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

        self.displayModeButtonVisibility = .never
        
        if self.project.projectConfig.schemeKind == .app {
            NXWindowSessionApplication.bringSessionToFront(withBundleIdentifier: self.project.projectConfig.bundleid)
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        NotificationCenter.default.addObserver(self, selector: #selector(invokeBuild), name: Notification.Name("RunAct"), object: nil)
        NXApplicationState.fileListRequiresToSendRequests = true
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        NotificationCenter.default.removeObserver(self)
        NXApplicationState.fileListRequiresToSendRequests = false
    }
    
    override var keyCommands: [UIKeyCommand]? {
        let closeCommand = UIKeyCommand(title: "Close", action: #selector(self.detailVC?.closeCurrentTab), input: "W", modifierFlags: [.command])
        let runCommand = UIKeyCommand(title: "Run", action: #selector(self.invokeBuild), input: "R", modifierFlags: [.command])
        
        closeCommand.wantsPriorityOverSystemBehavior = true
        
        return [closeCommand, runCommand]
    }
    
    @objc func invokeBuild() {
        NXDocumentManager.shared().saveAll { [weak self] in
            if let self = self,
               let masterVC = masterVC,
               let detailVC = detailVC,
               os_unfair_lock_trylock(&self.lock) {
                
                let project = detailVC.project
                
                masterVC.navigationItem.leftBarButtonItem?.isEnabled = false
                self.detailVC?.logView?.clearConsole()
                
                buildProjectWithArgumentUI(targetViewController: detailVC, project: project, buildType: .run) { [weak self] result, execPath in
                    if let process = detailVC.process {
                        process.remove(detailVC)
                        detailVC.process = nil
                    }
                    
                    guard let self = self else { return }
                    masterVC.navigationItem.leftBarButtonItem?.isEnabled = true
                    os_unfair_lock_unlock(&self.lock)
                    
                    if result {
                        let fileTable: PEFileTable = PEFileTable.empty()
                        
                        if let logView = detailVC.logView {
                            fileTable.appendFileDescriptor(logView.pipe.fileHandleForWriting.fileDescriptor, withMappingToLoc: STDOUT_FILENO)
                            fileTable.appendFileDescriptor(logView.pipe.fileHandleForWriting.fileDescriptor, withMappingToLoc: STDERR_FILENO)
                            fileTable.appendFileDescriptor(logView.stdinPipe.fileHandleForReading.fileDescriptor, withMappingToLoc: STDIN_FILENO)
                            
                            fileTable.appendFileDescriptor(logView.pipe.fileHandleForReading.fileDescriptor, withMappingToLoc: 100)
                            fileTable.appendFileDescriptor(logView.stdinPipe.fileHandleForWriting.fileDescriptor, withMappingToLoc: 101)
                        }
                        
                        var processIdentifier: pid_t = -1
                        
                        if project.projectConfig.schemeKind == .app {
                            processIdentifier = PEProcessManager.shared().spawnProcess(withBundleIdentifier: project.projectConfig.bundleid, withItems: ["PEFileTable":fileTable], withKernelSurfaceProcess: nil, doRestartIfRunning: true)
                        } else if project.projectConfig.schemeKind == .utility, let execPath = execPath {
                            guard let homePath: String = LDEApplicationWorkspace.shared().utilityHomePath() else {
                                return
                            }
                            
                            processIdentifier = PEProcessManager.shared().spawnProcess(withItems: [
                                "PEExecutablePath": execPath,
                                "PEArguments": [
                                    execPath
                                ],
                                "PEEnvironment": [
                                    "HOME": homePath,
                                    "CFFIXED_USER_HOME": homePath,
                                    "TMPDIR": (homePath as NSString).appendingPathComponent("/Tmp")
                                ],
                                "PEWorkingDirectory": homePath,
                                "PEFileTable": fileTable,
                            ], withKernelSurfaceProcess: nil)
                        }
                        
                        if processIdentifier > 0,
                           let process: PEProcess = PEProcessManager.shared().process(forProcessIdentifier: processIdentifier) {
                            process.add(detailVC)
                            detailVC.process = process
                        } else {
                            if let logView = detailVC.logView {
                                logView.writeMessage(toConsole: "failed to spawn process")
                            }
                        }
                    }
                }
            }
        }
    }
}

class SplitScreenDetailViewController: UIViewController, PEProcessObserver {
    let project: NXProject
    
    var lock: os_unfair_lock = os_unfair_lock()
    var process: PEProcess? = nil
    
    var logView: NXConsoleView?
    var logViewHeightConstraint: NSLayoutConstraint?
    var logViewHeight: CGFloat = 300
    let resizeHandle = {
        let logTopBorder = UIHitTestExtendedView()
        logTopBorder.translatesAutoresizingMaskIntoConstraints = false
        logTopBorder.backgroundColor = LDETheme.currentTheme?.gutterHairlineColor ?? UIColor.white.withAlphaComponent(0.2)
        return logTopBorder
    }()
    
    let emptyEditorVC: UIViewController = {
        let emptyEditorVC: UIViewController = UIViewController()
        emptyEditorVC.view.backgroundColor = LDETheme.currentTheme?.backgroundColor
        let label: UILabel = UILabel()
        label.text = "Empty Editor"
        label.translatesAutoresizingMaskIntoConstraints = false
        emptyEditorVC.view.addSubview(label)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: emptyEditorVC.view.safeAreaLayoutGuide.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: emptyEditorVC.view.safeAreaLayoutGuide.centerYAnchor)
        ])
        return emptyEditorVC
    }()
    
    var childVCMasterConstraints: [NSLayoutConstraint]?
    var childVCMaster: UIViewController?
    var childVC: UIViewController? {
        get {
            childVCMaster
        }
        set {
            os_unfair_lock_lock(&self.lock)
            defer { os_unfair_lock_unlock(&self.lock) }
            
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
            
            // trying to get old constraints
            if let oldConstraints = self.childVCMasterConstraints {
                NSLayoutConstraint.deactivate(oldConstraints)
            }
            
            // setting to new view controller
            childVCMaster = newValue
            
            let vc = newValue ?? self.emptyEditorVC
            self.addChild(vc)
            vc.view.alpha = 0
            self.view.addSubview(vc.view)
            
            vc.view.translatesAutoresizingMaskIntoConstraints = false
            
            let constraints: [NSLayoutConstraint] = {
                var isIOS26: Bool = false
                var isIOS27: Bool = false
                
                if #available(iOS 26.0, *) {
                    if #unavailable(iOS 27.0) {
                        isIOS26 = true
                    } else {
                        isIOS27 = true
                    }
                }
                
                let hconstrains: NSLayoutConstraint = logView!.heightAnchor.constraint(equalToConstant: logViewHeight)
                self.logViewHeightConstraint = hconstrains
                
                return [
                    vc.view.topAnchor.constraint(equalTo: isIOS27 ? view.topAnchor : view.safeAreaLayoutGuide.topAnchor),
                    vc.view.bottomAnchor.constraint(equalTo: logView!.topAnchor, constant: isIOS26 ? -16 : 0),
                    vc.view.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: isIOS26 ? 16 : 0),
                    vc.view.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: isIOS26 ? -16 : 0),
                    hconstrains
                ]
            }()
            
            if #available(iOS 27.0, *) {
                let leftEdge = UIView()
                leftEdge.translatesAutoresizingMaskIntoConstraints = false
                leftEdge.backgroundColor = LDETheme.currentTheme?.gutterHairlineColor ?? UIColor.white.withAlphaComponent(0.2)
                vc.view.addSubview(leftEdge)
                
                NSLayoutConstraint.activate([
                    leftEdge.leadingAnchor.constraint(equalTo: vc.view.leadingAnchor),
                    leftEdge.topAnchor.constraint(equalTo: vc.view.topAnchor),
                    leftEdge.bottomAnchor.constraint(equalTo: vc.view.bottomAnchor),
                    leftEdge.widthAnchor.constraint(equalToConstant: 0.5),
                ])
            } else if #available(iOS 26.0, *) {
                vc.view.layer.cornerRadius = 20
                vc.view.layer.cornerCurve = .continuous
                vc.view.layer.borderWidth = 1.0
                vc.view.layer.borderColor = LDETheme.currentTheme?.backgroundColor.cgColor ?? UIColor.white.withAlphaComponent(0.2).cgColor
                vc.view.layer.masksToBounds = true
            }
            
            self.childVCMasterConstraints = constraints
            NSLayoutConstraint.activate(constraints)
            
            UIView.animate(withDuration: 0.3) {
                vc.view.alpha = 1
            }
            
            self.view.bringSubviewToFront(self.resizeHandle)
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
    
    func openPath(url: URL, line: CFIndex, column: CFIndex, isReadOnly: Bool) {
        if let existingTab = tabs.first(where: { $0.url == url }) {
            self.childButton = existingTab
            self.childVC = existingTab.vc
            (self.childVC as! CodeEditorViewController).goto(location: MDKSourceLocationMake(line, column))
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
        
        guard let button = UIButtonTab(frame: CGRect(x: 0, y: 0, width: 100, height: 100),
                                       project: self.project,
                                       url: url,
                                       line: line,
                                       column: column,
                                       openAction: open,
                                       closeAction: close,
                                       isReadOnly: isReadOnly) else {
            return
        }
        
        self.scrollView.addArrangedSubview(button)
        self.tabs.append(button)
        
        self.updateTabSelection(selectedTab: button)
    }
    
    func closeTab(url: URL) {
        guard let button = tabs.first(where: { $0.url == url }) else { return }
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

    init(project: NXProject) {
        self.project = project
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.view.backgroundColor = LDETheme.currentTheme?.gutterBackgroundColor
        
        /* setting up logview */
        logView = NXConsoleView()
        logView!.isEditable = true
        logView!.isSelectable = true
        if #available(iOS 26.0, *) {
            if #unavailable(iOS 27.0) {
                logView!.layer.cornerRadius = 20
                logView!.layer.cornerCurve = .continuous
                logView!.layer.borderWidth = 1.0
                logView!.layer.borderColor = LDETheme.currentTheme?.gutterHairlineColor.cgColor ?? UIColor.white.withAlphaComponent(0.2).cgColor
                logView!.layer.masksToBounds = true
            }
        }
        logView!.translatesAutoresizingMaskIntoConstraints = false
        logView!.backgroundColor = LDETheme.currentTheme?.backgroundColor
        logView!.textColor = LDETheme.currentTheme?.textColor
        self.view.addSubview(logView!)
        
        if #available(iOS 27.0, *) {
            NSLayoutConstraint.activate([
                logView!.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
                logView!.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
                logView!.bottomAnchor.constraint(equalTo: view.bottomAnchor)
            ])
            
            let logLeftBorder = UIView()
            logLeftBorder.translatesAutoresizingMaskIntoConstraints = false
            logLeftBorder.backgroundColor = LDETheme.currentTheme?.gutterHairlineColor ?? UIColor.white.withAlphaComponent(0.2)
            self.view.addSubview(logLeftBorder)
            
            NSLayoutConstraint.activate([
                logLeftBorder.leadingAnchor.constraint(equalTo: logView!.leadingAnchor),
                logLeftBorder.topAnchor.constraint(equalTo: logView!.topAnchor),
                logLeftBorder.bottomAnchor.constraint(equalTo: logView!.bottomAnchor),
                logLeftBorder.widthAnchor.constraint(equalToConstant: 0.5)
            ])
        } else if #available(iOS 26.0, *) {
            NSLayoutConstraint.activate([
                logView!.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 16),
                logView!.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -16),
                logView!.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -16)
            ])
            
            self.resizeHandle.backgroundColor = .clear
        } else { // iOS 18 fallback
            NSLayoutConstraint.activate([
                logView!.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
                logView!.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
                logView!.bottomAnchor.constraint(equalTo: view.bottomAnchor)
            ])
        }
        
        self.view.addSubview(self.resizeHandle)
        
        NSLayoutConstraint.activate([
            self.resizeHandle.topAnchor.constraint(equalTo: logView!.topAnchor),
            self.resizeHandle.leadingAnchor.constraint(equalTo: logView!.leadingAnchor),
            self.resizeHandle.trailingAnchor.constraint(equalTo: logView!.trailingAnchor),
            self.resizeHandle.heightAnchor.constraint(equalToConstant: 0.5)
        ])
        
        let pan = UIPanGestureRecognizer(target: self, action: #selector(handleResizePan(_:)))
        resizeHandle.addGestureRecognizer(pan)
        
        self.navigationItem.titleView = self.scrollView
        
        var barButtons: [UIBarButtonItem] = []
        if !NXApplicationState.extensionLessMode {
            barButtons.append(UIBarButtonItem(image: UIImage(systemName: "play.fill"), primaryAction: UIAction { _ in
                NotificationCenter.default.post(name: NSNotification.Name("RunAct"), object: nil)
            }))
        }
        barButtons.append(UIBarButtonItem(image: UIImage(systemName: "archivebox.fill"), primaryAction: UIAction { [weak self] _ in
            guard let self = self else { return }
            buildProjectWithArgumentUI(targetViewController: self, project: self.project, buildType: .export)
        }))
        barButtons.append(UIBarButtonItem(image: UIImage(systemName: "exclamationmark.triangle.fill"), primaryAction: UIAction { [weak self] _ in
            guard let self = self else { return }
            let loggerView = UINavigationController(rootViewController: UIDebugViewController(project: self.project))
            loggerView.modalPresentationStyle = .formSheet
            self.present(loggerView, animated: true)
        }))
        self.navigationItem.rightBarButtonItems = barButtons
        
        childVC = nil
        
        registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (self: Self, previousTraitCollection: UITraitCollection) in
            if let vc = self.childVCMaster {
                vc.view.layer.borderColor = LDETheme.currentTheme?.backgroundColor.cgColor ?? UIColor.white.withAlphaComponent(0.2).cgColor
            }
            self.logView?.layer.borderColor = LDETheme.currentTheme?.backgroundColor.cgColor ?? UIColor.white.withAlphaComponent(0.2).cgColor
        }
    }
    
    @objc private func handleResizePan(_ gesture: UIPanGestureRecognizer) {
        let location = gesture.location(in: self.view)
        
        let minHeight: CGFloat = 80
        let maxHeight: CGFloat = self.view.bounds.height * 0.7
        
        let bottomEdge = self.view.bounds.height - 16
        let newHeight = bottomEdge - location.y
        
        logViewHeight = max(minHeight, min(maxHeight, newHeight))
        logViewHeightConstraint?.constant = logViewHeight
        
        UIView.animate(withDuration: 0.0) {
            self.view.layoutIfNeeded()
        }
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
                self.openPath(url: URL(fileURLWithPath: args[1]), line: CFIndex(args[2]) ?? 0, column: CFIndex(args[3]) ?? 0, isReadOnly: (args.count >= 5 && args[4] == "1"))
                break
            case "close":
                self.closeTab(url: URL(fileURLWithPath: args[1]))
                break
            default:
                break
            }
        }
    }
    
    private func updateTabSelection(selectedTab: UIButtonTab?) {
        let selectedColor: UIColor
        
        if #available(iOS 26.0, *) {
            selectedColor = LDETheme.currentTheme?.appTableCell ?? UIColor.systemGray2
        } else {
            selectedColor = LDETheme.currentTheme?.appTableCell ?? UIColor.systemGray2
        }
        
        let unselectedColor: UIColor = .clear
        
        for tab in tabs {
            let isSelected: Bool = (tab == selectedTab)
            let targetColor: UIColor = isSelected ? selectedColor : unselectedColor
            UIView.animate(withDuration: 0.25) {
                tab.backgroundColor = targetColor
                tab.setSelected(isSelected)
            }
        }
    }
    
    @objc func closeCurrentTab() {
        if let childButton = self.childButton {
            childButton.closeAction(childButton)
        }
    }
    
    func process(_ process: PEProcess!, didExitWithWait4Code code: Int32) {
        DispatchQueue.main.sync {
            if let logView = self.logView {
                let signalBits = code & 0x7F
                let isStopped = signalBits == 0x7F
                
                if signalBits == 0 {
                    let exitCode = (code >> 8) & 0xFF
                    logView.writeMessage(toConsole: "process did exit with code: \(exitCode)", with: exitCode == 0 ? .systemGreen : .systemRed)
                } else if !isStopped {
                    let signalNumber = signalBits
                    var color: UIColor = .systemYellow
                    if(signalNumber == 9) {
                        color = .systemRed
                    }
                    logView.writeMessage(toConsole: "process was killed by signal: \(signalNumber) (\(PosixSignal(rawValue: signalNumber)?.description ?? "SIGUNKNOWN"))", with: color)
                } else {
                    // IDK how this would happen
                    let stopSignal = (code >> 8) & 0xFF
                    logView.writeMessage(toConsole: "process was stopped by signal: \(stopSignal) (\(PosixSignal(rawValue: stopSignal)?.description ?? "SIGUNKNOWN"))", with: .yellow)
                }
            }
        }
    }
}

class UIButtonTab: UIButton {
    var url: URL {
        get {
            self.vc.file.fileURL
        }
    }
    let vc: CodeEditorViewController
    let closeAction: (UIButtonTab) -> Void
    
    private var closeButton: UIButton?
    private let fileIcon: FileIcon
    
    init?(frame: CGRect,
          project: NXProject,
          url: URL,
          line: CFIndex,
          column: CFIndex,
          openAction: @escaping (UIButtonTab) -> Void,
          closeAction: @escaping (UIButtonTab) -> Void,
          isReadOnly: Bool) {
        
        guard let codeEditor = CodeEditorViewController(project: project, url: url, line: line, column: column, isReadOnly: isReadOnly) else {
            return nil
        }
        
        self.vc = codeEditor
        self.closeAction = closeAction
        
        self.fileIcon = FileIcon(withFontSize: 15)
        
        super.init(frame: frame)
        
        self.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            self.heightAnchor.constraint(equalToConstant: 30)
        ])
        
        self.setTitle(self.url.lastPathComponent, for: .normal)
        self.setTitleColor(LDETheme.currentTheme?.textColor, for: .normal)
        self.titleLabel?.font = .systemFont(ofSize: 13)
        self.contentHorizontalAlignment = .center
        self.contentVerticalAlignment = .center
        self.titleLabel?.textAlignment = .center
        
        if #available(iOS 26.0, *) {
            self.layer.cornerRadius = 13
            self.layer.cornerCurve = .continuous
        } else {
            self.layer.cornerRadius = 10
            self.layer.cornerCurve = .continuous
        }
        
        self.layer.masksToBounds = true
        
        fileIcon.translatesAutoresizingMaskIntoConstraints = false
        self.addSubview(fileIcon)
        NSLayoutConstraint.activate([
            fileIcon.centerYAnchor.constraint(equalTo: self.centerYAnchor),
            fileIcon.leadingAnchor.constraint(equalTo: self.leadingAnchor, constant: 5),
            fileIcon.heightAnchor.constraint(equalTo: self.heightAnchor, constant: -10),
            fileIcon.widthAnchor.constraint(equalTo: fileIcon.heightAnchor)
        ])
        
        fileIcon.configure(with: FileListEntry(name: self.url.lastPathComponent, path: self.url.path, isLink: false, type: .file))
        
        self.addAction(UIAction { [weak self] _ in
            guard let s = self else { return }
            openAction(s)
        }, for: .touchUpInside)
        
        openAction(self)
        
        self.contentEdgeInsets = UIEdgeInsets(top: 0, left: 32, bottom: 0, right: 28) // make room for close button
        
        let closeButton = UIButton(type: .system)
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        closeButton.setImage(UIImage(systemName: "xmark.circle.fill", withConfiguration: UIImage.SymbolConfiguration(pointSize: 10, weight: .medium)), for: .normal)
        closeButton.tintColor = LDETheme.currentTheme?.textColor.withAlphaComponent(0.6)
        closeButton.addAction(UIAction { [weak self] _ in
            guard let s = self else { return }
            closeAction(s)
        }, for: .touchUpInside)
        
        self.addSubview(closeButton)
        NSLayoutConstraint.activate([
            closeButton.centerYAnchor.constraint(equalTo: self.centerYAnchor),
            closeButton.trailingAnchor.constraint(equalTo: self.trailingAnchor, constant: -6),
            closeButton.widthAnchor.constraint(equalToConstant: 18),
            closeButton.heightAnchor.constraint(equalToConstant: 18)
        ])
        self.closeButton = closeButton
    }
    
    func setSelected(_ selected: Bool) {
        self.closeButton?.isHidden = !selected
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
