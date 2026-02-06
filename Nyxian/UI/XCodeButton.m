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

#import <UI/XCodeButton.h>

@implementation ProgressCircleView

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    
    self.backgroundCircle = [[CAShapeLayer alloc] init];
    self.backgroundCircle.strokeColor = [[UITableViewCell appearance] backgroundColor].CGColor;
    self.backgroundCircle.fillColor = UIColor.clearColor.CGColor;
    self.backgroundCircle.lineWidth = 2;
    self.backgroundCircle.lineCap = kCALineCapButt;
    
    self.progressLayer = [[CAShapeLayer alloc] init];
    self.progressLayer.strokeColor = [[UIView appearance] tintColor].CGColor;
    self.progressLayer.fillColor = UIColor.clearColor.CGColor;
    self.progressLayer.lineWidth = 2;
    self.progressLayer.strokeEnd = 0;
    self.progressLayer.lineCap = kCALineCapRound;
    
    [self.layer addSublayer:self.backgroundCircle];
    [self.layer addSublayer:self.progressLayer];
    
    return self;
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    
    CGFloat radius = MIN(self.bounds.size.width, self.bounds.size.height) / 2 - self.progressLayer.lineWidth/2;
    CGPoint center = CGPointMake(CGRectGetMidX(self.bounds), CGRectGetMidY(self.bounds));
    CGFloat startAngle = -(CGFloat)M_PI / 2.0;
    CGFloat endAngle = startAngle + 2.0 * (CGFloat)M_PI;

    UIBezierPath *path = [UIBezierPath bezierPathWithArcCenter:center
                                                        radius:radius
                                                    startAngle:startAngle
                                                      endAngle:endAngle
                                                     clockwise:YES];

    self.backgroundCircle.frame = self.bounds;
    self.backgroundCircle.path  = path.CGPath;

    self.progressLayer.frame = self.bounds;
    self.progressLayer.path  = path.CGPath;

    self.layer.cornerRadius = MIN(self.bounds.size.width,
                                  self.bounds.size.height) / 2.0;
}

- (void)setProgress:(CGFloat)value
{
    CGFloat clamped = MIN(MAX(value, 0.0), 1.0);
    
    CAShapeLayer *presentationLayer = (CAShapeLayer *)self.progressLayer.presentationLayer;
    CGFloat currentStrokeEnd = presentationLayer ? presentationLayer.strokeEnd : self.progressLayer.strokeEnd;
    
    if(fabs(clamped - currentStrokeEnd) < 0.01)
    {
        return;
    }
    
    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    self.progressLayer.strokeEnd = currentStrokeEnd;
    [CATransaction commit];
    
    CABasicAnimation *animation = [CABasicAnimation animationWithKeyPath:@"strokeEnd"];
    animation.fromValue = @(currentStrokeEnd);
    animation.toValue = @(clamped);
    animation.duration = 0.15;
    animation.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionLinear];
    
    self.progressLayer.strokeEnd = clamped;
    [self.progressLayer addAnimation:animation forKey:@"strokeEndAnim"];
}

- (void)resetProgress
{
    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    self.progressLayer.strokeEnd = 0.0;
    [CATransaction commit];
    self.progress = 0.0;
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection
{
    [super traitCollectionDidChange:previousTraitCollection];
    self.backgroundCircle.strokeColor = [[UITableViewCell appearance] backgroundColor].CGColor;
    self.progressLayer.strokeColor = [[UIView appearance] tintColor].CGColor;
}

@end

@implementation XCButton

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    
    self.XCProgressView = [[ProgressCircleView alloc] initWithFrame:self.bounds];
    self.XCProgressView.translatesAutoresizingMaskIntoConstraints = NO;
    [self addSubview:self.XCProgressView];
    
    UIImage *image = [UIImage systemImageNamed:@"hammer.fill"];
    self.XCImageView = [[UIImageView alloc] initWithImage:image];
    self.XCImageView.tintColor = UIColor.labelColor;
    self.XCImageView.contentMode = UIViewContentModeScaleAspectFit;
    self.XCImageView.translatesAutoresizingMaskIntoConstraints = NO;
    [self addSubview:self.XCImageView];
    
    [NSLayoutConstraint activateConstraints:@[
        [self.XCProgressView.widthAnchor constraintEqualToConstant:self.frame.size.width / 2.2],
        [self.XCProgressView.heightAnchor constraintEqualToAnchor:self.XCProgressView.widthAnchor],
        [self.XCProgressView.centerXAnchor constraintEqualToAnchor:self.centerXAnchor],
        [self.XCProgressView.centerYAnchor constraintEqualToAnchor:self.centerYAnchor],
        
        [self.XCImageView.widthAnchor constraintEqualToAnchor:self.XCProgressView.widthAnchor multiplier:0.55],
        [self.XCImageView.heightAnchor constraintEqualToAnchor:self.XCProgressView.widthAnchor],
        [self.XCImageView.centerXAnchor constraintEqualToAnchor:self.centerXAnchor],
        [self.XCImageView.centerYAnchor constraintEqualToAnchor:self.centerYAnchor]
    ]];
    
    return self;
}

