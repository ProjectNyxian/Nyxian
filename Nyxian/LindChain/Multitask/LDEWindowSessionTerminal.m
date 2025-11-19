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

#import <LindChain/Multitask/LDEProcessManager.h>
#import <LindChain/Multitask/LDEWindowSessionTerminal.h>
#import <Nyxian-Swift.h>

@interface LDEWindowSessionTerminal ()

@property (nonatomic,strong) NyxianTerminal *terminal;

@end

@implementation LDEWindowSessionTerminal

@synthesize windowName;
@synthesize windowSize;
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
    int stdoutPipe[2];
    int stderrPipe[2];
    int stdinPipe[2];
    
    pipe(stdoutPipe);
    pipe(stderrPipe);
    pipe(stdinPipe);
    
    FDMapObject *mapObject = [FDMapObject emptyMap];
    [mapObject insertStdPipe:stdoutPipe StdErrPipe:stderrPipe StdInPipe:stdinPipe];
    LDEProcess *process = nil;
    [[LDEProcessManager shared] spawnProcessWithPath:_utilityPath withArguments:@[] withEnvironmentVariables:@{} withMapObject:mapObject withConfiguration:[LDEProcessConfiguration userApplicationConfiguration] process:&process];
    process.wid = identifier;
    
    close(stderrPipe[0]);
    close(stderrPipe[1]);
    
    _terminal = [[NyxianTerminal alloc] initWithFrame:CGRectMake(0, 0, 100, 100) title:[process displayName] stdoutFD:stdoutPipe[0] stdinFD:stdinPipe[1]];
    
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
{
}

- (void)activateWindow
{
}


- (void)deactivateWindow
{
}


- (UIImage *)snapshotWindow
{
    return nil;
}


- (void)windowChangesSizeToRect:(CGRect)rect
{
    _heigthConstraint.constant = rect.size.height;
    _widthConstraint.constant = rect.size.width;
}

@end
