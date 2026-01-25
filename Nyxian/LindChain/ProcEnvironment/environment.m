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
#import <LindChain/ProcEnvironment/syscall.h>
#import <LindChain/ProcEnvironment/Surface/extra/relax.h>
#import <LindChain/Debugger/MachServer.h>
#import <LindChain/LiveContainer/LCBootstrap.h>
#include <dlfcn.h>

static EnvironmentRole environmentRole = EnvironmentRoleNone;

#pragma mark - Special client extra symbols

void environment_client_connect_to_host(NSXPCListenerEndpoint *endpoint)
{
    // FIXME: We cannot check the environment if the environment is not setup yet
    if(hostProcessProxy) return;
    NSXPCConnection* connection = [[NSXPCConnection alloc] initWithListenerEndpoint:endpoint];
    connection.remoteObjectInterface = [NSXPCInterface interfaceWithProtocol:@protocol(ServerProtocol)];
    connection.interruptionHandler = ^{
        NSLog(@"Connection to app interrupted");
        exit(0);
    };
    connection.invalidationHandler = ^{
        NSLog(@"Connection to app invalidated");
        exit(0);
    };
    
    [connection activate];
    hostProcessProxy = connection.remoteObjectProxy;
}

void environment_client_connect_to_syscall_proxy(MachPortObject *mpo)
{
    /* creating client*/
    syscall_client_t *client = syscall_client_create([mpo port]);
    
    /* null pointer check */
    if(client == NULL)
    {
        return;
    }
    
    /* setting syscall proxy */
    syscallProxy = client;
}

void environment_client_attach_debugger(void)
{
    environment_must_be_role(EnvironmentRoleGuest);
    machServerInit();
}

#pragma mark - Role/Restriction checkers and enforcers

BOOL environment_is_role(EnvironmentRole role)
{
    return (environmentRole == role);
}

BOOL environment_must_be_role(EnvironmentRole role)
{
    if(!environment_is_role(role))
        abort();
    else
        return YES;
}

#pragma mark - Initilizer

void environment_init(EnvironmentRole role,
                      EnvironmentExec exec,
                      const char *executablePath,
                      int argc,
                      char *argv[])
{
    /* checking role */
    if(role > EnvironmentRoleGuest)
    {
        fprintf(stderr, "[!] invalid role\n");
        exit(1);
    }
    
    /* making sure this is only initilized once */
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        /* checking role */
        
        /* setting environment role */
        environmentRole = role;
        
        /* initilizing subsystems of environment */
        environment_libproc_init();
        environment_application_init();
        environment_posix_spawn_init();
        environment_fork_init();
        environment_sysctl_init();
        environment_cred_init();
        environment_hostname_init();
        
        /* kernel start vs handshake */
        if(role == EnvironmentRoleHost)
        {
            /*
             * since guest processes usually dont have
             * this, we have to dynamically find the
             * init symbol of the kernel.
             */
            void (*ksurface_kinit_dyn)(void) = dlsym(RTLD_DEFAULT, "ksurface_kinit");
            if(ksurface_kinit_dyn)
            {
                ksurface_kinit_dyn();
            }
            else
            {
                fprintf(stderr, "[!] couldnt find ksurface_kinit\n");
                exit(1);
            }
        }
        else
        {
            /*
             * waiting till syscalling starts to work
             * for this process before handing off
             * control to some executable.
             */
            while(environment_syscall(SYS_getpid) < 0)
            {
                relax();
            }
        }
        
        /*
         * task_for_pid(3) is fixed last, because otherwise
         * a other process could compromise this process
         * easily which we ofc shall not let happen.
         */
        environment_tfp_init();
        
        /* invoking code execution or let it return */
        if(exec == EnvironmentExecLiveContainer)
        {
            LCBootstrapMain([NSString stringWithCString:executablePath encoding:NSUTF8StringEncoding], argc, argv);
        }
    });
}
