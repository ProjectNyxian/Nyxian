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
#import <LindChain/ProcEnvironment/Surface/ucred/ucred.h>
#import <LindChain/Services/trustd/LDETrust.h>

DEFINE_KVOBJECT_MAIN_EVENT_HANDLER(ucred)
{
    /* handle size request */
    if(kvarr == NULL)
    {
        return (int64_t)sizeof(ksurface_ucred_t);
    }
    
    /* get our kobj */
    ksurface_ucred_t *ucred = (ksurface_ucred_t*)kvarr[0];
    
    switch(type)
    {
        case kvObjEventSnapshot:
        case kvObjEventCopy:
            /* copy and snapshot are not supported on ucred */
            return -1;
        case kvObjEventInit:
            /* setting lowest permitives standard */
            ucred->ruid = 501;
            ucred->euid = 501;
            ucred->svuid = 501;
            ucred->groups[0] = 501;
            ucred->ngroups = 1;
            ucred->rgid = &(ucred->groups[0]);
            ucred->egid = 501;
            ucred->svgid = 501;
            ucred->entitlement = PEEntitlementNone;
        default:
            return 0;
    }
}

ksurface_ucred_t *ucred_for_path(const char *path)
{
    assert(path != NULL);
    
    /* creating new ucred object */
    ksurface_ucred_t *ucred = kvo_alloc_fastpath(ucred);
    
    if(ucred == NULL)
    {
        return NULL;
    }
    
    NSString *nsPath = [NSString stringWithCString:path encoding:NSUTF8StringEncoding];
    
    if(nsPath == nil)
    {
        kvo_release(ucred);
        return NULL;
    }
    
    ucred->entitlement = [[LDETrust shared] entitlementsOfExecutableAtPath:[NSString stringWithCString:path encoding:NSUTF8StringEncoding]];
    
    return ucred;
}
