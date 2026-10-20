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

#import <LindChain/IDEConsole/NXConsoleView.h>
#import <Nyxian-Swift.h>

static const CGFloat kAutoScrollThreshold = 20.0;

static NSString *const IDEFullLineHighlightAttributeName = @"IDEFullLineHighlightAttributeName";

@interface NXConsoleLayoutManager : NSLayoutManager
@end

@implementation NXConsoleLayoutManager

- (void)drawBackgroundForGlyphRange:(NSRange)glyphsToShow
                            atPoint:(CGPoint)origin
{
    [self enumerateLineFragmentsForGlyphRange:glyphsToShow usingBlock:^(CGRect rect, CGRect usedRect, NSTextContainer *textContainer, NSRange glyphRange, BOOL *stop) {
        NSRange charRange = [self characterRangeForGlyphRange:glyphRange actualGlyphRange:NULL];
        UIColor *highlightColor = [self.textStorage attribute:IDEFullLineHighlightAttributeName atIndex:charRange.location longestEffectiveRange:NULL inRange:charRange];
        
        if(highlightColor)
        {
            UIColor *gutterHairlineColor = [[LDETheme current] gutterHairlineColor];
            
            CGContextRef context = UIGraphicsGetCurrentContext();
            CGContextSaveGState(context);
            
            CGRect fullWidthRect = CGRectMake(0, rect.origin.y + origin.y, textContainer.size.width + (textContainer.lineFragmentPadding * 2), rect.size.height);
            
            [highlightColor setFill];
            CGContextFillRect(context, fullWidthRect);
            
            CGFloat hairlineThickness = 0.5;
            UIColor *hairlineColor = gutterHairlineColor;
            [hairlineColor setStroke];
            CGContextSetLineWidth(context, hairlineThickness);
            
            CGFloat topY = CGRectGetMinY(fullWidthRect) + (hairlineThickness / 2.0);
            CGContextBeginPath(context);
            CGContextMoveToPoint(context, CGRectGetMinX(fullWidthRect), topY);
            CGContextAddLineToPoint(context, CGRectGetMaxX(fullWidthRect), topY);
            CGContextStrokePath(context);
            
            CGFloat bottomY = CGRectGetMaxY(fullWidthRect) - (hairlineThickness / 2.0);
            CGContextBeginPath(context);
            CGContextMoveToPoint(context, CGRectGetMinX(fullWidthRect), bottomY);
            CGContextAddLineToPoint(context, CGRectGetMaxX(fullWidthRect), bottomY);
            CGContextStrokePath(context);
            
            CGContextRestoreGState(context);
        }
    }];
    
    [super drawBackgroundForGlyphRange:glyphsToShow atPoint:origin];
}

@end

@implementation NXConsoleView {
    BOOL _followTail;
    NSUInteger _inputStartLocation;
    BOOL _isAppendingOutput;
}

- (instancetype)init
{
    NSTextStorage *textStorage = [[NSTextStorage alloc] init];
    NXConsoleLayoutManager *layoutManager = [[NXConsoleLayoutManager alloc] init];
    [textStorage addLayoutManager:layoutManager];
    
    NSTextContainer *textContainer = [[NSTextContainer alloc] initWithSize:CGSizeZero];
    textContainer.widthTracksTextView = YES;
    textContainer.heightTracksTextView = YES;
    [layoutManager addTextContainer:textContainer];
    
    self = [super initWithFrame:CGRectZero textContainer:textContainer];
    if(self)
    {
        self.textContainerInset = UIEdgeInsetsZero;
        _pipe = [NSPipe pipe];
        _stdinPipe = [NSPipe pipe];
        _followTail = YES;
        _inputStartLocation = 0;
        _isAppendingOutput = NO;
        
        self.font = [UIFont monospacedSystemFontOfSize:12 weight:UIFontWeightRegular];
        self.backgroundColor = [UIColor systemGray6Color];
        self.editable = YES;
        self.selectable = YES;
        self.text = @"";
        self.translatesAutoresizingMaskIntoConstraints = NO;
        self.alwaysBounceVertical = YES;
        self.autocorrectionType = UITextAutocorrectionTypeNo;
        self.autocapitalizationType = UITextAutocapitalizationTypeNone;
        self.spellCheckingType = UITextSpellCheckingTypeNo;
        self.keyboardType = UIKeyboardTypeASCIICapable;
        self.returnKeyType = UIReturnKeySend;
        
        self.delegate = (id<UITextViewDelegate>)self;
        
        [_pipe.fileHandleForReading readInBackgroundAndNotify];
    }
    return self;
}

