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

#ifndef LDEWINDOW_H
#define LDEWINDOW_H

#import "FoundationPrivate.h"
#import <LindChain/Multitask/LDEWindowSession.h>

typedef int wid_t;

@interface LDEWindow : UIViewController

@property (nonatomic) wid_t identifier;
@property (nonatomic) NSString* windowName;
@property (nonatomic) UINavigationBar *navigationBar;
@property (nonatomic) UINavigationItem *navigationItem;
@property (nonatomic) UIView *resizeHandle;
@property (nonatomic) UIView *contentView;
@property (nonatomic) BOOL isMaximized;
@property (nonatomic) CGRect originalFrame;

@property (nonatomic) UIStackView *view;
@property (nonatomic) UIViewController<LDEWindowSession> *session;

- (instancetype)initWithSession:(UIViewController<LDEWindowSession>*)session dismissalCallback:(void (^)(void))dismissalCallback;
- (void)updateVerticalConstraints;
- (void)closeWindow;

@end

#endif /* LDEWINDOW_H */
