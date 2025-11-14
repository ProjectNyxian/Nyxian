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

#import <LindChain/Multitask/LDEWindowSessionDummy.h>

@interface LDEWindowSessionDummy ()

@property (strong, nonatomic) NSLayoutConstraint *widthConstraint;
@property (strong, nonatomic) NSLayoutConstraint *heightConstraint;

@end

@implementation LDEWindowSessionDummy

@synthesize windowSize;
@synthesize windowName;

- (instancetype)init
{
    self = [super init];
    self.windowName = @"Dummy";
    self.view.backgroundColor = UIColor.systemGrayColor;
    self.view.translatesAutoresizingMaskIntoConstraints = NO;
    
    self.widthConstraint = [self.view.widthAnchor constraintEqualToConstant:100];
    self.heightConstraint = [self.view.heightAnchor constraintEqualToConstant:100];

    [NSLayoutConstraint activateConstraints:@[
        self.widthConstraint,
        self.heightConstraint
    ]];
    
    UIImage *image = [UIImage imageNamed:@"IconPreviewDrawn"];
    UIImageView *imageView = [[UIImageView alloc] initWithImage:image];
    imageView.translatesAutoresizingMaskIntoConstraints = NO;
    imageView.contentMode = UIViewContentModeScaleAspectFit;
    [self.view addSubview:imageView];
    
    [NSLayoutConstraint activateConstraints:@[
        [imageView.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [imageView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
        [imageView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [imageView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor]
    ]];
    
    return self;
}

- (BOOL)openWindow
{
    return YES;
}

- (void)closeWindow
{
    
}

- (UIImage*)snapshotWindow
{
    return nil;
}

- (void)activateWindow
{
}


- (void)deactivateWindow
{
}


- (void)windowChangesSizeToRect:(CGRect)rect
{
    self.widthConstraint.constant = rect.size.width;
    self.heightConstraint.constant = rect.size.height;
}

@end
