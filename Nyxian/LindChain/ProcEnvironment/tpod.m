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

#import <LindChain/ProcEnvironment/tpod.h>
#import <os/lock.h>

static NSMutableDictionary <NSNumber*,TaskPortObject*> *tfp_userspace_ports;
static os_unfair_lock tfp_unfair_lock = OS_UNFAIR_LOCK_INIT;

TaskPortObject *get_tpo_for_pid(pid_t pid)
{
    /* lock unfair lock for safe concurrent access */
    os_unfair_lock_lock(&tfp_unfair_lock);
    
    /* extracting task port */
    TaskPortObject *tpo = tfp_userspace_ports[@(pid)];
    
    os_unfair_lock_unlock(&tfp_unfair_lock);
    /* unlock unfair lock */
    
    /* check if task port object is usable */
    if(tpo != NULL &&
       ![tpo isUsable])
    {
        /* setting tpo to null */
        tpo = NULL;
    }
    
    /* returning task port object safely */
    return tpo;
}

bool set_tpo_for_pid(pid_t pid,
                     TaskPortObject *tpo)
{
    /* checking if tpo is nonnull */
    if(tpo == NULL ||
       ![tpo isUsable])
    {
        return false;
    }
    
    /* lock unfair lock for safe concurrent access */
    os_unfair_lock_lock(&tfp_unfair_lock);
    
    /* extracting task port */
    tfp_userspace_ports[@(pid)] = tpo;
    
    os_unfair_lock_unlock(&tfp_unfair_lock);
    /* unlock unfair lock */
    
    return true;
}

void rm_tpo_for_pid(pid_t pid)
{
    /* lock unfair lock for safe concurrent access */
    os_unfair_lock_lock(&tfp_unfair_lock);
    
    /* extracting task port */
    [tfp_userspace_ports removeObjectForKey:@(pid)];
    
    os_unfair_lock_unlock(&tfp_unfair_lock);
    /* unlock unfair lock */
}

bool add_tpo(TaskPortObject *tpo)
{
    /* null pointer check */
    if(tpo == NULL)
    {
        return false;
    }

    /* getting pid */
    pid_t pid = [tpo pid];
    
    /* checking return */
    if(pid == -1)
    {
        return false;
    }
    
    /* adding it to tpod */
    set_tpo_for_pid(pid, tpo);
    
    return true;
}

void tpod_init(void)
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        tfp_userspace_ports = [[NSMutableDictionary alloc] init];
    });
}
