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
#import <LindChain/ProcEnvironment/Surface/proc/rw.h>
#import <LindChain/ProcEnvironment/Surface/sys/syscall.h>

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

static inline void ksurface_kinit_kalloc(void)
{
    /* allocate surface */
    ksurface = malloc(sizeof(ksurface_mapping_t));
    if(ksurface == NULL)
    {
        /* in case allocation failed we go */
        environment_panic();
    }
    klog_log(@"ksurface:kinit:kalloc", @"allocated ksurface @ %p", ksurface);
}

static inline void ksurface_kinit_kinfo(void)
{
    /* setting magic */
    klog_log(@"ksurface:kinit:kinfo", @"writing magic");
    ksurface->magic = SURFACE_MAGIC;
    
    /* setting up rcu state's */
    klog_log(@"ksurface:kinit:kinfo", @"initilizing locks");
    pthread_rwlock_t *wls[2] = { &(ksurface->proc_info.rwlock),  &(ksurface->host_info.rwlock) };
    for(unsigned char i = 0; i < 2; i++)
    {
        klog_log(@"ksurface:kinit:kinfo", @"initilizing rwlock @ %p", wls[i]);
        pthread_rwlock_init(wls[i], NULL);
    }
    
    /* setting up process radix tree */
    klog_log(@"ksurface:kinit:kinfo", @"initilizing radix tree");
    ksurface->proc_info.tree.root = NULL;
    
    NSString *hostname = [[NSUserDefaults standardUserDefaults] stringForKey:@"LDEHostname"];
    if(hostname == nil)
    {
        hostname = @"localhost";
    }
    klog_log(@"ksurface:kinit:kinfo", @"setting up hostname with \"%@\"", hostname);
    strlcpy(ksurface->host_info.hostname, hostname.UTF8String, MAXHOSTNAMELEN);
}

static inline void ksurface_kinit_kproc(void)
{
    /* creating kproc */
    klog_log(@"ksurface:kinit:kproc", @"creating kernel process");
    ksurface_proc_t *kproc = proc_create(getpid(), PID_LAUNCHD, [[[NSBundle mainBundle] executablePath] UTF8String]);
    if(kproc == NULL)
    {
        /* Should never happen, panic! */
        environment_panic();
    }
    
    /* locking kproc write */
    proc_write_lock(kproc);
    
    /* setting entitlements */
    proc_setentitlements(kproc, PEEntitlementKernel);
    
    /* unlocking */
    proc_unlock(kproc);
    
    /* logging */
    klog_log(@"ksurface:kinit:kproc", @"executable_path = %s", kproc->nyx.executable_path);
    klog_log(@"ksurface:kinit:kproc", @"entitlements = %d", proc_getentitlements(kproc));
    klog_log(@"ksurface:kinit:kproc", @"pid = %d", proc_getpid(kproc));
    klog_log(@"ksurface:kinit:kproc", @"ppid = %d", proc_getppid(kproc));
    klog_log(@"ksurface:kinit:kproc", @"uid = %d", proc_getruid(kproc));
    klog_log(@"ksurface:kinit:kproc", @"gid = %d", proc_getrgid(kproc));
    
    /* storing kproc */
    ksurface->proc_info.kproc = kproc;
    
    /* inserting kproc */
    klog_log(@"ksurface:kinit:kproc", @"inserting kernel process");
    ksurface_error_t error = proc_insert(kproc);
    if(error != kSurfaceErrorSuccess)
    {
        /* Should never happen, panic! */
        environment_panic();
    }
    
    /* releaing our reference to kproc */
    proc_release(kproc);
}

void ksurface_kinit_kserver(void)
{
    /* allocating syscall server */
    ksurface->sys_server = syscall_server_create();
    
    /* null pointer check */
    if(ksurface->sys_server == NULL)
    {
        environment_panic();
    }
    
    /* printing log */
    klog_log(@"ksurface:kinit:kserver", @"allocated syscall server @ %p", ksurface->sys_server);
    
    /* registration loop */
    for(uint32_t sys_i = 0; sys_i < SYS_N; sys_i++)
    {
        /*
         * getting entry (dont check anything pointer related, this is not a attack surface, if something is wrong
         * with the syscall list entries then this shall be patched and not stay hidden
         */
        syscall_list_item_t *item = &(sys_list[sys_i]);
        
        /* registering syscall */
        syscall_server_register(ksurface->sys_server, item->sysnum, item->hndl);
        
        /* logging */
        klog_log(@"ksurface:kinit:kserver", @"registered syscall %d(%s)", item->sysnum, item->name);
    }
    
    /* starting server */
    syscall_server_start(ksurface->sys_server);
    klog_log(@"ksurface:kinit:kserver", @"started syscall server");
}

void ksurface_kinit(void)
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        if(environment_must_be_role(EnvironmentRoleHost))
        {
            /* starting huh :3 */
            klog_log(@"ksurface:kinit", @"hello from kinit");
            klog_log(@"ksurface:kinit", @"kernel commits magic spells to the iOS kernel now");
            
            /*
             * allocates the surface where everything nyxian kernel
             * related exists, structures that are made to store
             * sensitive information.
             */
            ksurface_kinit_kalloc();
            
            /*
             * sets up the surface to make it ready for everything else.
             */
            ksurface_kinit_kinfo();
            
            /*
             * creates the kernel process kproc
             */
            ksurface_kinit_kproc();
            
            /*
             * creates syscall server
             */
            ksurface_kinit_kserver();
        }
    });
}
