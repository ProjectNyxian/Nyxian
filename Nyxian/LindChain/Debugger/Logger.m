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

#import <LindChain/Debugger/Logger.h>

static const CGFloat kAutoScrollThreshold = 20.0;

@implementation LogTextView {
    BOOL _followTail;
    NSUInteger _inputStartLocation;
    BOOL _isAppendingOutput;
}

- (instancetype)init
{
    return [self initWithPipe:[NSPipe pipe] stdinPipe:[NSPipe pipe]];
}

- (instancetype)initWithPipe:(NSPipe*)pipe
                   stdinPipe:(NSPipe*)stdinPipe
{
    self = [super init];
    _pipe = pipe;
    _stdinPipe = stdinPipe;
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

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleNotification:) name:NSFileHandleReadCompletionNotification object:_pipe.fileHandleForReading];
    
    [_pipe.fileHandleForReading readInBackgroundAndNotify];
    
    return self;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
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
        [self scrollToBottom];
    }
}

- (void)scrollToBottom
{
    if(self.text.length > 0)
    {
        NSRange range = NSMakeRange(self.text.length - 1, 1);
        [self scrollRangeToVisible:range];
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
        
        NSAttributedString *newline = [[NSAttributedString alloc]
            initWithString:@"\n"
            attributes:@{
                NSFontAttributeName: [UIFont monospacedSystemFontOfSize:12 weight:UIFontWeightRegular],
                NSForegroundColorAttributeName: [UIColor systemGreenColor]
            }];
        [self.textStorage appendAttributedString:newline];
        
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

@end
