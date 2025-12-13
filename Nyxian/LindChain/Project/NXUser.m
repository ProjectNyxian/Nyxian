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
    return [NSString stringWithFormat:@"//\n// %@\n// %@\n//\n// Created by %@ on %@.\n//\n\n", fileName, self.projectName, self.username, self.datestring];
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

@end