- (void)willMoveToWindow:(UIWindow *)newWindow
{
    [super willMoveToWindow:newWindow];
    
    if(newWindow == nil)
    {
        [[NSNotificationCenter defaultCenter] removeObserver:self];
    }
    else
    {
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleNotification:) name:NSFileHandleReadCompletionNotification object:_pipe.fileHandleForReading];
    }
}

- (void)dealloc
{
    @try {
        [_pipe.fileHandleForReading closeFile];
        [_stdinPipe.fileHandleForWriting closeFile];
    } @catch (NSException *ex) { /* ignore */ }
    _pipe = nil;
    _stdinPipe = nil;
}

- (void)handleNotification:(NSNotification*)notification
{
    NSData *data = notification.userInfo[NSFileHandleNotificationDataItem];
    if (!data || data.length == 0) {
        [_pipe.fileHandleForReading readInBackgroundAndNotify];
        return;
    }

    NSString *output = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    if (!output) {
        [_pipe.fileHandleForReading readInBackgroundAndNotify];
        return;
    }

    dispatch_async(dispatch_get_main_queue(), ^{
        [self appendOutput:output];
    });

    [_pipe.fileHandleForReading readInBackgroundAndNotify];
}

- (void)appendOutput:(NSString *)output
{
    _isAppendingOutput = YES;
    
    NSString *currentInput = @"";
    if(_inputStartLocation < self.text.length)
    {
        currentInput = [self.text substringFromIndex:_inputStartLocation];
        NSRange inputRange = NSMakeRange(_inputStartLocation, self.text.length - _inputStartLocation);
        [self.textStorage deleteCharactersInRange:inputRange];
    }
    
    NSDictionary *outputAttributes = @{
        NSFontAttributeName: [UIFont monospacedSystemFontOfSize:12 weight:UIFontWeightRegular],
        NSForegroundColorAttributeName: [UIColor labelColor]
    };
    NSAttributedString *outputAttr = [[NSAttributedString alloc] initWithString:output attributes:outputAttributes];
    [self.textStorage appendAttributedString:outputAttr];
    
    _inputStartLocation = self.text.length;
    
    if(currentInput.length > 0)
    {
        NSDictionary *inputAttributes = @{
            NSFontAttributeName: [UIFont monospacedSystemFontOfSize:12 weight:UIFontWeightRegular],
            NSForegroundColorAttributeName: [UIColor systemGreenColor]
        };
        NSAttributedString *inputAttr = [[NSAttributedString alloc] initWithString:currentInput attributes:inputAttributes];
        [self.textStorage appendAttributedString:inputAttr];
    }
    
    [self.layoutManager ensureLayoutForTextContainer:self.textContainer];
    self.selectedRange = NSMakeRange(self.text.length, 0);
    
    _isAppendingOutput = NO;
    
    if(_followTail)
    {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self scrollToBottom];
        });
    }
}

- (void)appendAttributedOutput:(NSAttributedString *)attributedOutput
{
    _isAppendingOutput = YES;
    NSString *currentInput = @"";
    if(_inputStartLocation < self.text.length)
    {
        currentInput = [self.text substringFromIndex:_inputStartLocation];
        NSRange inputRange = NSMakeRange(_inputStartLocation, self.text.length - _inputStartLocation);
        [self.textStorage deleteCharactersInRange:inputRange];
    }
    
    [self.textStorage appendAttributedString:attributedOutput];
    
    _inputStartLocation = self.text.length;
    
    if(currentInput.length > 0)
    {
        NSDictionary *inputAttributes = @{
            NSFontAttributeName: [UIFont monospacedSystemFontOfSize:12 weight:UIFontWeightRegular],
            NSForegroundColorAttributeName: [UIColor systemGreenColor]
        };
        NSAttributedString *inputAttr = [[NSAttributedString alloc] initWithString:currentInput attributes:inputAttributes];
        [self.textStorage appendAttributedString:inputAttr];
    }
    
    [self.layoutManager ensureLayoutForTextContainer:self.textContainer];
    self.selectedRange = NSMakeRange(self.text.length, 0);
    _isAppendingOutput = NO;
    if(_followTail)
    {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self scrollToBottom];
        });
    }
}

- (void)scrollToBottom
{
    UIEdgeInsets insets = self.contentInset;
    CGFloat bottomOffset = self.contentSize.height - self.bounds.size.height + insets.bottom;
    if(bottomOffset > self.contentOffset.y)
    {
        [self setContentOffset:CGPointMake(0, MAX(0, bottomOffset)) animated:NO];
    }
}

- (void)scrollViewDidScroll:(UIScrollView *)scrollView
{
    CGFloat distanceFromBottom = scrollView.contentSize.height - scrollView.bounds.size.height - scrollView.contentOffset.y;
    _followTail = (distanceFromBottom <= kAutoScrollThreshold);
}

