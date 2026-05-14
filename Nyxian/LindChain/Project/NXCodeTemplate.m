/*
 SPDX-License-Identifier: AGPL-3.0-or-later

 Copyright (C) 2025 - 2026 mach-port-t

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

#import <LindChain/Project/NXCodeTemplate.h>
#import <LindChain/Project/NXUser.h>
#import <LindChain/Project/NXUtils.h>

NSDictionary *NXCodeTemplateDirectory = nil;

__attribute__((constructor))
void init_codetemplates(void)
{
    NXCodeTemplateDirectory = @{
        NXProjectSchemeApp: @{
            NXProjectLanguageObjectiveC:@{
                NXProjectInterfaceUIKit: @{
                    @"AppDelegate.h": @"#ifndef APPDELEGATE_H\n#define APPDELEGATE_H\n\n#import <UIKit/UIKit.h>\n\n@interface AppDelegate : UIResponder <UIApplicationDelegate>\n@end\n\n#endif /* APPDELEGATE_H */\n",
                    @"AppDelegate.m": @"#import \"AppDelegate.h\"\n\n@implementation AppDelegate\n\n- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {\n\treturn YES;\n}\n\n@end\n",
                    @"Main.m": @"#import <UIKit/UIKit.h>\n#import \"AppDelegate.h\"\n\nint main(int argc, char * argv[]) {\n\t@autoreleasepool {\n\t\treturn UIApplicationMain(argc, argv, nil, NSStringFromClass([AppDelegate class]));\n\t}\n}\n",
                    @"SceneDelegate.h": @"#ifndef SCENEDELEGATE_H\n#define SCENEDELEGATE_H\n\n#import <UIKit/UIKit.h>\n\n@interface SceneDelegate : UIResponder <UIWindowSceneDelegate>\n\n@property (nonatomic, strong) UIWindow *window;\n\n@end\n\n#endif /* SCENEDELEGATE_H */\n",
                    @"SceneDelegate.m": @"#import \"SceneDelegate.h\"\n#import \"ViewController.h\"\n\n@implementation SceneDelegate\n\n- (void)scene:(UIScene *)scene willConnectToSession:(UISceneSession *)session options:(UISceneConnectionOptions *)connectionOptions {\n\tif(![scene isKindOfClass:[UIWindowScene class]]) return;\n\n\tUIWindowScene *windowScene = (UIWindowScene *)scene;\n\tself.window = [[UIWindow alloc] initWithWindowScene:windowScene];\n\n\tViewController *vc = [[ViewController alloc] init];\n\n\tself.window.rootViewController = vc;\n\t[self.window makeKeyAndVisible];\n}\n\n@end\n",
                    @"ViewController.h": @"#ifndef VIEWCONTROLLER_H\n#define VIEWCONTROLLER_H\n\n#import <UIKit/UIKit.h>\n\n@interface ViewController : UIViewController\n@end\n\n#endif /* VIEWCONTROLLER_H */\n",
                    @"ViewController.m": @"#import \"ViewController.h\"\n\n@implementation ViewController\n\n- (void)viewDidLoad {\n\t[super viewDidLoad];\n\n\tself.view.backgroundColor = [UIColor systemBackgroundColor];\n\n\tUIImageSymbolConfiguration *config = [UIImageSymbolConfiguration configurationWithScale:UIImageSymbolScaleLarge];\n\tUIImage *img = [[UIImage systemImageNamed:@\"globe\"] imageByApplyingSymbolConfiguration:config];\n\tUIImageView * globeView = [[UIImageView alloc] initWithImage:img];\n\tglobeView.tintColor = [UIColor systemBlueColor];\n\n\tUILabel *label = [[UILabel alloc] init];\n\tlabel.text = @\"Hello, world!\";\n\tlabel.textAlignment = NSTextAlignmentCenter;\n\tlabel.textColor = [UIColor labelColor];\n\n\tUIStackView *stackView = [[UIStackView alloc] initWithArrangedSubviews:@[globeView, label]];\n\tstackView.axis = UILayoutConstraintAxisVertical;\n\tstackView.distribution = UIStackViewDistributionEqualCentering;\n\tstackView.alignment = UIStackViewAlignmentCenter;\n\t[self.view addSubview:stackView];\n\tstackView.translatesAutoresizingMaskIntoConstraints = NO;\n\n\t[NSLayoutConstraint activateConstraints:@[\n\t\t[stackView.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],\n\t\t[stackView.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor]\n\t]];\n}\n\n@end\n"
                }
            },
            NXProjectLanguageSwift:@{
                NXProjectInterfaceUIKit: @{
                    @"AppDelegate.swift": @"import UIKit\n\n@main\nclass AppDelegate: UIResponder, UIApplicationDelegate {\n\tfunc application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {\n\t\treturn true\n\t}\n}",
                    @"SceneDelegate.swift": @"import UIKit\n\nclass SceneDelegate: UIResponder, UIWindowSceneDelegate {\n\tvar window: UIWindow?\n\n\tfunc scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {\n\t\tguard let windowScene = scene as? UIWindowScene else { return }\n\n\t\tlet window = UIWindow(windowScene: windowScene)\n\t\twindow.rootViewController = ViewController()\n\t\twindow.makeKeyAndVisible()\n\t\tself.window = window\n\t}\n}\n",
                    @"ViewController.swift": @"import UIKit\n\nclass ViewController: UIViewController {\n\toverride func viewDidLoad() {\n\t\tsuper.viewDidLoad()\n\n\t\tview.backgroundColor = .systemBackground\n\n\t\tlet config = UIImage.SymbolConfiguration(scale: .large)\n\t\tlet imageView = UIImageView(image: UIImage(systemName: \"globe\", withConfiguration: config))\n\t\timageView.tintColor = .systemBlue\n\n\t\tlet label = UILabel()\n\t\tlabel.text = \"Hello, world!\"\n\t\tlabel.textAlignment = .center\n\t\tlabel.textColor = .label\n\n\t\tlet stackView = UIStackView(arrangedSubviews: [imageView, label])\n\t\tstackView.axis = .vertical\n\t\tstackView.distribution = .equalCentering\n\t\tstackView.alignment = .center\n\t\tstackView.translatesAutoresizingMaskIntoConstraints = false\n\t\tview.addSubview(stackView)\n\n\t\tNSLayoutConstraint.activate([\n\t\t\tstackView.centerXAnchor.constraint(equalTo: view.centerXAnchor),\n\t\t\tstackView.centerYAnchor.constraint(equalTo: view.centerYAnchor)\n\t\t])\n\t}\n}\n"
                },
                NXProjectInterfaceSwiftUI: @{
                    @"$(NXDisplayName)App.swift": @"import SwiftUI\n\n@main\nstruct $(NXDisplayName)App: App {\n\tvar body: some Scene {\n\t\tWindowGroup {\n\t\t\tContentView()\n\t\t}\n\t}\n}\n",
                    @"ContentView.swift": @"import SwiftUI\n\nstruct ContentView: View {\n\tvar body: some View {\n\t\tVStack {\n\t\t\tImage(systemName: \"globe\")\n\t\t\t\t.imageScale(.large)\n\t\t\t\t.foregroundStyle(.tint)\n\t\t\tText(\"Hello, world!\")\n\t\t}\n\t\t.padding()\n\t}\n}\n"
                }
            }
        },
        NXProjectSchemeUtility: @{
            NXProjectLanguageC: @{
                NXProjectInterfaceZero: @{
                    @"Main.c": @"#include <stdio.h>\n\nint main(int argc, char * argv[]) {\n\tprintf(\"Hello, World!\\n\");\n}\n"
                }
            },
            NXProjectLanguageCXX: @{
                NXProjectInterfaceZero: @{
                    @"Main.cpp": @"#include <iostream>\n\nint main(int argc, char* argv[]) {\n\tstd::cout << \"Hello, World!\" << std::endl;\n\treturn 0;\n}\n"
                }
            },
            NXProjectLanguageObjectiveC: @{
                NXProjectInterfaceZero: @{
                    @"Main.m": @"#import <Foundation/Foundation.h>\n\nint main(int argc, char * argv[]) {\n\t@autoreleasepool {\n\t\tNSLog(@\"Hello, World!\");\n\t}\n}\n"
                }
            },
            NXProjectLanguageSwift:@{
                NXProjectInterfaceZero: @{
                    @"Main.swift": @"import Foundation\n\nprint(\"Hello, World!\")\n"
                }
            }
        }
    };
}

