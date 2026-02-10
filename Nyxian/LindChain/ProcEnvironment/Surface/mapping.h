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

#ifndef PROCENVIRONMENT_MAPPING_H
#define PROCENVIRONMENT_MAPPING_H

#import <LindChain/ProcEnvironment/Surface/proc/def.h>
#import <LindChain/ProcEnvironment/Syscall/mach_syscall_server.h>
#import <LindChain/ProcEnvironment/Syscall/mach_syscall_client.h>
#import <LindChain/ProcEnvironment/Surface/radix/radix.h>
#include <stdint.h>
#include <limits.h>
#include <pthread.h>


/// Structure that holds surface information and other structures
typedef struct {
    
    /*
     * syscall server which handles certain
     * syscalls made by userspace processes.
     */
    syscall_server_t *sys_server;
    
    /*
     * structure that holds host information.
     * Such as hostname.
     */
    struct {
        
        /*
         * lock making sure rw happens not at
         * the same time
         */
        pthread_rwlock_t struct_lock;
        
        /*
         * hostname buffer, holding current hostname.
         * which can be changed by userspace with
         * enough entitlements.
         */
        char hostname[MAXHOSTNAMELEN];
    } host_info;
    
    /*
     * process information structure.
     * It holds all processes that run
     * inside of nyxian and manages them.
     */
    struct {
        
        /* rwlock securing structures */
        pthread_rwlock_t struct_lock;
        
        /* rwlock securing structures */
        pthread_rwlock_t task_lock;
        
        /*
         * count of processes currently running
         * inside of nyxian.
         */
        uint32_t proc_count;
        
        /*
         * radix tree where all processes are
         * listed inside.
         */
        radix_tree_t tree;
        
        /*
         * kernel process(aka Nyxian it self
         * running as host for the glient
         * processes).
         */
        ksurface_proc_t *kern_proc;
    } proc_info;
} ksurface_mapping_t;

#endif /* PROCENVIRONMENT_MAPPING_H */
