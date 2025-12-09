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

#ifndef LDEAPPENTRY_H
#define LDEAPPENTRY_H

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@interface LDEAppEntry : NSObject

@property (nonatomic, copy) NSString *bundleID;
@property (nonatomic, copy) NSString *displayName;
@property (nonatomic, strong) UIImage *icon;

@end

#endif /* LDEAPPENTRY_H */
