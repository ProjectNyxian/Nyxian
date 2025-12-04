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
    klog_log(@"ksurface:kinit:kalloc", @"allocated ksurface at %p", ksurface);
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
        klog_log(@"ksurface:kinit:kinfo", @"setting up rwlock at %p", wls[i]);
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
    
    /* FIXME: PEEntitlementKernel breaks spawning daemons */
    /* locking kproc write */
    //proc_write_lock(kproc);
    
    /* setting entitlements */
    //proc_setentitlements(kproc, PEEntitlementKernel);
    
    /* unlocking */
    //proc_read_lock(kproc);
    
    /* logging */
    klog_log(@"ksurface:kinit:kproc", @"executable_path = %s", kproc->nyx.executable_path);
    klog_log(@"ksurface:kinit:kproc", @"entitlements = %d", proc_getentitlements(kproc));
    klog_log(@"ksurface:kinit:kproc", @"pid = %d", proc_getpid(kproc));
    klog_log(@"ksurface:kinit:kproc", @"ppid = %d", proc_getppid(kproc));
    klog_log(@"ksurface:kinit:kproc", @"uid = %d", proc_getuid(kproc));
    klog_log(@"ksurface:kinit:kproc", @"gid = %d", proc_getgid(kproc));
    
    /* storing kproc */
    ksurface->proc_info.kproc = kproc;
    
    /* inserting kproc */
    klog_log(@"ksurface:kproc:kinit", @"inserting kernel process");
    ksurface_error_t error = proc_insert(kproc);
    if(error != kSurfaceErrorSuccess)
    {
        /* Should never happen, panic! */
        environment_panic();
    }
    
    /* releaing our reference to kproc */
    proc_release(kproc);
}

void ksurface_kinit_kdump(void)
{
    klog_log(@"ksurface:kinit:kdump", @"dumping information");
    
    /* null pointer check */
    if(ksurface == NULL)
    {
        klog_log(@"ksurface:kinit:kdump", @"ERROR: ksurface is NULL!");
        return;
    }
    
    /* main structure */
    klog_log(@"ksurface:kinit:kdump", @"[ksurface_mapping_t] @ %p (size: %zu bytes)", ksurface, sizeof(ksurface_mapping_t));
    klog_log(@"ksurface:kinit:kdump", @"  magic: 0x%08X (%s)", ksurface->magic, ksurface->magic == SURFACE_MAGIC ? "VALID" : "INVALID");
    
    /* host information */
    klog_log(@"ksurface:kinit:kdump", @"");
    klog_log(@"ksurface:kinit:kdump", @"[ksurface_host_info_t] @ %p (size: %zu bytes)", &ksurface->host_info, sizeof(ksurface_host_info_t));
    klog_log(@"ksurface:kinit:kdump", @"  hostname: \"%s\"", ksurface->host_info.hostname);
    klog_log(@"ksurface:kinit:kdump", @"  rwlock: %p", &ksurface->host_info.rwlock);
    
    /* process information */
    klog_log(@"ksurface:kinit:kdump", @"");
    klog_log(@"ksurface:kinit:kdump", @"[ksurface_proc_info_t] @ %p (size: %zu bytes)",
             &ksurface->proc_info, sizeof(ksurface_proc_info_t));
    klog_log(@"ksurface:kinit:kdump", @"  pcnt: %u / %d (PROC_MAX)", ksurface->proc_info.pcnt, PROC_MAX);
    klog_log(@"ksurface:kinit:kdump", @"  kproc: %p", ksurface->proc_info.kproc);
    klog_log(@"ksurface:kinit:kdump", @"  tree: %p", &ksurface->proc_info.tree);
    klog_log(@"ksurface:kinit:kdump", @"  rwlock: %p", &ksurface->proc_info.rwlock);
    
    /* size information */
    klog_log(@"ksurface:kinit:kdump", @"");
    klog_log(@"ksurface:kinit:kdump", @"--- Structure Sizes ---");
    klog_log(@"ksurface:kinit:kdump", @"  sizeof(ksurface_mapping_t):      %zu bytes", sizeof(ksurface_mapping_t));
    klog_log(@"ksurface:kinit:kdump", @"  sizeof(ksurface_host_info_t):    %zu bytes", sizeof(ksurface_host_info_t));
    klog_log(@"ksurface:kinit:kdump", @"  sizeof(ksurface_proc_info_t):    %zu bytes", sizeof(ksurface_proc_info_t));
    klog_log(@"ksurface:kinit:kdump", @"  sizeof(ksurface_proc_t):         %zu bytes", sizeof(ksurface_proc_t));
    klog_log(@"ksurface:kinit:kdump", @"  sizeof(ksurface_proc_children_t):%zu bytes", sizeof(ksurface_proc_children_t));
    klog_log(@"ksurface:kinit:kdump", @"  sizeof(knyx_proc_t):             %zu bytes", sizeof(knyx_proc_t));
    klog_log(@"ksurface:kinit:kdump", @"  sizeof(kinfo_proc_t):            %zu bytes", sizeof(kinfo_proc_t));
    
    /* limits */
    klog_log(@"ksurface:kinit:kdump", @"");
    klog_log(@"ksurface:kinit:kdump", @"--- Configuration Limits ---");
    klog_log(@"ksurface:kinit:kdump", @"  PROC_MAX:       %d", PROC_MAX);
    klog_log(@"ksurface:kinit:kdump", @"  PID_MAX:        %d", PID_MAX);
    klog_log(@"ksurface:kinit:kdump", @"  CHILD_PROC_MAX: %d", CHILD_PROC_MAX);
    klog_log(@"ksurface:kinit:kdump", @"  PATH_MAX:       %d", PATH_MAX);
    klog_log(@"ksurface:kinit:kdump", @"  MAXHOSTNAMELEN: %d", MAXHOSTNAMELEN);
    
    /* memory footprint estimation*/
    size_t kproc_total = sizeof(ksurface_proc_t) * PROC_MAX;
    klog_log(@"ksurface:kinit:kdump", @"");
    klog_log(@"ksurface:kinit:kdump", @"--- Memory Footprint ---");
    klog_log(@"ksurface:kinit:kdump", @"  radix tree (max): %zu bytes (%.2f MB)", kproc_total, (double)kproc_total / (1024.0 * 1024.0));
    klog_log(@"ksurface:kinit:kdump", @"------------------------");
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
             * creats the kernel process kproc
             */
            ksurface_kinit_kproc();
            
            /*
             * dumps structure information
             */
            ksurface_kinit_kdump();
        }
    });
}