BOOL NXCodeTemplateMakeProjectStructure(NXProjectScheme scheme,
                                        NXProjectLanguage language,
                                        NXProjectInterface interface,
                                        NSString *projectName,
                                        NSURL *projectURL,
                                        NSArray **outSources)
{
    assert(scheme != nil && language != nil);
    
    /* getting item from code template directory */
    NSDictionary *NXScemeDirectory = NXCodeTemplateDirectory[scheme];
    assert(NXScemeDirectory != nil);
    NSDictionary *NXLanguageDirectory = NXScemeDirectory[language];
    assert(NXLanguageDirectory != nil);
    NSDictionary *NXInterfaceDirectory = NXLanguageDirectory[interface?: NXProjectInterfaceZero];
    assert(NXInterfaceDirectory != nil);
    
    NSFileManager *defaultManager = [NSFileManager defaultManager];
    [NXUser shared].projectName = projectName;
    NSURL *templateURL = [[[NSBundle.mainBundle.bundleURL URLByAppendingPathComponent:@"/Shared/Templates"] URLByAppendingPathComponent:scheme] URLByAppendingPathComponent:language];
    if(interface != nil)
    {
        templateURL = [templateURL URLByAppendingPathComponent:interface];
    }
    
    NSDictionary<NSString*,NSString*> *variables = @{
        @"NXDisplayName": projectName
    };
    
    NSMutableArray *sources = [NSMutableArray array];
    
    for(NSString *fileNameKey in NXInterfaceDirectory)
    {
        NSString *fileContent = NXInterfaceDirectory[fileNameKey];
        NSURL *dstURL = [projectURL URLByAppendingPathComponent:fileNameKey];
        
        NSString *fileName = NXSubstituteContent([dstURL lastPathComponent], variables, NO);
        
        /* good enough for now */
        [sources addObject:[NSString stringWithFormat:@"$(SRCROOT)/%@/%@", projectName, [fileName lastPathComponent]]];
        
        dstURL = [[dstURL URLByDeletingLastPathComponent] URLByAppendingPathComponent:fileName];
        
        NSError *error = NULL;

        if(error)
        {
            return NO;
        }
        
        fileContent = NXSubstituteContent(fileContent, variables, NO);
        fileContent = [[[NXUser shared] generateHeaderForFileName: [dstURL lastPathComponent]] stringByAppendingString:fileContent];
        [fileContent writeToURL:dstURL atomically:YES encoding:NSUTF8StringEncoding error:&error];
    }
    
    *outSources = [sources copy];
    
    return YES;
}