+ (instancetype)shared
{
    static XCButton *buttonSingleton = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        buttonSingleton = [[XCButton alloc] initWithFrame:CGRectMake(0, 0, 64, 64)];
    });
    return buttonSingleton;
}

+ (void)updateProgressWithValue:(double)value
{
    dispatch_async(dispatch_get_main_queue(), ^{
        [[self shared].XCProgressView setProgress:value];
    });
}

+ (void)incrementProgressWithValue:(double)value
{
    dispatch_async(dispatch_get_main_queue(), ^{
        [[self shared].XCProgressView setProgress:[self shared].XCProgressView.progressLayer.strokeEnd + value];
    });
}

+ (void)resetProgress
{
    dispatch_async(dispatch_get_main_queue(), ^{
        [[self shared].XCProgressView resetProgress];
    });
}

+ (double)getProgress
{
    return [self shared].XCProgressView.progressLayer.strokeEnd;
}

+ (void)updateProgressIncrement:(double)value
{
    dispatch_async(dispatch_get_main_queue(), ^{
        if(value > [self shared].XCProgressView.progressLayer.strokeEnd)
        {
            [[self shared].XCProgressView setProgress:value];
        }
    });
}

+ (void)switchImageWithSystemName:(NSString*)systemName
                         animated:(BOOL)animated
                     withDuration:(double)duration
{
    dispatch_async(dispatch_get_main_queue(), ^{
        UIImageView *imageView = [self shared].XCImageView;
        if(!imageView)
        {
            return;
        }
        
        if(animated)
        {
            CGFloat currentAlpha = imageView.layer.presentationLayer ?
            ((CALayer *)imageView.layer.presentationLayer).opacity :
            imageView.alpha;
            
            [imageView.layer removeAllAnimations];
            imageView.alpha = currentAlpha;
            
            [UIView animateWithDuration:duration / 2.0 animations:^{
                imageView.alpha = 0.0;
            } completion:^(BOOL finished) {
                imageView.image = [UIImage systemImageNamed:systemName];
                [UIView animateWithDuration:duration / 2.0 animations:^{
                    imageView.alpha = 1.0;
                }];
            }];
            
        } else {
            imageView.image = [UIImage systemImageNamed:systemName];
        }
    });
}

+ (void)switchImageSyncWithSystemName:(NSString*)systemName
                             animated:(BOOL)animated
                         withDuration:(double)duration
{
    UIImageView *imageView = [self shared].XCImageView;
    if(!imageView)
    {
        return;
    }

    if(animated)
    {
        CGFloat currentAlpha;
        if(imageView.layer.presentationLayer)
        {
            currentAlpha = ((CALayer *)imageView.layer.presentationLayer).opacity;
        }
        else
        {
            currentAlpha = imageView.alpha;
        }

        [imageView.layer removeAllAnimations];
        imageView.alpha = currentAlpha;

        [UIView animateWithDuration:duration / 2.0 animations:^{
            imageView.alpha = 0.0;
        } completion:^(BOOL finished) {
            imageView.image = [UIImage systemImageNamed:systemName];
            [UIView animateWithDuration:duration / 2.0 animations:^{
                imageView.alpha = 1.0;
            }];
        }];

    } else {

        imageView.image = [UIImage systemImageNamed:systemName];
    }
}

+ (void)switchImageWithSystemName:(NSString*)systemName
                         animated:(BOOL)animated
{
    [self switchImageWithSystemName:systemName animated:true withDuration:0.6];
}

+ (void)switchImageSyncWithSystemName:(NSString*)systemName
                             animated:(BOOL)animated
{
    [self switchImageSyncWithSystemName:systemName animated:true withDuration:0.6];
}

- (CGSize)intrinsicContentSize
{
    return CGSizeMake(35, 35);
}

@end
