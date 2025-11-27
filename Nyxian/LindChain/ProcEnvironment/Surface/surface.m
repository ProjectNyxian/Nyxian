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
#import <LindChain/ProcEnvironment/Surface/proc/proc.h>
#import <LindChain/ProcEnvironment/proxy.h>
#import <LindChain/litehook/src/litehook.h>
#import <mach/mach.h>
#import <sys/sysctl.h>
#import <mach-o/dyld.h>
#import <LindChain/ProcEnvironment/Utils/klog.h>

ksurface_mapping_t *surface = NULL;
static MappingPortObject *surfaceMappingPortObject = NULL;

MappingPortObject *proc_surface_for_pid(pid_t pid)
{
    environment_must_be_role(EnvironmentRoleHost);
    // TODO: Enforce entitlements
    uint32_t flags = VM_PROT_NONE;
    
    // Check entitlements and go
    ksurface_proc_t proc = {};
    ksurface_error_t error = proc_for_pid(pid, &proc);
    if(error == kSurfaceErrorSuccess)
    {
        // If gathering the process was successful, only then we gonna add permitives to the mapping port we going to distribute to the process
        PEEntitlement proc_ent = proc_getentitlements(proc);
        if(entitlement_got_entitlement(proc_ent, PEEntitlementSurfaceRead)) flags = flags | VM_PROT_READ;
        
        // MARK: PEEntitlementSurfaceWrite Banned because of reflock implementation, no child process shall be able to alter the ksurface memory at all
        //if(entitlement_got_entitlement(proc_ent, PEEntitlementSurfaceWrite)) flags = flags | VM_PROT_WRITE;
    }
    
    return [surfaceMappingPortObject copyWithProt:flags];
}

/*
 Experimental hooks & implementations
 */
DEFINE_HOOK(gethostname, int, (char *buf, size_t bufsize))
{
    unsigned long seq;
    
    do
    {
        seq = reflock_read_begin(&(surface->reflock));
        strlcpy(buf, surface->host_info.hostname, bufsize);
    }
    while(reflock_read_retry(&(surface->reflock), seq));
    
    return 0;
}

void kern_sethostname(NSString *hostname)
{
    klog_log(@"surface", @"setting hostname to %@", hostname);
    reflock_lock(&(surface->reflock));
    hostname = hostname ?: @"localhost";
    strlcpy(surface->host_info.hostname, [hostname UTF8String], MAXHOSTNAMELEN);
    reflock_unlock(&(surface->reflock));
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
            strlcpy(surface->host_info.hostname, hostname.UTF8String, MAXHOSTNAMELEN);
            surface->proc_info.proc_count = 0;
            
            // Initilize kernel process
            proc_init_kproc();
            
            // Setup spinface
            reflock_init(&(surface->reflock));
        }
        else
        {
            // Get surface object
            MappingPortObject *surfaceMapObject = environment_proxy_get_surface_mapping();
            
            if(surfaceMapObject != nil)
            {
                // Now map em
                if(surfaceMapObject.prot == VM_PROT_NONE) return;
                void *surfacePtr = [surfaceMapObject map];
                
                if(surfacePtr != MAP_FAILED ||
                   ((ksurface_mapping_t*)surfacePtr)->magic != SURFACE_MAGIC)
                {
                    surface = surfacePtr;
                    DO_HOOK_GLOBAL(gethostname);
                }
            }
        }
    });
}
