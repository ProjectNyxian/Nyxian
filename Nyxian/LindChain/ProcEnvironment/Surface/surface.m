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
#import <LindChain/ProcEnvironment/Utils/klog.h>
#import <LindChain/ProcEnvironment/Surface/sys/syscall.h>
#import <LindChain/LiveContainer/utils.h>

ksurface_mapping_t *ksurface = NULL;

/* TODO: check against same regex pattern as in the syscall */
void ksurface_sethostname(NSString *hostname)
{
    /* sanity check */
    if(hostname == nil &&
       [hostname length] > MAXHOSTNAMELEN)
    {
        return;
    }
    
    /* locking host info so hostname can be set */
    host_wrlock();
    
    /* setting hostname */
    klog_log(@"surface", @"setting hostname to %@", hostname);
    
    /* copying hostname over to hostinfo */
    strlcpy(ksurface->host_info.hostname, [hostname UTF8String], MAXHOSTNAMELEN);
    
    /* unlocking again */
    host_unlock();
}

static inline void ksurface_kinit_kalloc(void)
{
    /* checking if already initilized */
    if(ksurface != NULL)
    {
        /* shall only be initilized once */
        environment_panic();
    }
    
    /* allocate surface */
    ksurface = malloc(sizeof(ksurface_mapping_t));
    
    /* null pointer check */
    if(ksurface == NULL)
    {
        /* in case allocation failed we go */
        environment_panic();
    }
    
    /* logging allocation */
    klog_log(@"ksurface:kinit:kalloc", @"allocated ksurface @ %p", ksurface);
}

static inline void ksurface_kinit_kinfo(void)
{
    /* setting up locks */
    klog_log(@"ksurface:kinit:kinfo", @"initilizing locks");
    pthread_rwlock_t *wls[3] = { &(ksurface->proc_info.struct_lock), &(ksurface->proc_info.task_lock),  &(ksurface->host_info.struct_lock) };
    for(unsigned char i = 0; i < 3; i++)
    {
        klog_log(@"ksurface:kinit:kinfo", @"initilizing lock @ %p", wls[i]);
        pthread_rwlock_init(wls[i], NULL);
    }
    
    /* setting up process radix tree */
    klog_log(@"ksurface:kinit:kinfo", @"initilizing radix tree");
    ksurface->proc_info.tree.root = NULL;
    ksurface->proc_info.proc_count = 0;
    
    /* loading hostname from standard user defaults */
    NSString *hostname = [[NSUserDefaults standardUserDefaults] stringForKey:@"LDEHostname"];
    
    /* checking if hostname is even set */
    if(hostname == nil)
    {
        /* setting hostname automatically to localhost */
        hostname = @"localhost";
    }
    
    /* logging to what it will be set */
    klog_log(@"ksurface:kinit:kinfo", @"setting up hostname with \"%@\"", hostname);
    
    /* copying hostname over */
    strlcpy(ksurface->host_info.hostname, hostname.UTF8String, MAXHOSTNAMELEN);
}

static inline void ksurface_kinit_kserver(void)
{
    /* allocating syscall server */
    ksurface->sys_server = syscall_server_create();
    
    /* null pointer check */
    if(ksurface->sys_server == NULL)
    {
        /* should never happen, panic! */
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

static inline void ksurface_kinit_kproc(void)
{
    /* creating kproc */
    ksurface_proc_t *kproc = kvo_alloc(sizeof(ksurface_proc_t), GET_KVOBJECT_MAIN_EVENT_HANDLER(proc));
    
    /* null pointer check */
    if(kproc == NULL)
    {
        /* should never happen, panic! */
        environment_panic();
    }
    
    /* logging allocation */
    klog_log(@"ksurface:kinit:kproc", @"allocated kernel process @ %p", kproc);
    
    /* finding executable path */
    char *buf = malloc(PATH_MAX);
    
    /* null pointer check */
    if(buf == NULL)
    {
        /* shall not happen */
        environment_panic();
    }
    
    uint32_t bufsize = PATH_MAX;
    
    if(_NSGetExecutablePath(buf, &bufsize) > 0)
    {
        /* shall not happen */
        environment_panic();
    }
    
    /* setting up properties */
    kproc->kproc.task = environment_sendable_mach_task_self();
    proc_setpid(kproc, getpid());
    proc_setppid(kproc, PID_LAUNCHD);
    proc_setsid(kproc, proc_getpid(kproc));
    proc_setentitlements(kproc, PEEntitlementKernel);
    
    /* setting executable path */
    strlcpy(kproc->kproc.kcproc.nyx.executable_path, buf, PATH_MAX);
    const char *name = strrchr(buf, '/');
    name = name ? name + 1 : buf;
    strlcpy(kproc->kproc.kcproc.bsd.kp_proc.p_comm, name, MAXCOMLEN);
    
    /* storing kproc */
    ksurface->proc_info.kern_proc = kproc;
    
    /* inserting kproc */
    klog_log(@"ksurface:kinit:kproc", @"inserting kernel process");
    ksurface_return_t error = proc_insert(kproc);
    
    /* checking if inserting kernel process was successful */
    if(error != SURFACE_SUCCESS)
    {
        /* should never happen, panic! */
        environment_panic();
    }
    
    /* releaing our reference to kproc, because we return now and kproc is now held by the radix tree */
    kvo_release(kproc);
}

void ksurface_kinit(void)
{
    /*
     * this symbol shall only run once!!!
     */
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
            
            /* sets up the surface to make it ready for everything else */
            ksurface_kinit_kinfo();
            
            /* creates syscall server */
            ksurface_kinit_kserver();
            
            /* creates the kernel process kproc */
            ksurface_kinit_kproc();
        }
    });
}
