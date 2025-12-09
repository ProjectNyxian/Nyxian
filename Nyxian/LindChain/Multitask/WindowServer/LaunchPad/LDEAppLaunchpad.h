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

#ifndef LDEAPPLAUNCHPAD_H
#define LDEAPPLAUNCHPAD_H

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

#import <LindChain/Multitask/WindowServer/LaunchPad/LDEAppEntry.h>

@protocol LDEAppLaunchpadDelegate <NSObject>

- (void)launchpadDidSelectAppWithBundleID:(NSString *)bundleID;

@end

@interface LDEAppLaunchpad : UIView <UICollectionViewDelegate, UICollectionViewDataSource, UISearchBarDelegate>

@property (nonatomic, weak) id<LDEAppLaunchpadDelegate> delegate;
@property (nonatomic, strong, readonly) NSArray<LDEAppEntry *> *installedApps;

- (void)reloadApps;
- (void)registerAppWithBundleID:(NSString*)bundleID displayName:(NSString*)name icon:(UIImage*)icon appPath:(NSString*)path;
- (void)unregisterAppWithBundleID:(NSString*)bundleID;

@end

#endif /* LDEAPPLAUNCHPAD_H */
