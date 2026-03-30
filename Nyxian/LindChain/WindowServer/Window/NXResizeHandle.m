/*
 SPDX-License-Identifier: AGPL-3.0-or-later

 Copyright (C) 2023 - 2025 LiveContainer
 Copyright (C) 2025 - 2026 cr4zyengineer

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

#import <LindChain/WindowServer/Window/NXResizeHandle.h>

@implementation NXResizeHandle

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    self.layer.masksToBounds = YES;
    self.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleTopMargin;
    UIView *backgroundView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, frame.size.width*sqrt(2), frame.size.height*sqrt(2))];
    backgroundView.backgroundColor = [UIColor colorWithWhite:1 alpha:0.2];
    backgroundView.center = CGPointMake(frame.size.width, frame.size.height);
    backgroundView.transform = CGAffineTransformMakeRotation(M_PI_4);
    backgroundView.layer.cornerRadius = 8;
    [self addSubview:backgroundView];
    return self;
}

- (void)dealloc
{
    NSLog(@"deallocated %@", self);
}

@end
