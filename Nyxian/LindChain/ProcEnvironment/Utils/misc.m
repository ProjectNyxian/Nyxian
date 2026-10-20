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

#import <LindChain/ProcEnvironment/Utils/misc.h>
#import <LindChain/Private/UIKitPrivate.h>
#import <Foundation/Foundation.h>

@interface _LSOpenConfiguration : NSObject
@property(nonatomic, copy) NSDictionary *frontBoardOptions;
@end

extern NSString* FBSOpenApplicationOptionKeyActivateAsClassic;
extern NSString* FBSOpenApplicationOptionKeyPayloadURL;

@interface LSApplicationWorkspace (LiveContainerSkid)
- (BOOL)openURL:(id)url;
- (BOOL)isApplicationAvailableToOpenURL:(id)arg1 error:(id*)arg2;
- (void)openApplicationWithBundleIdentifier:(NSString *)bundleID configuration:(_LSOpenConfiguration *)configuration completionHandler:(void (^)(BOOL, NSError *))completion;
- (void)openApplicationWithBundleIdentifier:(NSString *)bundleID usingConfiguration:(_LSOpenConfiguration *)configuration completionHandler:(void (^)(BOOL, NSError *))completion;
@end

void PERestartSelf(void)
{
    /* thanks Duy Tran */
    void (^completionHandler)(BOOL) = ^(BOOL success) {
        // syscall(SYS_ptrace, PT_DENY_ATTACH, 0, 0, 0);
        __asm__ __volatile__ ("mov x0, #31\n"
                              "mov x16, #26\n"
                              "svc #0x80");
        raise(SIGKILL);
    };
    
    _LSOpenConfiguration *configuration = [[PrivClass(_LSOpenConfiguration) alloc] init];
    LSApplicationWorkspace* workspace = [PrivClass(LSApplicationWorkspace) defaultWorkspace];
    
    int tries = 2;
    for(int i = 0; i < tries; i++)
    {
        [workspace openApplicationWithBundleIdentifier:NSBundle.mainBundle.bundleIdentifier configuration:configuration completionHandler:^(BOOL success, NSError* error) {
            completionHandler(success);
        }];
    }
}

BOOL PEURLIsContainedIn(NSURL *candidate,
                        NSURL *root)
{
    NSURL *candidateSatnderized = candidate.URLByResolvingSymlinksInPath.URLByStandardizingPath;
    NSURL *rootSatnderized = root.URLByResolvingSymlinksInPath.URLByStandardizingPath;
    
    NSString *candidatePath = candidateSatnderized.path;
    NSString *rootPath = rootSatnderized.path;
    
    if(![rootPath hasSuffix:@"/"])
    {
        rootPath = [rootPath stringByAppendingString:@"/"];
    }
    NSString *canditateSlash = [candidatePath hasSuffix:@"/"] ? candidatePath : [candidatePath stringByAppendingString:@"/"];
    return [canditateSlash isEqualToString:rootPath] || [canditateSlash hasPrefix:rootPath];
}
