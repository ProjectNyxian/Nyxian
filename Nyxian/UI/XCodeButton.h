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

#ifndef UI_XCODEBUTTON_H
#define UI_XCODEBUTTON_H

#import <UIKit/UIKit.h>

@interface ProgressCircleView : UIView

@property (nonatomic,strong) CAShapeLayer *backgroundCircle;
@property (nonatomic,strong) CAShapeLayer *progressLayer;

- (void)setProgress:(CGFloat)value;
- (void)resetProgress;

@end

@interface XCButton : UIView

@property (nonatomic,strong) UIImageView *XCImageView;
@property (nonatomic,strong) ProgressCircleView *XCProgressView;
@property (nonatomic) BOOL isTriggered;

- (instancetype)initWithFrame:(CGRect)frame;
+ (instancetype)shared;

+ (void)updateProgressWithValue:(double)value;
+ (void)incrementProgressWithValue:(double)value;
+ (void)resetProgress;
+ (double)getProgress;
+ (void)updateProgressIncrement:(double)value;
+ (void)switchImageWithSystemName:(NSString*)systemName animated:(BOOL)animated withDuration:(double)duration;
+ (void)switchImageSyncWithSystemName:(NSString*)systemName animated:(BOOL)animated withDuration:(double)duration;
+ (void)switchImageWithSystemName:(NSString*)systemName animated:(BOOL)animated;
+ (void)switchImageSyncWithSystemName:(NSString*)systemName animated:(BOOL)animated;

@end

#endif /* UI_XCODEBUTTON_H */
