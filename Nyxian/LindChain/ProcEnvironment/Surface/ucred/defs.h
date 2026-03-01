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

#ifndef UCRED_DEFS_H
#define UCRED_DEFS_H

#import <LindChain/ProcEnvironment/Surface/obj/kvobject.h>
#import <LindChain/ProcEnvironment/Surface/entitlement.h>
#include <sys/types.h>

typedef struct ksurface_ucred ksurface_ucred_t;

struct ksurface_ucred {
    /* object header */
    kvobject_t header;
    
    /* user identifier */
    uid_t ruid;
    uid_t euid;
    uid_t svuid;
    
    /* groups/group identifier */
    gid_t groups[NGROUPS_MAX];
    uint8_t ngroups;    /* number of groups */
    gid_t *rgid;        /* pointer which points to the first item of groups */
    gid_t egid;
    gid_t svgid;
    
    /* entitlements */
    PEEntitlement entitlement;
};

#endif /* UCRED_DEFS_H */
