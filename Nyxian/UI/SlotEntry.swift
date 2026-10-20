/*
 SPDX-License-Identifier: LicenseRef-EPSL-1.1

 Copyright (C) 2026 Kyle-Ye
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
import UIOnboarding

// Let me cry alone :<
@_cdecl("NXSlotMain")
public func NXSlotMain() -> UnsafeMutableRawPointer? {
    let defaults = UserDefaults.standard
    
    let enforcement: PEEnforcementMode
    switch defaults.string(forKey: "nyxian.boot.entitlements.mode") {
    case "permissive": enforcement = .permissive
    case "disabled": enforcement = .disabled
    default: enforcement = .enforcing
    }
    
    if !trust_enforcement_set_mode(enforcement) {
        assertionFailure("trust_enforcement_mode() was read before trust_enforcement_set_mode()")
    }
    
    if !klog_set_obfuscation(defaults.bool(forKey: "nyxian.boot.log.obfuscated")) {
        assertionFailure("klog_obfuscation_enabled() was read before klog_set_obfuscation()")
    }
    
    NXApplicationState.loadKernelExtensions = defaults.bool(forKey: "nyxian.boot.kextLoading")
    
    PEUserspaceManager.shared().boot(withKextLoadingEnabled: NXApplicationState.loadKernelExtensions)
    NXBootstrap.shared().bootstrap()
    
    _ = UIViewController.swizzlePresentAndDismissOnce
    _ = UIBarButtonItem.swizzleBarButtonitem
    RevertUI()
    
    let root = SlotCoordinator.shared.makeRootViewController()
    return Unmanaged.passRetained(root).toOpaque()
}

@_cdecl("NXSlotCreateWindow")
public func NXSlotCreateWindow(_ scenePtr: UnsafeMutableRawPointer) -> UnsafeMutableRawPointer? {
    let scene = Unmanaged<UIWindowScene>.fromOpaque(scenePtr).takeUnretainedValue()
    guard let window = NXWindowServer.shared(with: scene) else { return nil }
    return Unmanaged.passRetained(window).toOpaque()
}

@_cdecl("NXSlotDidAppear")
public func NXSlotDidAppear() {
    SlotCoordinator.shared.didAppear()
}

@objc class NXApplicationState: NSObject {
    @objc static var extensionExists: Bool = {
        return PEGetLiveProcessBundle() != nil
    }()
    
    @objc static var extensionCorrectlyEntitled: Bool = {
        return PEExtensionHasGetTaskAllowed()
    }()
    
    @objc static var extensionLessMode: Bool = {
        return !extensionExists || !extensionCorrectlyEntitled;
    }()
    
    private static var actualLoadKernelExtensions: Bool = false
    @objc static var loadKernelExtensions: Bool {
        get {
            if UserDefaults.standard.bool(forKey: "LDEDisableKernelExtensionsForce") {
                UserDefaults.standard.removeObject(forKey: "LDEDisableKernelExtensionsForce")
                return false
            }
            return self.actualLoadKernelExtensions;
        }
        set {
            if UserDefaults.standard.bool(forKey: "LDEDisableKernelExtensionsForce") {
                return
            }
            actualLoadKernelExtensions = newValue
        }
    }
    
    @objc static var fileListRequiresToSendRequests: Bool = false
    
    @objc static func restartAppWithoutKEXTLoadingEnabled() {
        UserDefaults.standard.set(true, forKey: "LDEDisableKernelExtensionsForce")
        PERestartSelf()
    }
}

final class SlotCoordinator: NSObject, UITabBarControllerDelegate, UIOnboardingViewControllerDelegate {
    static let shared = SlotCoordinator()
    
    private weak var tabController: UITabBarController?
    
    func makeRootViewController() -> UIViewController {
        let themedTabViewController = NXUITabBarController()
        
        let contentNavigationController = UINavigationController(rootViewController: ContentViewController())
        let settingsNavigationController = UINavigationController(rootViewController: NXSettingsTableViewController())
        
        contentNavigationController.tabBarItem = UITabBarItem(title: "Projects", image: UIImage(systemName: "square.grid.2x2.fill"), tag: 0)
        settingsNavigationController.tabBarItem = UITabBarItem(title: "Settings", image: UIImage(systemName: "gear"), tag: 1)
        
        var viewControllers: [UIViewController] = [contentNavigationController, settingsNavigationController]
        
        if UIDevice.current.userInterfaceIdiom == .phone {
            if #available(iOS 26.0, *) {
                if !NXApplicationState.extensionLessMode {
                    let fakeViewController = UIViewController()
                    fakeViewController.tabBarItem = UITabBarItem(tabBarSystemItem: .search, tag: 2)
                    fakeViewController.tabBarItem.title = "Switcher"
                    fakeViewController.tabBarItem.image = UIImage(systemName: "iphone.app.switcher")
                    viewControllers.append(fakeViewController)
                }
            }
        }
        
        themedTabViewController.viewControllers = viewControllers
        themedTabViewController.delegate = self
        tabController = themedTabViewController
        return themedTabViewController
    }
    
    func didAppear() {
        if UserDefaults.standard.object(forKey: "NXOnboardingSentinel") is NSNumber {
            checkSigningSetup()
            return
        }
        
        guard let tabController else { return }
        
        let onboardingConfiguration = UIOnboardingViewConfiguration(
            appIcon: UIOnboardingHelper.setUpIcon(),
            firstTitleLine: UIOnboardingHelper.setUpFirstTitleLine(),
            secondTitleLine: UIOnboardingHelper.setUpSecondTitleLine(),
            features: UIOnboardingHelper.setUpFeatures(),
            textViewConfiguration: UIOnboardingHelper.setUpNotice(),
            buttonConfiguration: UIOnboardingHelper.setUpButton())
        let onboardingController = UIOnboardingViewController(withConfiguration: onboardingConfiguration)
        onboardingController.delegate = self
        onboardingController.backgroundColor = LDETheme.currentTheme!.backgroundColor
        onboardingController.modalTransitionStyle = .crossDissolve
        
        tabController.present(onboardingController, animated: true)
    }
    
    func tabBarController(_ tabBarController: UITabBarController, shouldSelect viewController: UIViewController) -> Bool {
        if tabBarController.selectedViewController === viewController && NXBuilder.builds {
            return false
        }
        if viewController.tabBarItem.tag == 2 {
            NXWindowServer.shared().showAppSwitcherExternal()
            return false
        }
        return true
    }
    
    func didFinishOnboarding(onboardingViewController: UIOnboarding.UIOnboardingViewController) {
        onboardingViewController.modalTransitionStyle = .crossDissolve
        onboardingViewController.dismiss(animated: true, completion: nil)
        
        UserDefaults.standard.set(NSNumber(booleanLiteral: true), forKey: "NXOnboardingSentinel")
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            checkSigningSetup()
        }
    }
}

struct UIOnboardingHelper {
    static func setUpIcon() -> UIImage {
        if #unavailable(iOS 26.0) {
            return .init(named: "IconPreviewDefaultOld")!
        } else {
            let object = LDEApplicationObject(nsBundle: Bundle.main)!
            return Gib26Icon(object.icon, object.darkIcon, CGSize(width: 1024, height: 1024), UIScreen.main.scale)
        }
    }
    
    static func setUpFirstTitleLine() -> NSMutableAttributedString {
        .init(string: "Welcome to", attributes: [.foregroundColor: UIColor.label])
    }
    
    static func setUpSecondTitleLine() -> NSMutableAttributedString {
        .init(string: Bundle.main.displayName ?? "Nyxian", attributes: [
            .foregroundColor: UIColor { trait in trait.userInterfaceStyle == .dark ? UIColor(red: 0.79, green: 0.66, blue: 0.89, alpha: 1.0) : UIColor(red: 0.62, green: 0.48, blue: 0.78, alpha: 1.0) }
        ])
    }
    
    static func setUpFeatures() -> Array<UIOnboardingFeature> {
        return .init([
            .init(icon: UIImage(systemName: "hammer.fill")!,
                  iconTint: UIColor { trait in trait.userInterfaceStyle == .dark ? UIColor(red: 0.55, green: 0.78, blue: 0.98, alpha: 1.0) : UIColor(red: 0.30, green: 0.58, blue: 0.88, alpha: 1.0) },
                  title: "Development",
                  description: "A full development environment supporting Swift, C, C++, Objective-C and Objective-C++ that runs on any iOS 18.0+ iPhone or iPad."),
            .init(icon: UIImage(systemName: "wrench.and.screwdriver.fill")!,
                  iconTint: UIColor { trait in trait.userInterfaceStyle == .dark ? UIColor(red: 0.78, green: 0.71, blue: 0.95, alpha: 1.0) : UIColor(red: 0.55, green: 0.45, blue: 0.85, alpha: 1.0) },
                  title: "MobileDevelopmentKit",
                  description: "A completely FOSS LLVM, Swift, Clang, and LLD toolchain running natively on iOS, powering compilation and linkage completely on-device without any overpriced cloud services or subscriptions."),
            .init(icon: UIImage(systemName: "cpu.fill")!,
                  iconTint: UIColor { trait in trait.userInterfaceStyle == .dark ? UIColor(red: 0.60, green: 0.88, blue: 0.80, alpha: 1.0) : UIColor(red: 0.30, green: 0.68, blue: 0.58, alpha: 1.0) },
                  title: "Native Performance",
                  description: "A custom micro kernel called ksurface providing real process management, mach IPC(task ports through task_for_pid() for example), POSIX semantics, custom kernel extensions so you can extend ksurface your self and even a shimcache so you can add more rebinds in the userspace to syscalls you or someone else fixed and that directly on your restricted iOS device for your projects."),
            .init(icon: UIImage(systemName: "exclamationmark.triangle.fill")!,
                  iconTint: UIColor { trait in trait.userInterfaceStyle == .dark ? UIColor(red: 0.98, green: 0.82, blue: 0.45, alpha: 1.0) : UIColor(red: 0.85, green: 0.60, blue: 0.12, alpha: 1.0) },
                  title: "Warning",
                  description: "This is a beta version of Nyxian, so don't expect a product without bugs, please be kind and respectful, it is very hard to develop this kind of software. Please report any kinds of issues and ask any question over at our github we have a lot of time and passion answering your questions and making Nyxian better."),
        ])
    }
    
    static func setUpNotice() -> UIOnboardingTextViewConfiguration {
        return .init(icon: UIImage(systemName: "heart.fill")!,
                     text: "Contributions, feedback, and stars keep the project alive.",
                     linkTitle: "Contribute on GitHub",
                     link: "https://github.com/emexlab/Nyxian",
                     linkColor: UIColor { trait in trait.userInterfaceStyle == .dark ? UIColor(red: 0.79, green: 0.66, blue: 0.89, alpha: 1.0) : UIColor(red: 0.62, green: 0.48, blue: 0.78, alpha: 1.0) })
    }
    
    static func setUpButton() -> UIOnboardingButtonConfiguration {
        let lightBackground = LDETheme.currentTheme!.backgroundColor.resolvedColor(with: .init(userInterfaceStyle: .light))
        
        return .init(title: "Continue", titleColor: lightBackground, backgroundColor: UIColor { trait in trait.userInterfaceStyle == .dark ? UIColor(red: 0.79, green: 0.66, blue: 0.89, alpha: 1.0) : UIColor(red: 0.62, green: 0.48, blue: 0.78, alpha: 1.0) })
    }
}
