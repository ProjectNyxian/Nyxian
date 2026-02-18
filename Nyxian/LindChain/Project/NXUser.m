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

#import <LindChain/Project/NXUser.h>

@interface NXUser ()

@property (nonatomic,strong,readonly) NSDateFormatter *formatter;

@end

@implementation NXUser

@synthesize username = _username;
@synthesize datestring = _datestring;

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
    
    if([@[@"c",@"cpp",@"m",@"mm"] containsObject:pathExtension])
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
