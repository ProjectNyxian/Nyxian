/*
 SPDX-License-Identifier: LicenseRef-EPSL-1.1

 Copyright (C) 2025 - 2026 emexlab

 This file is part of Nyxian.

 Licensed under the emexLabs Public Source License, version 1.1
 (EPSL 1.1).

 Private use and modification are permitted under the license.
 Redistribution of source or binaries, modified or unmodified,
 requires prior written permission from emexLabs.

 External deployment is subject to the source-availability
 requirements and other conditions of the license.

 Provided "AS IS", without warranty, to the extent permitted by law.

 See LICENSE for the full license terms.
*/

#ifndef UI_XCODEBUTTON_H
#define UI_XCODEBUTTON_H

#import <UIKit/UIKit.h>

@interface ProgressCircleView : UIView

@property (nonatomic,strong) CAShapeLayer *backgroundCircle;
@property (nonatomic,strong) CAShapeLayer *progressLayer;

- (void)setProgress:(CGFloat)value;
- (void)resetProgress;
- (void)startSpinningWithArcFraction:(CGFloat)fraction duration:(CFTimeInterval)duration;
- (void)startSpinning;
- (void)stopSpinning;

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
+ (void)startSpinning;
+ (void)startSpinningWithArcFraction:(CGFloat)fraction duration:(CFTimeInterval)duration;
+ (void)stopSpinning;

@end

#endif /* UI_XCODEBUTTON_H */
