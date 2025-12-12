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

#import "FoundationPrivate.h"
#import "LCMachOUtils.h"
#import "utils.h"
#import <LindChain/litehook/litehook.h>
#include "Tweaks.h"
#import <LindChain/Utils/Swizzle.h>

extern NSUserDefaults *lcUserDefaults;
extern NSBundle *guestMainBundle;

NSURL* appContainerURL = 0;
NSString* appContainerPath = 0;

void NUDGuestHooksInit(void)
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        appContainerPath = [NSString stringWithUTF8String:getenv("HOME")];
        appContainerURL = [NSURL URLWithString:appContainerPath];
        
        swizzle_objc_method(@selector(initWithDomain:user:byHost:containerPath:containingPreferences:),
                            NSClassFromString(@"CFPrefsPlistSource"),
                            @selector(hook_initWithDomain:user:byHost:containerPath:containingPreferences:),
                            [CFPrefsPlistSource2 class]);
        
        Class CFXPreferencesClass = NSClassFromString(@"_CFXPreferences");
        NSMutableDictionary* sources = object_getIvar([CFXPreferencesClass copyDefaultPreferences], class_getInstanceVariable(CFXPreferencesClass, "_sources"));
        
        [sources removeObjectForKey:@"C/A//B/L"];
        [sources removeObjectForKey:@"C/C//*/L"];
        
        const char* coreFoundationPath = "/System/Library/Frameworks/CoreFoundation.framework/CoreFoundation";
        
        CFStringRef* _CFPrefsCurrentAppIdentifierCache = litehook_find_dsc_symbol(coreFoundationPath, "__CFPrefsCurrentAppIdentifierCache");
        lcUserDefaults = [[NSUserDefaults alloc] init];
        [lcUserDefaults _setIdentifier:(__bridge NSString*)CFStringCreateCopy(nil, *_CFPrefsCurrentAppIdentifierCache)];
        *_CFPrefsCurrentAppIdentifierCache = (__bridge CFStringRef)[guestMainBundle bundleIdentifier];
        
        NSUserDefaults* newStandardUserDefaults = [[NSUserDefaults alloc] initWithSuiteName:@"whatever"];
        [newStandardUserDefaults _setIdentifier:[guestMainBundle bundleIdentifier]];
        NSUserDefaults.standardUserDefaults = newStandardUserDefaults;
        
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

-(id)hook_initWithDomain:(CFStringRef)domain user:(CFStringRef)user byHost:(bool)host containerPath:(CFStringRef)containerPath containingPreferences:(id)arg5
{
    static NSArray* appleIdentifierPrefixes = @[
        @"com.apple.",
        @"group.com.apple.",
        @"systemgroup.com.apple."
    ];
    return [appleIdentifierPrefixes indexOfObjectPassingTest:^BOOL(NSString *cur, NSUInteger idx, BOOL *stop) { return [(__bridge NSString *)domain hasPrefix:cur]; }] != NSNotFound ?
        [self hook_initWithDomain:domain user:user byHost:host containerPath:containerPath containingPreferences:arg5] :
        [self hook_initWithDomain:domain user:user byHost:host containerPath:(__bridge CFStringRef)appContainerPath containingPreferences:arg5];
}

@end
