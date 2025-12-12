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

static id _Nullable sync_call_with_timeout(void (^invoke)(void (^reply)(id)))
{
    __block id result = nil;
    dispatch_semaphore_t sem = dispatch_semaphore_create(0);

    invoke(^(id obj){
        result = obj;
        dispatch_semaphore_signal(sem);
    });

    long waited = dispatch_semaphore_wait(
        sem,
        dispatch_time(DISPATCH_TIME_NOW, (int64_t)(PROXY_MAX_DISPATCH_TIME * NSEC_PER_SEC))
    );
    if (waited != 0) return nil; // timeout
    return result;
}

static unsigned int sync_call_with_timeout_uint(void (^invoke)(void (^reply)(unsigned int)))
{
    __block unsigned int result = -1;
    dispatch_semaphore_t sem = dispatch_semaphore_create(0);

    invoke(^(unsigned int val){
        result = val;
        dispatch_semaphore_signal(sem);
    });

    long waited = dispatch_semaphore_wait(
        sem,
        dispatch_time(DISPATCH_TIME_NOW, (int64_t)(PROXY_MAX_DISPATCH_TIME * NSEC_PER_SEC))
    );
    return (waited == 0) ? result : -1;
}

int environment_proxy_proc_kill_process_identifier(pid_t process_identifier,
                                                   int signal)
{
    environment_must_be_role(EnvironmentRoleGuest);
    return (int)environment_syscall(SYS_KILL, process_identifier, signal);
}

pid_t environment_proxy_spawn_process_at_path(NSString *path,
                                              NSArray *arguments,
                                              NSDictionary *environment,
                                              FDMapObject *mapObject)
{
    environment_must_be_role(EnvironmentRoleGuest);
    return sync_call_with_timeout_uint(PROXY_TYPE_REPLY(unsigned int){
        [hostProcessProxy spawnProcessWithPath:path withArguments:arguments withEnvironmentVariables:environment withMapObject:mapObject withReply:reply];
    });
}

// FIXME: Frida, fix those two following garbage syscall wrappers
void environment_proxy_getproctable(kinfo_proc_t **pt, uint32_t *pt_cnt)
{
    environment_must_be_role(EnvironmentRoleGuest);
    
    kinfo_proc_t kp[PROC_MAX];
    uint32_t len;
    
    environment_syscall(SYS_PROCTB, &kp, &len);
    
    *pt = malloc(len);
    memcpy(*pt, kp, len);
    *pt_cnt = (uint32_t)(len / sizeof(kinfo_proc_t));
}

void environment_proxy_sign_macho(NSString *path)
{
    environment_must_be_role(EnvironmentRoleGuest);
    
    /* open file descriptor */
    int fd = open([path UTF8String], O_RDWR);
    
    /* checking file descriptor */
    if(fd == -1)
    {
        return;
    }
    
    /* calling syscall */
    environment_syscall(SYS_SIGNEXEC, fd);
    
    /* closing file descriptor */
    close(fd);
}

void environment_proxy_set_endpoint_for_service_identifier(NSXPCListenerEndpoint *endpoint,
                                                           NSString *serviceIdentifier)
{
    [hostProcessProxy setEndpoint:endpoint forServiceIdentifier:serviceIdentifier];
}

NSXPCListenerEndpoint *environment_proxy_get_endpoint_for_service_identifier(NSString *serviceIdentifier)
{
    environment_must_be_role(EnvironmentRoleGuest);
    return sync_call_with_timeout(PROXY_TYPE_REPLY(NSXPCListenerEndpoint*){
        [hostProcessProxy getEndpointOfServiceIdentifier:serviceIdentifier withReply:reply];
    });
}

void environment_proxy_set_snapshot(UIImage *snapshot)
{
    environment_must_be_role(EnvironmentRoleGuest);
    [hostProcessProxy setSnapshot:snapshot];
}

void environment_proxy_waittrap(void)
{
    // MARK: Trapping till the host says it added us to the proc map
    dispatch_semaphore_t sema = dispatch_semaphore_create(0);
    [hostProcessProxy waitTillAddedTrapWithReply:^(BOOL added){
        if(added)
        {
            dispatch_semaphore_signal(sema);
        }
        else
        {
            exit(0);
        }
    }];
    dispatch_semaphore_wait(sema, DISPATCH_TIME_FOREVER);
}

knyx_proc_t environment_proxy_nyxcopy(pid_t pid)
{
    environment_must_be_role(EnvironmentRoleGuest);
    NSData *ret = sync_call_with_timeout(PROXY_TYPE_REPLY(NSData*){
        [hostProcessProxy getProcessNyxWithIdentifier:pid withReply:reply];
    });
    return *((knyx_proc_t*)(ret.bytes));
}
