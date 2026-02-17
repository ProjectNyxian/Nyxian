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

- (instancetype)initWithUtilityPath:(NSString*)utilityPath
{
    self = [super init];
    _utilityPath = utilityPath;
    return self;
}

- (BOOL)openWindow
{
    if(![super openWindow])
    {
        return NO;
    }
    
    self.focused = NO;
    self.atExit = NO;
    
    /* using NSPipe, because file descriptors are automatically closed */
    self.stdoutPipe = [NSPipe pipe];
    self.stdinPipe = [NSPipe pipe];
    
    FDMapObject *mapObject = [FDMapObject emptyMap];
    [mapObject insertOutFD:self.stdoutPipe.fileHandleForWriting.fileDescriptor ErrFD:self.stdoutPipe.fileHandleForWriting.fileDescriptor InPipe:self.stdinPipe.fileHandleForReading.fileDescriptor];
    LDEProcess *process = nil;
    [[LDEProcessManager shared] spawnProcessWithPath:_utilityPath withArguments:@[] withEnvironmentVariables:@{} withMapObject:mapObject withKernelSurfaceProcess:kernel_proc_ enableDebugging:YES process:&process withSession:nil];
    _process = process;
    
    _terminal = [[NyxianTerminal alloc] initWithFrame:self.windowRect title:process.executablePath.lastPathComponent stdoutFD:self.stdoutPipe.fileHandleForReading.fileDescriptor stdinFD:self.stdinPipe.fileHandleForWriting.fileDescriptor];
    _terminal.translatesAutoresizingMaskIntoConstraints = NO;
    
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
                [[LDEWindowServer shared] closeWindowWithIdentifier:strongSelf.windowIdentifier withCompletion:nil];
            };
        }
        else
        {
            [[LDEWindowServer shared] closeWindowWithIdentifier:strongSelf.windowIdentifier withCompletion:nil];
        }
    };
    
    _terminal.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:_terminal];
    
    _heigthConstraint = [self.terminal.heightAnchor constraintEqualToConstant:100];
    _widthConstraint = [self.terminal.widthAnchor constraintEqualToConstant:100];
    
    [NSLayoutConstraint activateConstraints:@[
        _heigthConstraint,
        _widthConstraint
    ]];
    
    return YES;
}

- (BOOL)closeWindow
{
    [super closeWindow];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        BOOL succeeded __attribute__((unused)) = [self.terminal resignFirstResponder];
    });
    self.terminal.stdinHandle = nil;
    self.terminal.stdoutHandle = nil;
    [_process terminate];
    
    return YES;
}

- (BOOL)activateWindow
{
    [super activateWindow];
    
    [_process resume];
    self.focused = YES;
    (void)[_terminal becomeFirstResponder];
    return YES;
}

- (BOOL)deactivateWindow
{
    [super deactivateWindow];
    
    self.focused = NO;
    
    if(self.atExit)
    {
        [[LDEWindowServer shared] closeWindowWithIdentifier:self.windowIdentifier withCompletion:nil];
        return YES;
    }
    
    [_process suspend];
    return YES;
}

- (void)windowChangesToRect:(CGRect)rect
{
    [super windowChangesToRect:rect];
    
    _heigthConstraint.constant = rect.size.height;
    _widthConstraint.constant = rect.size.width;
    
    char *noop = "\0";
    [_stdoutPipe.fileHandleForWriting writeData:[NSData dataWithBytes:noop length:1]];
}

- (NSString*)windowName
{
    return [self.utilityPath lastPathComponent];
}

- (void)dealloc
{
    NSLog(@"deallocated %@", self);
}

@end
