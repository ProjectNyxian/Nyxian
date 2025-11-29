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

#import <LindChain/ProcEnvironment/Surface/proc/userapi/cred.h>

static inline bool proc_cred_unified(uid_t *value,
                                     bool allowed_set,
                                     uid_t *set)
{
    if(set != NULL)
    {
        if(*value == *set)
        {
            return true;
        }
        else if(allowed_set)
        {
            *value = *set;
            return true;
        }
    }
    return false;
}

unsigned long proc_cred_get(ksurface_proc_t *proc,
                            ProcessInfo Info)
{
    if(proc == NULL)
    {
        return -1;
    }
    
    unsigned long cpy = -1;
    
    switch(Info)
    {
        case ProcessInfoEUID:
        case ProcessInfoUID:
            cpy = proc_getuid(proc);
            break;
        case ProcessInfoRUID:
            cpy = proc_getruid(proc);
            break;
        case ProcessInfoEGID:
        case ProcessInfoGID:
            cpy = proc_getgid(proc);
            break;
        case ProcessInfoRGID:
            cpy = proc_getrgid(proc);
            break;
        case ProcessInfoEntitlements:
            cpy = proc_getentitlements(proc);
            break;
        case ProcessInfoPID:
            cpy = proc_getpid(proc);
            break;
        case ProcessInfoPPID:
            cpy = proc_getppid(proc);
            break;
        default:
            break;
    }
    
    return cpy;
}

unsigned long proc_cred_set(ksurface_proc_t *proc,
                            ProcessInfo Info,
                            uid_t uid)
{
    if(proc == NULL)
    {
        return -1;
    }
    
    bool allowedToAlter = entitlement_got_entitlement(proc_getentitlements(proc), PEEntitlementProcessElevate);
    bool success = false;
    switch(Info)
    {
        case ProcessInfoEUID:
        case ProcessInfoUID:
            success = proc_cred_unified(&proc_getuid(proc), allowedToAlter, &uid);
            break;
        case ProcessInfoRUID:
            success = proc_cred_unified(&proc_getruid(proc), allowedToAlter, &uid);
            break;
        case ProcessInfoEGID:
        case ProcessInfoGID:
            success = proc_cred_unified(&proc_getgid(proc), allowedToAlter, &uid);
            break;
        case ProcessInfoRGID:
            success = proc_cred_unified(&proc_getrgid(proc), allowedToAlter, &uid);
            break;
        default:
            break;
    }
    
    return success ? 0 : -1;
}
