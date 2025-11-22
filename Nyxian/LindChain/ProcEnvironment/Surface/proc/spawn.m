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

#import <LindChain/ProcEnvironment/Surface/proc/spawn.h>
#import <LindChain/ProcEnvironment/Surface/proc/new.h>
#import <LindChain/ProcEnvironment/Surface/proc/def.h>
#import <LindChain/ProcEnvironment/Server/Server.h>
#import <LindChain/Multitask/LDEWindowServer.h>

ksurface_error_t proc_spawn(ksurface_proc_t *parent,
                            uid_t uid,
                            gid_t gid,
                            PEEntitlement entitlement,
                            NSString *mode,
                            NSString *path,
                            NSArray<NSString*> *arg,
                            NSDictionary<NSString*,NSString*> *env)
{
#ifdef HOST_ENV
    // Executing the process huh :)
    NSBundle *liveProcessBundle = [NSBundle bundleWithPath:[NSBundle.mainBundle.builtInPlugInsPath stringByAppendingPathComponent:@"LiveProcess.appex"]];
    if(!liveProcessBundle)
    {
        return kSurfaceErrorUndefined;
    }
    
    NSError* error = nil;
    NSExtension *extension = [NSExtension extensionWithIdentifier:liveProcessBundle.bundleIdentifier error:&error];
    if(error)
    {
        return kSurfaceErrorUndefined;
    }
    extension.preferredLanguages = @[];
    
    NSExtensionItem *item = [NSExtensionItem new];
    item.userInfo = @{
        @"LSEndpoint": [Server getTicket],
        @"LSServiceMode": mode,
        @"LSExecutablePath": path,
        @"LSArguments": arg,
        @"LSEnvironment": env
    };
    
    __block RBSProcessHandle *handle = nil;
    __block RBSProcessMonitor *monitor = nil;
    __block NSUUID *identifier = nil;
    __block pid_t pid;
    __block ksurface_proc_t *proc;
    __block ksurface_error_t kerror = kSurfaceErrorSuccess;
    pid_t ppid = proc_getppid((*parent));
    
    dispatch_semaphore_t sema = dispatch_semaphore_create(0);
    [extension beginExtensionRequestWithInputItems:@[item] completion:^(NSUUID *identifier_) {
        if(identifier_)
        {
            identifier = identifier_;
            pid = [extension pidForRequestIdentifier:identifier_];
            NSLog(@"Spawned: %d", pid);
            
            // TODO: We gonna shrink down this part more and more to move the tasks all slowly to surface
            kerror = kSurfaceErrorUndefined;
            if(parent != kernel_proc_)
            {
                kerror = proc_new_child_proc_v2(kernel_proc_, pid, path, &proc);
            }
            else
            {
                kerror = proc_new_proc_v2(ppid, pid, uid, gid, path, entitlement, &proc);
            }
            
            if(kerror != kSurfaceErrorSuccess)
            {
                [extension _kill:SIGKILL];
            }
            
            NSLog(@"Allocated process structure: %p", proc);
            
            RBSProcessPredicate* predicate = [PrivClass(RBSProcessPredicate) predicateMatchingIdentifier:@(pid)];
            monitor = [PrivClass(RBSProcessMonitor) monitorWithPredicate:predicate updateHandler:^(RBSProcessMonitor *monitor, RBSProcessHandle *_handle, RBSProcessStateUpdate *update) {
                // Setting process handle directly from process monitor
                handle = _handle;
                
                // Interestingly, when a process exits, the process monitor says that there is no state, so we can use that as a logic check
                NSArray<RBSProcessState *> *states = [monitor states];
                if([states count] == 0)
                {
                    NSLog(@"Process died!");
                    // Process dead!
                    /*dispatch_once(&(proc->nyx.removeOnce), ^{
                        if(self.wid != -1) [[LDEWindowServer shared] closeWindowWithIdentifier:strongSelf.wid];
                        [[LDEProcessManager shared] unregisterProcessWithProcessIdentifier:strongSelf.pid];
                        if(strongSelf.exitingCallback) strongSelf.exitingCallback();
                    });*/
                }
            }];
        }
        dispatch_semaphore_signal(sema);
    }];
    dispatch_semaphore_wait(sema, DISPATCH_TIME_FOREVER);
    
    return kerror;
#else
    return kSurfaceErrorUndefined;
#endif /* HOST_ENV */
}
