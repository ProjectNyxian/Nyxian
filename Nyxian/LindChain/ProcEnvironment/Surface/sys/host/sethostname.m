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

#import <LindChain/ProcEnvironment/Surface/sys/host/sethostname.h>
#import <LindChain/ProcEnvironment/Surface/proc/def.h>
#import <LindChain/ProcEnvironment/Surface/entitlement.h>

DEFINE_SYSCALL_HANDLER(sethostname)
{
    /* checking input payload */
    sys_need_in_payload_with_len(1);
    
    /*
     * check permitives
     * root user and platform processes shall be entitled to set hostname
     * and processes entitled with PEEntitlementHostManager
     */
    if(proc_geteuid(sys_proc_copy_) != 0 &&
       !entitlement_got_entitlement(proc_getentitlements(sys_proc_copy_), PEEntitlementPlatform) &&
       !entitlement_got_entitlement(proc_getentitlements(sys_proc_copy_), PEEntitlementHostManager))
    {
        sys_return_failure(EPERM);
    }
    
    /* lock the lock for writing obviously now lol ^^ */
    pthread_rwlock_wrlock(&(ksurface->host_info.rwlock));
    
    /* write to hostname */
    strlcpy(ksurface->host_info.hostname, (const char*)in_payload, MAXHOSTNAMELEN);
    
    /* updating NSUserDefaults */
    [[NSUserDefaults standardUserDefaults] setObject:[NSString stringWithCString:ksurface->host_info.hostname encoding:NSUTF8StringEncoding] forKey:@"LDEHostname"];
    
    /* unlocking lock */
    pthread_rwlock_unlock(&(ksurface->host_info.rwlock));
    return 0;
}
