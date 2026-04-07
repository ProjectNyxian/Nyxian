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

#import <LindChain/ProcEnvironment/Process/PEExtension.h>
#import <LindChain/ProcEnvironment/Surface/surface.h>
#import <LindChain/ProcEnvironment/Object/PEMachPort.h>
#import <LindChain/ProcEnvironment/Syscall/mach_syscall_server.h>
#import <LindChain/ProcEnvironment/Server/Server.h>

NSExtension *PEGetNSExtensionLiveProcess(void)
{
    static NSBundle *liveProcessBundle = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        liveProcessBundle = [NSBundle bundleWithPath:[NSBundle.mainBundle.builtInPlugInsPath stringByAppendingPathComponent:@"LiveProcess.appex"]];
    });
    
    if(liveProcessBundle == nil)
    {
        return nil;
    }
    
    /* must be one NSExtension per process, idk.. the class is weirdly designed */
    NSError* error = nil;
    NSExtension* extension = [NSExtension extensionWithIdentifier:liveProcessBundle.bundleIdentifier error:&error];
    if(error)
    {
        return nil;
    }
    extension.preferredLanguages = @[];
    return extension;
}

bool PESpawnNSExtensionLiveProcess(NSDictionary *items,
                                   pid_t *pid,
                                   NSUUID **identifier,
                                   NSExtension **extension)
{
    assert(items != nil && pid != NULL && identifier != nil && extension != nil);
    
    __block NSExtension *extractedExtension = PEGetNSExtensionLiveProcess();
    *extension = extractedExtension;
    
    /* insert required items */
    NSMutableDictionary *mutableItems = [items mutableCopy];
    mutableItems[@"PESyscallPort"] = [PEMachPort portWithPortName:syscall_server_get_port(ksurface->sys_server)];
    mutableItems[@"PEEndpoint"] = [Server getTicket];   /* MARK: deprecated and soon replaced with the syscall server entirely */
    items = [mutableItems copy];
    
    /* validating presence of executable path */
    NSString *executablePath = items[@"PEExecutablePath"];
    if(executablePath == nil)
    {
        false;
    }
    
    NSExtensionItem *item = [NSExtensionItem new];
    item.userInfo = items;
    
    /* invoke execution */
    __block NSUUID *extractedIdentifier = nil;
    __block BOOL timedOut = NO;
    dispatch_semaphore_t sema = dispatch_semaphore_create(0);
    [extractedExtension beginExtensionRequestWithInputItems:@[item] completion:^(NSUUID *extensionIdentifier) {
        if(!timedOut)
        {
            extractedIdentifier = extensionIdentifier;
        }
        else
        {
            /* timed out, killing, cuz got no purpose */
            [extractedExtension _kill:SIGKILL];
        }
        dispatch_semaphore_signal(sema);
    }];
    long result = dispatch_semaphore_wait(sema, dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)));
    
    if(result != 0)
    {
        timedOut = YES;
        return false;
    }
    
    /* checking if execution it self suceeded */
    if(extractedIdentifier == nil)
    {
        return false;
    }
    *identifier = extractedIdentifier;
    
    *pid = [extractedExtension pidForRequestIdentifier:*identifier];
    
    /*
     * checking if process is still valid
     * we need its BSD process identifier.
     */
    if(*pid < 0)
    {
        return false;
    }
    
    return true;
}
