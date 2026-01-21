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

#import <LindChain/ProcEnvironment/Surface/sys/host/gethostname.h>
#import <LindChain/ProcEnvironment/Surface/proc/rw.h>

DEFINE_SYSCALL_HANDLER(gethostname)
{
    /* lock the lock */
    host_read_lock();
    
    /* getting the length of the buffer which is nullterminated (ill cry if someone finds a vulnerability later here) */
    size_t len = strlen(ksurface->host_info.hostname);
    
    /* check if the length is within bounds */
    if((len + 1) > MAXHOSTNAMELEN)
    {
        goto out_fault;
    }
    
    /* allocate buffer */
    kern_return_t kr = mach_syscall_payload_create(ksurface->host_info.hostname, len + 1, (vm_address_t*)out_payload);
    *out_len = (uint32_t)len;
    
    /* checking payload return code */
    if(kr != KERN_SUCCESS)
    {
        goto out_fault;
    }
    
    /* unlock the lock */
    host_unlock();
    sys_return;
    
out_fault:
    host_unlock();
    sys_return_failure(EFAULT);
}
