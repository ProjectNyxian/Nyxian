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

#import <Foundation/Foundation.h>
#import <LindChain/ProcEnvironment/Surface/sys/host/sethostname.h>
#import <LindChain/ProcEnvironment/Surface/proc/def.h>
#import <LindChain/ProcEnvironment/Surface/entitlement.h>
#import <LindChain/ProcEnvironment/Surface/proc/rw.h>
#include <regex.h>

bool is_valid_hostname_regex(const char *hostname)
{
    /* checking string lenght */
    if(strnlen(hostname, MAXHOSTNAMELEN) >= MAXHOSTNAMELEN)
    {
        return false;
    }
    
    /* compiling regex pattern once */
    static regex_t *regex;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        /* allocating this, dont make me regret this */
        regex = malloc(sizeof(regex_t));
        
        /* null terminator check */
        if(regex == NULL)
        {
            return;
        }
        
        /* compiling regex pattern */
        if(regcomp(regex, "^([a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?\\.)*[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?$", REG_EXTENDED) != 0)
        {
            /* if it fails then freeing regex and setting it to null */
            free(regex);
            regex = NULL;
        }
    });
    
    /* null pointer checking */
    if(regex == NULL)
    {
        return false;
    }
    
    /* the pattern must be valid */
    return (regexec(regex, hostname, 0, NULL, 0) == 0);
}

DEFINE_SYSCALL_HANDLER(sethostname)
{
    /* syscall wrapper */
    sys_name("SYS_sethostname");
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
    
    /* validating payload first */
    if(!is_valid_hostname_regex((const char*)in_payload))
    {
        sys_return_failure(EINVAL);
    }
    
    /* lock the lock for writing obviously now lol ^^ */
    host_write_lock();
    
    /* write to hostname */
    strlcpy(ksurface->host_info.hostname, (const char*)in_payload, MAXHOSTNAMELEN);
    
    /* updating NSUserDefaults */
    [[NSUserDefaults standardUserDefaults] setObject:[NSString stringWithCString:ksurface->host_info.hostname encoding:NSUTF8StringEncoding] forKey:@"LDEHostname"];
    
    /* unlocking lock */
    host_unlock();
    
    sys_return;
}
