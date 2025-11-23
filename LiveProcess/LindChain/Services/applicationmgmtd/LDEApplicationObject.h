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

#ifndef LDEAPPLICATIONOBJECT_H
#define LDEAPPLICATIONOBJECT_H

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "MIBundle.h"

@interface LDEApplicationObject : NSObject <NSSecureCoding>

@property (nonatomic) NSString *bundleIdentifier;
@property (nonatomic) NSString *displayName;

@property (nonatomic) NSString *bundlePath;
@property (nonatomic) NSString *containerPath;
@property (nonatomic) NSString *executablePath;

@property (nonatomic) BOOL isLaunchAllowed;

@property (nonatomic) UIImage *icon;

- (instancetype)initWithBundle:(MIBundle*)bundle;
- (instancetype)initWithNSBundle:(NSBundle*)nsBundle;

@end

@interface LDEApplicationObjectArray : NSObject <NSSecureCoding>

@property (nonatomic) NSArray<LDEApplicationObject*> *applicationObjects;

- (instancetype)initWithApplicationObjects:(NSArray<LDEApplicationObject*>*)applicationObjects;

@end

#endif /* LDEAPPLICATIONOBJECT_H */