- (BOOL)textView:(UITextView *)textView shouldChangeTextInRange:(NSRange)range replacementText:(NSString *)text
{
    if(_isAppendingOutput)
    {
        return NO;
    }
    
    if(range.location < _inputStartLocation)
    {
        dispatch_async(dispatch_get_main_queue(), ^{
            self.selectedRange = NSMakeRange(self.text.length, 0);
        });
        return NO;
    }
    
    if([text isEqualToString:@"\n"])
    {
        NSString *command = @"";
        if(_inputStartLocation < self.text.length)
        {
            command = [self.text substringFromIndex:_inputStartLocation];
        }
        
        if(_inputStartLocation < self.text.length)
        {
            NSRange inputRange = NSMakeRange(_inputStartLocation, self.text.length - _inputStartLocation);
            NSDictionary *outputAttributes = @{
                NSFontAttributeName: [UIFont monospacedSystemFontOfSize:12 weight:UIFontWeightRegular],
                NSForegroundColorAttributeName: [UIColor systemGreenColor]
            };
            [self.textStorage setAttributes:outputAttributes range:inputRange];
        }
        
        _inputStartLocation = self.text.length;
        
        NSString *commandWithNewline = [command stringByAppendingString:@"\n"];
        NSData *data = [commandWithNewline dataUsingEncoding:NSUTF8StringEncoding];
        @try {
            [_stdinPipe.fileHandleForWriting writeData:data];
        } @catch (NSException *exception) {
            NSLog(@"Failed to write to stdin: %@", exception);
        }
        
        return NO;
    }
    
    return YES;
}

- (void)textViewDidChange:(UITextView *)textView
{
    if(_inputStartLocation < self.text.length)
    {
        NSRange inputRange = NSMakeRange(_inputStartLocation, self.text.length - _inputStartLocation);
        NSDictionary *inputAttributes = @{
            NSFontAttributeName: [UIFont monospacedSystemFontOfSize:12 weight:UIFontWeightRegular],
            NSForegroundColorAttributeName: [UIColor systemGreenColor]
        };
        [self.textStorage setAttributes:inputAttributes range:inputRange];
    }
}

- (void)textViewDidChangeSelection:(UITextView *)textView
{
    if(!_isAppendingOutput && textView.selectedRange.location < _inputStartLocation && textView.selectedRange.length < 1)
    {
        dispatch_async(dispatch_get_main_queue(), ^{
            if(self.selectedRange.location < self->_inputStartLocation)
            {
                self.selectedRange = NSMakeRange(self.text.length, 0);
            }
        });
    }
}

- (void)clearConsole
{
    self.text = @"";
    _inputStartLocation = 0;
    _followTail = YES;
    
    /* remove old notification observer for pipe */
    [[NSNotificationCenter defaultCenter] removeObserver:self name:NSFileHandleReadCompletionNotification object:_pipe.fileHandleForReading];
    
    @try {
        [_pipe.fileHandleForReading closeFile];
        [_stdinPipe.fileHandleForWriting closeFile];
    } @catch (NSException *ex) { /* ignore */ }
    
    /* creating new pipes */
    _pipe = [NSPipe pipe];
    _stdinPipe = [NSPipe pipe];
    
    /* readding pipe */
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleNotification:) name:NSFileHandleReadCompletionNotification object:_pipe.fileHandleForReading];
    
    /* starting reading from new pipe */
    [_pipe.fileHandleForReading readInBackgroundAndNotify];
}

- (void)setContentOffset:(CGPoint)contentOffset
{
    [super setContentOffset:contentOffset];
    if(!_isAppendingOutput)
    {
        CGFloat distanceFromBottom = self.contentSize.height - self.bounds.size.height - contentOffset.y;
        _followTail = (distanceFromBottom <= kAutoScrollThreshold);
    }
}

- (void)writeMessageToConsole:(NSString*)message
                    withColor:(UIColor*)color
{
    color = [color colorWithAlphaComponent:0.15];
    NSString *fullMessage = [NSString stringWithFormat:@"%@\n", message];
    
    NSDictionary *attributes = @{
        NSFontAttributeName: [UIFont monospacedSystemFontOfSize:12 weight:UIFontWeightRegular],
        NSForegroundColorAttributeName: [UIColor labelColor],
        IDEFullLineHighlightAttributeName: color
    };
    
    NSAttributedString *attributedMessage = [[NSAttributedString alloc] initWithString:fullMessage attributes:attributes];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [self appendAttributedOutput:attributedMessage];
    });
}

- (void)writeMessageToConsole:(NSString*)message
{
    [self writeMessageToConsole:message withColor:[UIColor systemGreenColor]];
}

@end
