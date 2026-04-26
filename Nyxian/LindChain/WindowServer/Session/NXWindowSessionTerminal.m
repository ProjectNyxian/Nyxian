/*
 SPDX-License-Identifier: AGPL-3.0-or-later

 Copyright (C) 2025 - 2026 cr4zyengineer

 This file is part of Nyxian.

 Nyxian is free software: you can redistribute it and/or modify
 it under the terms of the GNU Affero General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.

 Nyxian is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 GNU Affero General Public License for more details.

 You should have received a copy of the GNU Affero General Public License
 along with Nyxian. If not, see <https://www.gnu.org/licenses/>.
*/

#import <LindChain/WindowServer/Session/NXWindowSessionTerminal.h>
#import <LindChain/ProcEnvironment/Process/PEProcessManager.h>
#import <LindChain/Services/applicationmgmtd/LDEApplicationWorkspace.h>
#import <LindChain/ProcEnvironment/Surface/tty/tty.h>
#import <Nyxian-Swift.h>

@interface NXWindowSessionTerminal () <TerminalViewDelegateObjC>

@property (nonatomic,strong) TerminalViewObjC *terminal;
@property (nonatomic) bool focused;
@property (nonatomic) bool atExit;
@property (nonatomic) id_t identifier;
@property (nonatomic) ksurface_tty_t *tty;

@end

@implementation NXWindowSessionTerminal

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

    
    /*
     * in theory creating it before the process exists,
     * to have pipes to handoff.
     */
    ksurface_tty_t *tty = kvo_alloc_fastpath(tty);
    
    if(tty == NULL)
    {
        return NO;
    }
    
    /* setting tty properties */
    kvo_wrlock(tty);
    tty->t.c_iflag = ICRNL | ISTRIP | INPCK /*| IXON | BRKINT*/;
    tty->t.c_oflag = OPOST | ONLCR;
    /*tty->t.c_cflag = CS8 | CREAD | CLOCAL;*/
    tty->t.c_lflag = /*ICANON | ECHO | ECHOE | ECHOK |*/ ISIG /*| IEXTEN*/;
    tty->t.c_cc[VINTR]  = 0x03;
    tty->t.c_cc[VQUIT]  = 0x1C;
    /*tty->t.c_cc[VERASE] = 0x7F;*/
    tty->t.c_cc[VKILL]  = 0x15;
    /*tty->t.c_cc[VEOF]   = 0x04;*/
    tty->t.c_cc[VSUSP]  = 0x1A;
    /*tty->t.c_cc[VSTART] = 0x11;
    tty->t.c_cc[VSTOP]  = 0x13;
    tty->t.c_cc[VMIN]   = 1;
    tty->t.c_cc[VTIME]  = 0;*/
    kvo_unlock(tty);
    
    kvo_retain(tty);
    _tty = tty;
    
    FDMapObject *mapObject = [FDMapObject emptyMap];
    
    if(mapObject == nil)
    {
        kvo_release(tty);
        return NO;
    }
    
    [mapObject appendFileDescriptor:tty->userspacefd[SLAVEFD] withMappingToLoc:STDIN_FILENO];
    [mapObject appendFileDescriptor:tty->userspacefd[SLAVEFD] withMappingToLoc:STDOUT_FILENO];
    [mapObject appendFileDescriptor:tty->userspacefd[SLAVEFD] withMappingToLoc:STDERR_FILENO];
    
    NSString *homePath = [[LDEApplicationWorkspace shared] utilityHomePath];
    if(homePath == nil)
    {
        kvo_release(tty);
        return NO;
    }
    
    pid_t pid = [[PEProcessManager shared] spawnProcessWithItems:@{
        @"PEExecutablePath": _utilityPath,
        @"PEArguments": @[self.utilityPath],
        @"PEEnvironment": @{
            @"HOME": homePath,
            @"CFFIXED_USER_HOME": homePath,
            @"TMPDIR": [homePath stringByAppendingPathComponent:@"/Tmp"]
        },
        @"PEWorkingDirectory": homePath,
        @"PEMapObject": mapObject
    } withKernelSurfaceProcess:kernel_proc_];
    PEProcess *process = [[PEProcessManager shared] processForProcessIdentifier:pid];
    
    if(process == nil)
    {
        kvo_release(tty);
        return NO;
    }
    
    _process = process;
    
    /* attaching tty to process lifecycle */
    ksurface_return_t ksr = tty_attach_proc(_process.proc, tty);
    
    if(ksr != SURFACE_SUCCESS)
    {
        [process terminate];
        kvo_release(tty);
        return NO;
    }
    
    /* finally starting terminal */
    _terminal = [[TerminalViewObjC alloc] initWithFrame:self.windowRect masterFD:tty->userspacefd[MASTERFD]];
    
    if(_terminal == nil)
    {
        [process terminate];
        kvo_release(tty);
        return NO;
    }
    
    _terminal.objcDelegate = self;
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
            write(strongSelf->_tty->userspacefd[SLAVEFD], "\n[process exited]\n", 18);
            
            strongSelf.atExit = YES;
        }
        else
        {
            dispatch_async(dispatch_get_main_queue(), ^{
                [[NXWindowServer shared] closeWindowWithIdentifier:strongSelf.windowIdentifier withCompletion:nil];
            });
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
    self.terminal.ttyHandle = nil;
    [_process terminate];
    
    return YES;
}

- (BOOL)activateWindow
{
    [super activateWindow];
    
    //[_process resume];
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
        [[NXWindowServer shared] closeWindowWithIdentifier:self.windowIdentifier withCompletion:nil];
        return YES;
    }
    
    //[_process suspend];
    return YES;
}

- (void)windowChangesToRect:(CGRect)rect
{
    [super windowChangesToRect:rect];
    
    _heigthConstraint.constant = rect.size.height;
    _widthConstraint.constant = rect.size.width;
    
    char *noop = "\0";
    write(_tty->userspacefd[SLAVEFD], [[NSData dataWithBytes:noop length:1] bytes], 1);
}

- (NSString*)getWindowName
{
    NSString *windowName = [super getWindowName];
    return windowName ?: [self.utilityPath lastPathComponent];
}

- (void)sendWithSource:(TerminalView * _Nonnull)source data:(NSData * _Nonnull)data
{
    if(self.atExit)
    {
        [[NXWindowServer shared] closeWindowWithIdentifier:self.windowIdentifier withCompletion:nil];
    }
    
    write(self.terminal.ttyHandle.fileDescriptor, data.bytes, data.length);
}

- (void)setTerminalTitleWithSource:(TerminalView * _Nonnull)source title:(NSString * _Nonnull)title
{
    self.windowName = title;
}

- (void)sizeChangedWithSource:(TerminalView * _Nonnull)source newCols:(NSInteger)newCols newRows:(NSInteger)newRows
{
    /* updating window size */
    kvo_wrlock(_tty);
    _tty->ws.ws_col = newCols;
    _tty->ws.ws_row = newRows;
    kvo_unlock(_tty);
    
    /* notifying child process */
    [self.process sendSignal:SIGWINCH];
}

- (void)dealloc
{
    if(_tty != NULL)
    {
        kvo_release(_tty);
    }
    
    NSLog(@"deallocated %@", self);
}

@end
