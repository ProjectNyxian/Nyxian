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

#import <LindChain/IDEFoundation/NXUser.h>

@implementation NXUser {
    NSDateFormatter *_formatter;
}

- (instancetype)init
{
    self = [super init];
    _formatter = [[NSDateFormatter alloc] init];
    _formatter.dateFormat = @"dd.MM.yy";
    return self;
}

+ (NXUser*)shared
{
    static NXUser *nxUserSingletone = NULL;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        nxUserSingletone = [[NXUser alloc] init];
    });
    return nxUserSingletone;
}

- (NSString*)username
{
    NSString *username = [[NSUserDefaults standardUserDefaults] valueForKey:@"LDEUsername"];
    if(username == nil)
        username = @"Anonymous";
    return username;
}

- (void)setUsername:(NSString*)username
{
    [[NSUserDefaults standardUserDefaults] setObject:username forKey:@"LDEUsername"];
}

- (NSString*)datestring
{
    NSDate *date = [NSDate date];
    return [_formatter stringFromDate:date];
}

- (NSString*)generateHeaderForFileName:(NSString*)fileName
{
    /* making sure we have a last path component */
    fileName = [fileName lastPathComponent];
    return [NSString stringWithFormat:@"//\n// %@\n// %@\n//\n// Created by %@ on %@.\n//\n\n", fileName, self.projectName, self.username, self.datestring];
}

- (NSString*)generateFileCreationContentForName:(NSString*)fileName
{
    /* making sure we have a last path component */
    fileName = [fileName lastPathComponent];
    
    /* preparing */
    BOOL authgen = NO;
    BOOL headergen = NO;
    
    NSString *pathExtension = [[NSURL fileURLWithPath:fileName] pathExtension];
    
    if([@[@"c",@"cpp",@"m",@"mm",@"swift"] containsObject:pathExtension])
    {
        authgen = YES;
    }
    else if([pathExtension isEqualToString:@"h"])
    {
        authgen = YES;
        headergen = YES;
    }
    
    /* preparing da content */
    NSMutableString *content = [[NSMutableString alloc] init];
    
    if(authgen)
    {
        [content appendFormat:@"//\n// %@\n// %@\n//\n// Created by %@ on %@.\n//\n\n", fileName, self.projectName, self.username, self.datestring];
    }
    
    if(headergen)
    {
        NSMutableString *macroname = [[fileName uppercaseString] mutableCopy];
        [macroname replaceOccurrencesOfString:@"." withString:@"_" options:NSCaseInsensitiveSearch range:NSMakeRange(0, [macroname length])];
        [macroname replaceOccurrencesOfString:@" " withString:@"_" options:NSCaseInsensitiveSearch range:NSMakeRange(0, [macroname length])];
        [content appendFormat:@"#ifndef %@\n#define %@\n\n#endif /* %@ */\n", macroname, macroname, macroname];
    }
    
    return content;
}

@end
