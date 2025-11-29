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
#import <LindChain/ProcEnvironment/panic.h>
#import <LindChain/ProcEnvironment/Surface/surface.h>
#import <LindChain/ProcEnvironment/Surface/proc/proc.h>
#import <LindChain/ProcEnvironment/proxy.h>
#import <LindChain/litehook/src/litehook.h>
#import <mach/mach.h>
#import <sys/sysctl.h>
#import <mach-o/dyld.h>
#import <LindChain/ProcEnvironment/Utils/klog.h>

ksurface_mapping_t *ksurface = NULL;

/*
 Experimental hooks & implementations
 */
DEFINE_HOOK(gethostname, int, (char *buf, size_t bufsize))
{
    /*unsigned long seq;
    
    do
    {
        seq = reflock_read_begin(&(surface->reflock));
        strlcpy(buf, surface->host_info.hostname, bufsize);
    }
    while(reflock_read_retry(&(surface->reflock), seq));*/
    
    return 0;
}

void kern_sethostname(NSString *hostname)
{
    /*klog_log(@"surface", @"setting hostname to %@", hostname);
    hostname = hostname ?: @"localhost";
    strlcpy(surface->host_info.hostname, [hostname UTF8String], MAXHOSTNAMELEN);*/
    
    
}

static inline void ksurface_kalloc(void)
{
    /* allocate surface */
    ksurface = malloc(sizeof(ksurface_mapping_t));
    if(ksurface == NULL)
    {
        /* in case allocation failed we go */
        environment_panic();
    }
}

static inline void ksurface_kinit(void)
{
    /* setting magic */
    ksurface->magic = SURFACE_MAGIC;
    
    /* setting up rcu state's */
    pthread_mutex_t *wls[2] = { &(ksurface->proc_info.wl),  &(ksurface->host_info.wl) };
    rcu_state_t *states[2] = { &(ksurface->proc_info.rcu), &(ksurface->host_info.rcu) };
    for(unsigned char i = 0; i < 2; i++)
    {
        pthread_mutex_init(wls[i], NULL);
        states[i]->current_epoch = 0;
        pthread_mutex_init(&(states[i]->gp_lock), NULL);
        pthread_mutex_init(&(states[i]->registry_lock), NULL);
        memset(states[i]->thread_state, 0, sizeof(states[i]->thread_state));
    }
    
    /* setting up process table */
    ksurface->proc_info.proc_count = 0;
    for(int i = 0; i < PROC_MAX; i++)
    {
        ksurface->proc_info.proc[i] = NULL;
    }
    
    NSString *hostname = [[NSUserDefaults standardUserDefaults] stringForKey:@"LDEHostname"];
    if(hostname == nil) hostname = @"localhost";
    strlcpy(ksurface->host_info.hostname, hostname.UTF8String, MAXHOSTNAMELEN);
}

void ksurface_init(void)
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        if(environment_must_be_role(EnvironmentRoleHost))
        {
            ksurface_kalloc();
            ksurface_kinit();
        }
    });
}
