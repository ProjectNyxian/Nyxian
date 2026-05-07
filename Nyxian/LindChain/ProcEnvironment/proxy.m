/*
 SPDX-License-Identifier: AGPL-3.0-or-later

 Copyright (C) 2025 - 2026 mach-port-t

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

#import <LindChain/ProcEnvironment/environment.h>
#import <LindChain/ProcEnvironment/proxy.h>
#include <signal.h>
#include <errno.h>
#import <LindChain/ProcEnvironment/Surface/sys/syscall.h>
#import <LindChain/ProcEnvironment/syscall.h>

#define PROXY_MAX_DISPATCH_TIME 1.0
#define PROXY_TYPE_REPLY(type) ^(void (^reply)(type))

NSObject<ServerProtocol> *hostProcessProxy = nil;
syscall_client_t *syscallProxy = NULL;

static int64_t sync_call_with_timeout_int64(void (^invoke)(void (^reply)(int64_t)))
{
    __block int64_t result = -1;
    dispatch_semaphore_t sem = dispatch_semaphore_create(0);

    invoke(^(int64_t val){
        result = val;
        dispatch_semaphore_signal(sem);
    });

    long waited = dispatch_semaphore_wait(
        sem,
        dispatch_time(DISPATCH_TIME_NOW, (int64_t)(PROXY_MAX_DISPATCH_TIME * NSEC_PER_SEC))
    );
    return (waited == 0) ? result : -1;
}

int64_t environment_proxy_spawn_process_at_path(NSString *path,
                                                NSArray *arguments,
                                                NSDictionary *environment,
                                                FDMapObject *mapObject,
                                                NSString *workingDirectory)
{
    return sync_call_with_timeout_int64(PROXY_TYPE_REPLY(int64_t){
        [hostProcessProxy spawnProcessWithPath:path withArguments:arguments withEnvironmentVariables:environment withMapObject:mapObject withWorkingDirectory:workingDirectory withReply:reply];
    });
}

void environment_proxy_set_snapshot(UIImage *snapshot)
{
    [hostProcessProxy setSnapshot:snapshot];
}
