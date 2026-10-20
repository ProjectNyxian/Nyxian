/*
 SPDX-License-Identifier: AGPL-3.0-or-later

 Copyright (C) 2023 - 2026 LiveContainer
 Copyright (C) 2026 emexlab

 This file is part of LiveContainer.

 LiveContainer is free software: you can redistribute it and/or modify
 it under the terms of the GNU Affero General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.

 LiveContainer is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 GNU Affero General Public License for more details.

 You should have received a copy of the GNU Affero General Public License
 along with Nyxian. If not, see <https://www.gnu.org/licenses/>.
*/

#import <LindChain/Private/FoundationPrivate.h>
#import <LindChain/ProcEnvironment/LiveContainer/LCMachOUtils.h>
#import <LindChain/ProcEnvironment/LiveContainer/utils.h>
#import <LindChain/ProcEnvironment/litehook/litehook.h>
#import <LindChain/ProcEnvironment/LiveContainer/Tweaks/Tweaks.h>
#import <LindChain/Utils/Swizzle.h>

NSString* appContainerPath = nil;

NSArray* appleIdentifierPrefixes = @[
    @"com.apple.",
    @"group.com.apple.",
    @"systemgroup.com.apple."
];

static bool isAppleIdentifier(NSString* identifier)
{
    for(NSString* cur in appleIdentifierPrefixes)
    {
        if([identifier hasPrefix:cur])
        {
            return true;
        }
    }
    return false;
}

void NUDGuestHooksInit(void)
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        const char *home = getenv("HOME");
        if(home != nil)
        {
            appContainerPath = [NSString stringWithCString:home encoding:NSUTF8StringEncoding];
        }
        
        NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier];
        if(bundleID == nil)
        {
            NSString *exe = [[NSBundle mainBundle] executablePath].lastPathComponent;
            bundleID = exe.length ? [@"org.emexlabs.guest." stringByAppendingString:exe] : @"org.emexlabs.guest.unknown";
            bundleID = [bundleID copy];
            CFRetain((__bridge CFTypeRef)bundleID);
        }
        
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wundeclared-selector"
        SwizzleObjCMethod(@selector(initWithDomain:user:byHost:containerPath:containingPreferences:),
                          NSClassFromString(@"CFPrefsPlistSource"),
                          @selector(hook_initWithDomain:user:byHost:containerPath:containingPreferences:),
                          [CFPrefsPlistSource2 class],
                          kSwizzleMethodTypeInstance);
#pragma clang diagnostic pop
        
        Class CFXPreferencesClass = NSClassFromString(@"_CFXPreferences");
        NSMutableDictionary* sources = object_getIvar([CFXPreferencesClass copyDefaultPreferences], class_getInstanceVariable(CFXPreferencesClass, "_sources"));
        
        [sources removeObjectForKey:@"C/A//B/L"];
        [sources removeObjectForKey:@"C/C//*/L"];
        
        const char* coreFoundationPath = "/System/Library/Frameworks/CoreFoundation.framework/CoreFoundation";
        
        CFStringRef* _CFPrefsCurrentAppIdentifierCache = litehook_find_dsc_symbol(coreFoundationPath, "__CFPrefsCurrentAppIdentifierCache");
        if(_CFPrefsCurrentAppIdentifierCache)
        {
            *_CFPrefsCurrentAppIdentifierCache = (__bridge CFStringRef)bundleID;
        }
        
        NSUserDefaults* newStandardUserDefaults = [[NSUserDefaults alloc] initWithSuiteName:@"whatever"];
        if(newStandardUserDefaults != nil)
        {
            [newStandardUserDefaults _setIdentifier:bundleID];
            NSUserDefaults.standardUserDefaults = newStandardUserDefaults;
        }
        
        NSFileManager* fm = NSFileManager.defaultManager;
        NSURL* libraryPath = [fm URLsForDirectory:NSLibraryDirectory inDomains:NSUserDomainMask].lastObject;
        NSURL* preferenceFolderPath = [libraryPath URLByAppendingPathComponent:@"Preferences"];
        if(![fm fileExistsAtPath:preferenceFolderPath.path])
        {
            NSError* error;
            [fm createDirectoryAtPath:preferenceFolderPath.path withIntermediateDirectories:YES attributes:@{} error:&error];
        }
    });
}

@implementation CFPrefsPlistSource2

- (id)hook_initWithDomain:(CFStringRef)domain
                     user:(CFStringRef)user
                   byHost:(bool)host
            containerPath:(CFStringRef)containerPath
    containingPreferences:(id)arg5
{
    if(isAppleIdentifier((__bridge NSString*)domain))
    {
        return [self hook_initWithDomain:domain user:user byHost:host containerPath:containerPath containingPreferences:arg5];
    }
    
    if(user == kCFPreferencesAnyUser)
    {
        user = kCFPreferencesCurrentUser;
    }
    
    return [self hook_initWithDomain:domain user:user byHost:host containerPath:(__bridge CFStringRef)appContainerPath containingPreferences:arg5];
}

@end
