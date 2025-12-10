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

DEFINE_SYSCALL_HANDLER(gethostname)
{
    /* lock the lock */
    pthread_rwlock_rdlock(&(ksurface->host_info.rwlock));
    
    /* getting the length of the buffer which is nullterminated (ill cry if someone finds a vulnerability later here) */
    size_t len = strlen(ksurface->host_info.hostname);
    
    /* check if the length is within bounds */
    if((len + 1) > MAXHOSTNAMELEN)
    {
        goto out_fault;
    }
    
    /* allocate buffer */
    vm_io_client_map_t *client_map = kvmio_alloc(len + 1);
    
    memcpy((void*)client_map->map_address, ksurface->host_info.hostname, len);
    ((char*)client_map->map_address)[len] = '\0';
    
    kvmio_copy_out(client, client_map, (vm_address_t)args[0]);
    
    kvmio_dealloc(client_map);
    
    /* unlock the lock */
    pthread_rwlock_unlock(&(ksurface->host_info.rwlock));
    return 0;
    
out_fault:
    pthread_rwlock_unlock(&(ksurface->host_info.rwlock));
    *err = EFAULT;
    return -1;
}
