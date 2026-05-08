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
#import <LindChain/ProcEnvironment/panic.h>
#import <LindChain/ProcEnvironment/Surface/surface.h>
#import <LindChain/ProcEnvironment/Surface/proc/proc.h>
#import <LindChain/ProcEnvironment/Utils/klog.h>
#import <LindChain/ProcEnvironment/Surface/sys/syscall.h>
#import <LindChain/LiveContainer/utils.h>
#import <LindChain/ProcEnvironment/Surface/sys/host/sysctl.h>

ksurface_mapping_t *ksurface = NULL;

int ksurface_sethostname(NSString *hostname)
{
    if(hostname == nil)
    {
        return -1;
    }
    
    /*
     * validates hostname in lenght
     * and formatting making sure it
     * meets networking standards.
     */
    if(!is_valid_hostname_regex([hostname UTF8String]))
    {
        return -1;
    }
    
    host_wrlock();
    klog_log("surface", "setting hostname to \"%s\"", [hostname UTF8String]);
    strlcpy(ksurface->host_info.hostname, [hostname UTF8String], MAXHOSTNAMELEN);
    host_unlock();
    
    return 0;
}

static inline void ksurface_kinit_kalloc(void)
{
    assert(ksurface == NULL);
    
    ksurface = malloc(sizeof(ksurface_mapping_t));
    if(ksurface == NULL)
    {
        /* shall never happen */
        environment_panic("allocating ksurface failed got NULL pointer from malloc");
    }
    
    klog_log("ksurface:kinit:kalloc", "allocated ksurface @ %p", ksurface);
}

static inline void ksurface_kinit_kinfo(void)
{
    /*
     * this is the install time generated CS blob
     * key used to sign executables with nyxians
     * own virtualised entitlements, which are only
     * valid within the environment.
     */
    klog_log("ksurface:kinit:kinfo", "generating code signature private key");
    if(!get_static_kernel_key(&(ksurface->priv_key), &(ksurface->priv_key_len), &(ksurface->pub_key), &(ksurface->pub_key_len)))
    {
        /* shall never happen */
        environment_panic("failed to generate static kernel crypto key");
    }
    
    /*
     * do you have to make a comment on this one -.-
     * isint it obvious~~
     * well this is for the softies which can only take
     * one at a time.
     */
    klog_log("ksurface:kinit:kinfo", "initilizing locks");
    pthread_rwlock_t *wls[4] = { &(ksurface->proc_info.struct_lock), &(ksurface->proc_info.task_lock),  &(ksurface->host_info.struct_lock), &(ksurface->tty_info.struct_lock) };
    for(unsigned char i = 0; i < 4; i++)
    {
        klog_log("ksurface:kinit:kinfo", "initilizing lock @ %p", wls[i]);
        if(pthread_rwlock_init(wls[i], NULL) != 0)
        {
            environment_panic("failed to initilize lock @ %p", wls[i]);
        }
    }
    
    /*
     * setting up process radix trees, a radix tree
     * is a very efficient data struc..., bruh
     * just use google.. im not your CS teacher.
     */
    klog_log("ksurface:kinit:kinfo", "initilizing radix trees");
    ksurface->proc_info.tree.root = NULL;
    ksurface->proc_info.proc_count = 0;
    ksurface->tty_info.tty.root = NULL;
    
    /* restoring hostname */
    NSString *hostname = [[NSUserDefaults standardUserDefaults] stringForKey:@"LDEHostname"] ?: @"localhost";
    klog_log("ksurface:kinit:kinfo", "setting up hostname with \"%s\"", [hostname UTF8String]);
    strlcpy(ksurface->host_info.hostname, hostname.UTF8String, MAXHOSTNAMELEN);
}

static inline void ksurface_kinit_kserver(void)
{
    /*
     * allocating syscall server, which is used
     * to process syscalls for our "userspace"
     * for example if the guest wants to have a
     * list of all proceses it needs to invoke
     * SYS_sysctl, on normal iOS this gets blocked
     * because of sandbox, here in this case
     * we handle the syscall and write into the
     * userspace passed buffer pointer a buffer
     * with kinfo_proc data structures.
     */
    ksurface->sys_server = syscall_server_create();
    if(ksurface->sys_server == NULL)
    {
        /* shall never happen */
        environment_panic("got NULL syscall server");
    }
    klog_log("ksurface:kinit:kserver", "allocated syscall server @ %p", ksurface->sys_server);
    
    /*
     * registers all virtualized syscalls with
     * their appropriate handlers.
     */
    for(uint32_t sys_i = 0; sys_i < SYS_N; sys_i++)
    {
        /*
         * getting entry (dont check anything pointer related, this is not a attack surface, if something is wrong
         * with the syscall list entries then this shall be patched and not stay hidden
         */
        syscall_list_item_t *item = &(sys_list[sys_i]);
        syscall_server_register(ksurface->sys_server, item->sysnum, item->hndl);
        klog_log("ksurface:kinit:kserver", "registered syscall %d (%s)", item->sysnum, item->name);
    }
    
    /* kickstarting server~~ */
    syscall_server_start(ksurface->sys_server);
    klog_log("ksurface:kinit:kserver", "started syscall server");
}

static inline void ksurface_kinit_kproc(void)
{
    /*
     * creating brand new kernel process
     * which is there so proc_fork works
     * which needs a parent process data
     * object passed and we also do it
     * so processes can know that Nyxian
     * exists and can aquire for example
     * a task name right to Nyxian.
     */
    ksurface_proc_t *kproc = kvo_alloc_fastpath(proc);
    if(kproc == NULL)
    {
        /* shall never happen */
        environment_panic("got NULL kernel process");
    }
    klog_log("ksurface:kinit:kproc", "allocated kernel process @ %p", kproc);
    
    /* writing executable path */
    uint32_t bufsize = PATH_MAX;
    if(_NSGetExecutablePath(kproc->nyx.executable_path, &bufsize) > 0)
    {
        /* shall never happen */
        environment_panic("failed to aquire executable path from dyld");
    }
    const char *name = strrchr(kproc->nyx.executable_path, '/');
    name = name ? name + 1 : kproc->nyx.executable_path;
    strlcpy(kproc->bsd.kp_proc.p_comm, name, MAXCOMLEN);
    
    /* kernel shall only expose its task name */
    task_t task;
    kern_return_t kr = task_get_special_port(mach_task_self(), TASK_NAME_PORT, &task);
    if(kr != KERN_SUCCESS)
    {
        /* shall never happen */
        environment_panic("failed to aquire task name of kernel it self");
    }
    kproc->task = task;
    
    /* setting up properties */
    proc_setpid(kproc, getpid());
    proc_setppid(kproc, PID_LAUNCHD);
    proc_setsid(kproc, proc_getpid(kproc));
    proc_setentitlements(kproc, PEEntitlementKernel);
    proc_setmaxentitlements(kproc, PEEntitlementKernel);
    
    /* storing kernel proc */
    ksurface->proc_info.kern_proc = kproc;
    klog_log("ksurface:kinit:kproc", "inserting kernel process");
    kern_return_t error = proc_insert(kproc);
    if(error != KERN_SUCCESS)
    {
        /* shall never happen */
        environment_panic("failed to insert kernel process");
    }
    
    /* releaing our reference to kernrl proc, because we return now and kproc is now held by the radix tree */
    kvo_release(kproc);
}

void ksurface_kinit(void)
{
    /* starting huh :3 (shall only run once )*/
    klog_log("ksurface:kinit", "hello from kinit");
    klog_log("ksurface:kinit", "kernel commits magic spells to the iOS kernel now");
    
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
