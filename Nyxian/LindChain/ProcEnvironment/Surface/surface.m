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

int ksurface_proc_info_thread_register(void)
{
    return ksurface ? rcu_register_thread(&(ksurface->proc_info.rcu)) : -1;
}

void ksurface_proc_info_thread_unregister(void)
{
    if(ksurface == NULL)
    {
        rcu_unregister_thread(&ksurface->proc_info.rcu);
    }
}

int ksurface_host_info_thread_register(void)
{
    return ksurface ? rcu_register_thread(&(ksurface->host_info.rcu)) : -1;
}

void ksurface_host_info_thread_unregister(void)
{
    if(ksurface == NULL)
    {
        rcu_unregister_thread(&ksurface->host_info.rcu);
    }
}

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
    klog_log(@"ksurface:kalloc", @"allocated surface at %p", ksurface);
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
        klog_log(@"ksurface:kinit", @"setting up rcu state %p", states[i]);
        pthread_mutex_init(wls[i], NULL);
        states[i]->current_epoch = 0;
        pthread_mutex_init(&(states[i]->gp_lock), NULL);
        pthread_mutex_init(&(states[i]->registry_lock), NULL);
        klog_log(@"ksurface:kinit", @"setting up mutex %p", wls[i]);
        memset(states[i]->thread_state, 0, sizeof(states[i]->thread_state));
    }
    
    /* setting up process table */
    klog_log(@"ksurface:kinit", @"setting up process table");
    ksurface->proc_info.proc_count = 0;
    for(int i = 0; i < PROC_MAX; i++)
    {
        ksurface->proc_info.proc[i] = NULL;
    }
    
    klog_log(@"ksurface:kinit", @"setting up hostname");
    NSString *hostname = [[NSUserDefaults standardUserDefaults] stringForKey:@"LDEHostname"];
    if(hostname == nil) hostname = @"localhost";
    strlcpy(ksurface->host_info.hostname, hostname.UTF8String, MAXHOSTNAMELEN);
}

static inline void ksurface_kproc_init(void)
{
    ksurface_proc_info_thread_register();
    
    /* creating kproc */
    klog_log(@"ksurface:kproc:init", @"creating kernel process");
    ksurface_proc_t *proc = proc_create(getpid(), PID_LAUNCHD, [[[NSBundle mainBundle] bundlePath] UTF8String]);
    if(proc == NULL)
    {
        ksurface_proc_info_thread_unregister();
        return;
    }
    
    /* inserting kproc */
    klog_log(@"ksurface:kproc:init", @"inserting kernel process");
    ksurface_error_t error = proc_insert(proc);
    if(error != kSurfaceErrorSuccess)
    {
        /* Should never happen, panic! */
        environment_panic();
    }
    
    /* releaing our reference to kproc */
    proc_release(proc);
    
    ksurface_proc_info_thread_unregister();
}

void ksurface_init(void)
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        if(environment_must_be_role(EnvironmentRoleHost))
        {
            ksurface_kalloc();
            ksurface_kinit();
            ksurface_kproc_init();
        }
    });
}
