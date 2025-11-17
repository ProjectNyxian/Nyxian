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
#import <LindChain/ProcEnvironment/Surface/surface.h>
#import <LindChain/ProcEnvironment/Surface/proc.h>
#import <LindChain/ProcEnvironment/proxy.h>
#import <LindChain/litehook/src/litehook.h>
#import <mach/mach.h>
#import <sys/sysctl.h>
#import <mach-o/dyld.h>

ksurface_mapping_t *surface = NULL;
static MappingPortObject *surfaceMappingPortObject = NULL;

/* sysctl */
int proc_sysctl_listproc(void *buffer, size_t buffersize, size_t *needed_out)
{
    // Dont use if uninitilized
    if(surface == NULL) return 0;
    
    size_t needed_bytes = 0;
    int ret = 0;

    do {
        seqlock_read_begin(&(surface->seqlock));

        uint32_t count = surface->proc_count;
        needed_bytes = (size_t)count * sizeof(struct kinfo_proc);

        if(needed_out)
            *needed_out = needed_bytes;

        if(buffer == NULL || buffersize == 0)
        {
            ret = (int)needed_bytes;
            break;
        }

        if(buffersize < needed_bytes)
        {
            errno = ENOMEM;
            ret = -1;
            break;
        }

        struct kinfo_proc *kprocs = buffer;
        for(uint32_t i = 0; i < count; i++)
        {
            memset(&kprocs[i], 0, sizeof(struct kinfo_proc));
            memcpy(&kprocs[i],
                   &surface->proc_info[i].real,
                   sizeof(struct kinfo_proc));
        }

        ret = (int)needed_bytes;

    }
    while(seqlock_read_retry(&(surface->seqlock)));

    return ret;
}

/*
 Management
 */
/// Returns a process surface file handle to perform a handoff over XPC
MappingPortObject *proc_surface_for_pid(pid_t pid)
{
    environment_must_be_role(EnvironmentRoleHost);
    // TODO: Enforce entitlements
    uint32_t flags = VM_PROT_READ;
    return [surfaceMappingPortObject copyWithProt:flags];
}

/*
 Experimental hooks & implementations
 */
int environment_gethostname(char *buf,
                            size_t bufsize)
{
    do
    {
        seqlock_read_begin(&(surface->seqlock));
        strlcpy(buf, surface->hostname, bufsize);
    }
    while(seqlock_read_retry(&(surface->seqlock)));
    
    return 0;
}

void kern_sethostname(NSString *hostname)
{
    seqlock_lock(&(surface->seqlock));
    hostname = hostname ?: @"localhost";
    strlcpy(surface->hostname, [hostname UTF8String], MAXHOSTNAMELEN);
    seqlock_unlock(&(surface->seqlock));
}

void proc_surface_init(void)
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        if(environment_is_role(EnvironmentRoleHost))
        {
            // Allocate surface and spinface
            surfaceMappingPortObject = [[MappingPortObject alloc] initWithSize:sizeof(ksurface_mapping_t) withProt:VM_PROT_READ | VM_PROT_WRITE];
            surface = surfaceMappingPortObject.addr;
            
            // Setup surface
            surface->magic = SURFACE_MAGIC;
            NSString *hostname = [[NSUserDefaults standardUserDefaults] stringForKey:@"LDEHostname"];
            if(hostname == nil) hostname = @"localhost";
            strlcpy(surface->hostname, hostname.UTF8String, MAXHOSTNAMELEN);
            surface->proc_count = 0;
            proc_create_child_proc(getppid(), getpid(), 0, 0, [[NSBundle mainBundle] executablePath], PEEntitlementAll);
            
            
            // Setup spinface
            seqlock_init(&(surface->seqlock));
        }
        else
        {
            // Get surface object
            MappingPortObject *surfaceMapObject = environment_proxy_get_surface_mapping();
            
            if(surfaceMapObject != nil)
            {
                // Now map em
                void *surfacePtr = [surfaceMapObject map];
                
                if(surfacePtr != MAP_FAILED)
                {
                    surface = surfacePtr;
                }
            }
        }
    });
}
