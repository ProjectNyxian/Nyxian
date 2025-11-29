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

static inline ksurface_mapping_t *ksurface_alloc(void)
{
    ksurface_mapping_t *ksurface = malloc(sizeof(ksurface_mapping_t));
    ksurface->magic = SURFACE_MAGIC;
    ksurface->proc_info.proc_count = 0;
    return ksurface;
}

static inline void ksurface_hostname_init(void)
{
    NSString *hostname = [[NSUserDefaults standardUserDefaults] stringForKey:@"LDEHostname"];
    if(hostname == nil) hostname = @"localhost";
    strlcpy(surface->host_info.hostname, hostname.UTF8String, MAXHOSTNAMELEN);
}

void ksurface_init(void)
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        if(environment_must_be_role(EnvironmentRoleHost))
        {
            // Allocate internal surface
            surface = ksurface_alloc();
            
            // Initilize hostname
            ksurface_hostname_init();
        }
    });
}
