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

#import <LindChain/Multitask/ProcessManager/LDEProcessManager.h>
#import <LindChain/Multitask/WindowServer/Session/LDEWindowSessionTerminal.h>
#import <Nyxian-Swift.h>

@interface LDEWindowSessionTerminal ()

@property (nonatomic,strong) NyxianTerminal *terminal;
@property (nonatomic) bool focused;
@property (nonatomic) bool atExit;
@property (nonatomic) wid_t identifier;

@property (nonatomic,strong) NSPipe *stdoutPipe;
@property (nonatomic,strong) NSPipe *stdinPipe;

@end

@implementation LDEWindowSessionTerminal

@synthesize windowName;
@synthesize windowIsFullscreen;

- (instancetype)initWithUtilityPath:(NSString*)utilityPath
{
    self = [super init];
    _utilityPath = utilityPath;
    self.windowName = [utilityPath lastPathComponent];
    return self;
}

- (BOOL)openWindowWithScene:(UIWindowScene*)windowScene
      withSessionIdentifier:(int)identifier
{
    self.focused = NO;
    self.atExit = NO;
    self.identifier = identifier;
    
    /* using NSPipe, because file descriptors are automatically closed */
    self.stdoutPipe = [NSPipe pipe];
    self.stdinPipe = [NSPipe pipe];
    
    FDMapObject *mapObject = [FDMapObject emptyMap];
    [mapObject insertOutFD:self.stdoutPipe.fileHandleForWriting.fileDescriptor ErrFD:self.stdoutPipe.fileHandleForWriting.fileDescriptor InPipe:self.stdinPipe.fileHandleForReading.fileDescriptor];
    LDEProcess *process = nil;
    [[LDEProcessManager shared] spawnProcessWithPath:_utilityPath withArguments:@[] withEnvironmentVariables:@{} withMapObject:mapObject withKernelSurfaceProcess:kernel_proc_ process:&process];
    _process = process;
    
    _terminal = [[NyxianTerminal alloc] initWithFrame:CGRectMake(0, 0, 100, 100) title:process.executablePath.lastPathComponent stdoutFD:self.stdoutPipe.fileHandleForReading.fileDescriptor stdinFD:self.stdinPipe.fileHandleForWriting.fileDescriptor];
    
    __weak typeof(self) weakSelf = self;
    
    _process.exitingCallback = ^{
        __strong typeof(self) strongSelf = weakSelf;
        
        if(!strongSelf)
        {
            return;
        }
        
        if(strongSelf.focused)
        {
            dprintf(strongSelf.stdoutPipe.fileHandleForWriting.fileDescriptor, "\n[process exited]\n");
            
            strongSelf.atExit = YES;
            strongSelf.terminal.inputCallBack = ^{
                __strong typeof(self) strongSelf = weakSelf;
                strongSelf.terminal.stdinHandle = nil;
                strongSelf.terminal.stdoutHandle = nil;
                [[LDEWindowServer shared] closeWindowWithIdentifier:identifier];
            };
        }
        else
        {
            strongSelf.terminal.stdinHandle = nil;
            strongSelf.terminal.stdoutHandle = nil;
            
            [[LDEWindowServer shared] closeWindowWithIdentifier:identifier];
        }
    };
    
    self.view.translatesAutoresizingMaskIntoConstraints = NO;
    _terminal.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:_terminal];
    
    [NSLayoutConstraint activateConstraints:@[
        [_terminal.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [_terminal.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
        [_terminal.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [_terminal.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor]
    ]];
    
    _heigthConstraint = [self.view.heightAnchor constraintEqualToConstant:100];
    _widthConstraint = [self.view.widthAnchor constraintEqualToConstant:100];
    
    [NSLayoutConstraint activateConstraints:@[
        _heigthConstraint,
        _widthConstraint
    ]];
    
    return YES;
}

- (void)closeWindowWithScene:(UIWindowScene *)windowScene
                   withFrame:(CGRect)rect
{
    dispatch_async(dispatch_get_main_queue(), ^{
        BOOL succeeded __attribute__((unused)) = [self.terminal resignFirstResponder];
    });
    [_process terminate];
}

- (void)activateWindow
{
    [_process resume];
    [self focusWindow];
}

- (void)deactivateWindow
{
    [self unfocusWindow];
    
    if(self.atExit)
    {
        [[LDEWindowServer shared] closeWindowWithIdentifier:self.identifier];
        return;
    }
    
    [_process suspend];
}

- (UIImage *)snapshotWindow
{
    UIGraphicsBeginImageContextWithOptions(_terminal.bounds.size, NO, 0.0);
    CGContextRef context = UIGraphicsGetCurrentContext();
    [_terminal.layer renderInContext:context];
    UIImage *snapshot = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return snapshot;
}

- (void)windowChangesSizeToRect:(CGRect)rect
{
    _heigthConstraint.constant = rect.size.height;
    _widthConstraint.constant = rect.size.width;
}

- (CGRect)windowRect
{
    return CGRectMake(50, 50, 400, 400);
}

- (void)focusWindow
{
    self.focused = YES;
    BOOL succeeded __attribute__((unused)) = [self.terminal becomeFirstResponder];
}

- (void)unfocusWindow
{
    self.focused = NO;
    BOOL succeeded __attribute__((unused)) = [self.terminal resignFirstResponder];
}

- (void)dealloc
{
    NSLog(@"deallocated %@", self);
}

@end
