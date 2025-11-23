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
#import <LindChain/ProcEnvironment/Server/Server.h>
#import <LindChain/ProcEnvironment/Surface/proc/proc.h>

@implementation LDEProcess

- (instancetype)initWithItems:(NSDictionary*)items
            withConfiguration:(LDEProcessConfiguration*)configuration
{
    self = [super init];
    
    self.displayName = @"LiveProcess";
    self.executablePath = items[@"LSExecutablePath"];
    if(self.executablePath == nil) return nil;
    else self.displayName = [[NSURL fileURLWithPath:self.executablePath] lastPathComponent];
    self.wid = (wid_t)-1;
    
    NSBundle *liveProcessBundle = [NSBundle bundleWithPath:[NSBundle.mainBundle.builtInPlugInsPath stringByAppendingPathComponent:@"LiveProcess.appex"]];
    if(!liveProcessBundle) {
        return nil;
    }
    
    NSError* error = nil;
    _extension = [NSExtension extensionWithIdentifier:liveProcessBundle.bundleIdentifier error:&error];
    if(error) {
        return nil;
    }
    _extension.preferredLanguages = @[];
    
    NSExtensionItem *item = [NSExtensionItem new];
    item.userInfo = items;
    
    __weak typeof(self) weakSelf = self;
    
    dispatch_semaphore_t sema = dispatch_semaphore_create(0);
    [_extension beginExtensionRequestWithInputItems:@[item] completion:^(NSUUID *identifier) {
        if(identifier)
        {
            if(weakSelf == nil) return;
            __typeof(self) strongSelf = weakSelf;
            
            weakSelf.identifier = identifier;
            weakSelf.pid = [weakSelf.extension pidForRequestIdentifier:weakSelf.identifier];
            RBSProcessPredicate* predicate = [PrivClass(RBSProcessPredicate) predicateMatchingIdentifier:@(weakSelf.pid)];
            weakSelf.processMonitor = [PrivClass(RBSProcessMonitor) monitorWithPredicate:predicate updateHandler:^(RBSProcessMonitor *monitor, RBSProcessHandle *handle, RBSProcessStateUpdate *update) {
                // Interestingly, when a process exits, the process monitor says that there is no state, so we can use that as a logic check
                NSArray<RBSProcessState *> *states = [monitor states];
                if([states count] == 0)
                {
                    // Process dead!
                    dispatch_once(&strongSelf->_removeOnce, ^{
                        if(self.wid != -1) [[LDEWindowServer shared] closeWindowWithIdentifier:strongSelf.wid];
                        [[LDEProcessManager shared] unregisterProcessWithProcessIdentifier:strongSelf.pid];
                        if(strongSelf.exitingCallback) strongSelf.exitingCallback();
                    });
                }
                else
                {
                    // Setting process handle directly from process monitor
                    weakSelf.processHandle = handle;
                    
                    // TODO: We gonna shrink down this part more and more to move the tasks all slowly to surface
                    ksurface_error_t error = kSurfaceErrorUndefined;
                    if(configuration.ppid != getpid())
                    {
                        error = proc_new_child_proc(configuration.ppid, weakSelf.pid, weakSelf.executablePath);
                    }
                    else
                    {
                        error = proc_new_proc(configuration.ppid, weakSelf.pid, configuration.uid, configuration.gid, weakSelf.executablePath);
                    }
                    
                    if(error != kSurfaceErrorSuccess)
                    {
                        [weakSelf terminate];
                    }
                }
            }];
        }
        dispatch_semaphore_signal(sema);
    }];
    dispatch_semaphore_wait(sema, DISPATCH_TIME_FOREVER);
    
    return self;
}

- (instancetype)initWithPath:(NSString*)binaryPath
               withArguments:(NSArray *)arguments
    withEnvironmentVariables:(NSDictionary*)environment
               withMapObject:(FDMapObject*)mapObject
           withConfiguration:(LDEProcessConfiguration*)configuration
{
    NSMutableDictionary *dictionary = [NSMutableDictionary dictionaryWithDictionary:@{
        @"LSEndpoint": [Server getTicket],
        @"LSServiceMode": @"spawn",
        @"LSExecutablePath": binaryPath,
        @"LSArguments": arguments,
        @"LSEnvironment": environment
    }];
    
    if(mapObject != nil)
    {
        [dictionary setObject:mapObject forKey:@"LSMapObject"];
    }
    
    self = [self initWithItems:[dictionary copy] withConfiguration:configuration];
    
    return self;
}

/*
 Action
 */
- (void)sendSignal:(int)signal
{
    if(signal == SIGSTOP)
        _isSuspended = YES;
    else if(signal == SIGCONT)
        _isSuspended = NO;
    
    [self.extension _kill:signal];
}

- (BOOL)suspend
{
    if(!_audioBackgroundModeUsage)
    {
        [self sendSignal:SIGSTOP];
        return YES;
    }
    else
    {
        return NO;
    }
}

- (BOOL)resume
{
    [self sendSignal:SIGCONT];
    return YES;
}

- (BOOL)terminate
{
    [self sendSignal:SIGKILL];
    return YES;
}

- (void)setRequestCancellationBlock:(void(^)(NSUUID *uuid, NSError *error))callback
{
    [_extension setRequestCancellationBlock:callback];
}

- (void)setRequestInterruptionBlock:(void(^)(NSUUID *uuid))callback
{
    [_extension setRequestInterruptionBlock:callback];
}

- (void)setExitingCallback:(void(^)(void))callback
{
    _exitingCallback = callback;
}

@end
