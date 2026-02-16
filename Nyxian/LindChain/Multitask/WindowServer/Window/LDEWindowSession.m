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

#import <LindChain/Multitask/WindowServer/Window/LDEWindowSession.h>

@implementation LDEWindowSession

- (BOOL)openWindow
{
    return (self.windowScene != nil);
}

- (BOOL)closeWindow
{
    return YES;
}

- (BOOL)activateWindow
{
    return YES;
}

- (BOOL)deactivateWindow
{
    return YES;
}

- (BOOL)focusWindow
{
    return YES;
}

- (BOOL)unfocusWindow
{
    return YES;
}

- (UIImage*)snapshotWindow
{
    UIGraphicsBeginImageContextWithOptions(self.view.bounds.size, NO, 0.0);
    CGContextRef context = UIGraphicsGetCurrentContext();
    [self.view.layer renderInContext:context];
    UIImage *snapshot = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return snapshot;
}

- (void)windowChangesToRect:(CGRect)rect
{
    self.windowRect = rect;
    return;
}

- (NSString*)windowName
{
    return @"Window";
}

- (void)movedWindowToScene:(UIWindowScene*)windowScene
            withIdentifier:(wid_t)identifier
{
    self.windowIdentifier = identifier;
    
    /*
     * not changing the windowScene doesnt mean strictly
     * that changing the windowIdentifier shall be
     * prohibited.
     */
    if(windowScene == nil)
    {
        return;
    }
    
    self.windowScene = windowScene;
    
    return;
}



@end
