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
#import <LindChain/ProcEnvironment/Surface/proc/copy.h>
#import <LindChain/ProcEnvironment/Surface/proc/rw.h>

/*
 * Helper
 */

bool proc_is_privileged(ksurface_proc_copy_t *proc)
{
    /* Checking if process is entitled to elevate. */
    if(entitlement_got_entitlement(proc_getentitlements(proc), PEEntitlementProcessElevate))
    {
        return true;
    }
    
    /* It's not, so we check if the process is root. */
    return proc_getuid(proc) == 0;
}

/*
 * User identifier shit :3
 */

int proc_setuid_user(ksurface_proc_copy_t *proc,
                     uid_t uid)
{
    if(proc_is_privileged(proc))
    {
        proc_setuid(proc, uid);
        proc_setruid(proc, uid);
        proc_setsvuid(proc, uid);
        return 0;
    }
    else
    {
        if(uid == proc_getruid(proc) ||
           uid == proc_getsvuid(proc))
        {
            proc_setuid(proc, uid);
            return 0;
        }
    }
    return -1;
}

int proc_seteuid_user(ksurface_proc_copy_t *proc,
                      uid_t euid)
{
    if(proc_is_privileged(proc))
    {
        proc_setuid(proc, euid);
        return 0;
    }
    else
    {
        if(euid == proc_getruid(proc) ||
           euid == proc_getuid(proc) ||
           euid == proc_getsvuid(proc))
        {
            proc_setuid(proc, euid);
            return 0;
        }
    }
    return -1;
}

int proc_setruid_user(ksurface_proc_copy_t *proc,
                      uid_t ruid)
{
    if(proc_is_privileged(proc))
    {
        proc_setruid(proc, ruid);
        return 0;
    }
    else
    {
        if(ruid == proc_getruid(proc) ||
           ruid == proc_getuid(proc))
        {
            proc_setruid(proc, ruid);
            return 0;
        }
    }
    return -1;
}

int proc_setreuid_user(ksurface_proc_copy_t *proc,
                       uid_t ruid,
                       uid_t euid)
{
    uid_t cur_ruid = proc_getruid(proc);
    uid_t cur_euid = proc_getuid(proc);
    uid_t cur_svuid = proc_getsvuid(proc);
    bool privileged = proc_is_privileged(proc);
    
    if(ruid != (uid_t)-1 && !privileged)
    {
        if(ruid != cur_ruid && ruid != cur_euid)
        {
            return -1;
        }
    }
    
    if(euid != (uid_t)-1 && !privileged)
    {
        if(euid != cur_ruid && euid != cur_euid && euid != cur_svuid)
        {
            return -1;
        }
    }
    
    if(ruid != (uid_t)-1)
    {
        proc_setruid(proc, ruid);
    }
    if(euid != (uid_t)-1)
    {
        proc_setuid(proc, euid);
        if(ruid != (uid_t)-1)
        {
            proc_setsvuid(proc, euid);
        }
    }
    
    return 0;
}

int proc_setresuid_user(ksurface_proc_copy_t *proc,
                        uid_t ruid,
                        uid_t euid,
                        uid_t svuid)
{
    uid_t cur_ruid = proc_getruid(proc);
    uid_t cur_euid = proc_getuid(proc);
    uid_t cur_svuid = proc_getsvuid(proc);
    bool privileged = proc_is_privileged(proc);
    
    if(!privileged)
    {
        if(ruid != (uid_t)-1 &&
           ruid != cur_ruid && ruid != cur_euid && ruid != cur_svuid)
        {
            return -1;
        }
        if(euid != (uid_t)-1 &&
           euid != cur_ruid && euid != cur_euid && euid != cur_svuid)
        {
            return -1;
        }
        if(svuid != (uid_t)-1 &&
           svuid != cur_ruid && svuid != cur_euid && svuid != cur_svuid)
        {
            return -1;
        }
    }
    
    if(ruid != (uid_t)-1)  proc_setruid(proc, ruid);
    if(euid != (uid_t)-1)  proc_setuid(proc, euid);
    if(svuid != (uid_t)-1) proc_setsvuid(proc, svuid);
    
    return 0;
}

/*
 Group identifier shit :3
 */

int proc_setgid_user(ksurface_proc_copy_t *proc,
                     gid_t gid)
{
    if(proc_is_privileged(proc))
    {
       proc_setgid(proc, gid);
       proc_setrgid(proc, gid);
       proc_setsvgid(proc, gid);
       return 0;
    }
    else
    {
        if(gid == proc_getrgid(proc) ||
           gid == proc_getsvgid(proc))
        {
            proc_setgid(proc, gid);
            return 0;
        }
    }
    return -1;
}

int proc_setegid_user(ksurface_proc_copy_t *proc,
                      gid_t egid)
{
    if(proc_is_privileged(proc))
    {
        proc_setgid(proc, egid);
        return 0;
    }
    else
    {
        if(egid == proc_getrgid(proc) ||
           egid == proc_getgid(proc) ||
           egid == proc_getsvgid(proc))
        {
            proc_setgid(proc, egid);
            return 0;
        }
    }
    return -1;
}

int proc_setrgid_user(ksurface_proc_copy_t *proc,
                      gid_t rgid)
{
    if(proc_is_privileged(proc))
    {
        proc_setrgid(proc, rgid);
        return 0;
    }
    else
    {
        if(rgid == proc_getrgid(proc) ||
           rgid == proc_getgid(proc))
        {
            proc_setrgid(proc, rgid);
            return 0;
        }
    }
    return -1;
}

int proc_setregid_user(ksurface_proc_copy_t *proc,
                       gid_t rgid,
                       gid_t egid)
{
    gid_t cur_rgid = proc_getrgid(proc);
    gid_t cur_egid = proc_getgid(proc);
    gid_t cur_svgid = proc_getsvgid(proc);
    bool privileged = proc_is_privileged(proc);
    
    if(rgid != (gid_t)-1 && !privileged)
    {
        if(rgid != cur_rgid && rgid != cur_egid)
        {
            return -1;
        }
    }
    
    if(egid != (gid_t)-1 && !privileged)
    {
        if(egid != cur_rgid && egid != cur_egid && egid != cur_svgid)
        {
            return -1;
        }
    }
    
    if(rgid != (gid_t)-1)
    {
        proc_setrgid(proc, rgid);
    }
    if(egid != (gid_t)-1)
    {
        proc_setgid(proc, egid);
        if(rgid != (gid_t)-1)
        {
            proc_setsvgid(proc, egid);
        }
    }
    
    return 0;
}

int proc_setresgid_user(ksurface_proc_copy_t *proc,
                        gid_t rgid,
                        gid_t egid,
                        gid_t svgid)
{
    gid_t cur_rgid = proc_getrgid(proc);
    gid_t cur_egid = proc_getgid(proc);
    gid_t cur_svgid = proc_getsvgid(proc);
    bool privileged = proc_is_privileged(proc);
    
    if(!privileged)
    {
        if(rgid != (gid_t)-1 &&
           rgid != cur_rgid && rgid != cur_egid && rgid != cur_svgid)
        {
            return -1;
        }
        if(egid != (gid_t)-1 &&
           egid != cur_rgid && egid != cur_egid && egid != cur_svgid)
        {
            return -1;
        }
        if(svgid != (gid_t)-1 &&
           svgid != cur_rgid && svgid != cur_egid && svgid != cur_svgid)
        {
            return -1;
        }
    }
    
    if(rgid != (gid_t)-1)  proc_setrgid(proc, rgid);
    if(egid != (gid_t)-1)  proc_setgid(proc, egid);
    if(svgid != (gid_t)-1) proc_setsvgid(proc, svgid);
    
    return 0;
}

/*
 Userapi syscalls
 */

unsigned long proc_cred_get(ksurface_proc_t *proc,
                            ProcessInfo Info)
{
    /* checking if proc is NULL to ensure that input is valid */
    if(proc == NULL)
    {
        return -1;
    }
    
    /* retaining process so it cannot get freed until this symbol ran entirely through */
    proc_retain(proc);
    
    /* locking the processes mutex so no one can copy or modify it until done */
    proc_read_lock(proc);
    
    unsigned long retval = -1;
    
    switch(Info)
    {
        case ProcessInfoEUID:
        case ProcessInfoUID:
            retval = proc_getuid(proc);
            break;
        case ProcessInfoRUID:
            retval = proc_getruid(proc);
            break;
        case ProcessInfoEGID:
        case ProcessInfoGID:
            retval = proc_getgid(proc);
            break;
        case ProcessInfoRGID:
            retval = proc_getrgid(proc);
            break;
        case ProcessInfoEntitlements:
            retval = proc_getentitlements(proc);
            break;
        case ProcessInfoPID:
            retval = proc_getpid(proc);
            break;
        case ProcessInfoPPID:
            retval = proc_getppid(proc);
            break;
        default:
            break;
    }
    
    /* unlocking the processes mutex so now other actions can be performed on it */
    proc_unlock(proc);
    
    /* releasing process so, we dont mess up reference counting */
    proc_release(proc);
    
    return retval;
}

unsigned long proc_cred_set(ksurface_proc_t *proc,
                            ProcessCredOp Op,
                            id_t ida,
                            id_t idb,
                            id_t idc)
{
    /* checking if proc is NULL to ensure that input is valid */
    if(proc == NULL)
    {
        return -1;
    }
    
    /* creating a copy that references the process */
    ksurface_proc_copy_t *proc_copy = proc_copy_for_proc(proc);
    if(proc_copy == NULL)
    {
        return -1;
    }
    
    unsigned long retval = -1;

    switch(Op)
    {
        case ProcessCredOpSetUID:
            retval = proc_setuid_user(proc_copy, ida);
            break;
        case ProcessCredOpSetEUID:
            retval = proc_seteuid_user(proc_copy, ida);
            break;
        case ProcessCredOpSetRUID:
            retval = proc_setruid_user(proc_copy, ida);
            break;
        case ProcessCredOpSetREUID:
            retval = proc_setreuid_user(proc_copy, ida, idb);
            break;
        case ProcessCredOpSetRESUID:
            retval = proc_setresuid_user(proc_copy, ida, idb, idc);
            break;
        case ProcessCredOpSetGID:
            retval = proc_setgid_user(proc_copy, ida);
            break;
        case ProcessCredOpSetEGID:
            retval = proc_setegid_user(proc_copy, ida);
            break;
        case ProcessCredOpSetRGID:
            retval = proc_setrgid_user(proc_copy, ida);
            break;
        case ProcessCredOpSetREGID:
            retval = proc_setregid_user(proc_copy, ida, idb);
            break;
        case ProcessCredOpSetRESGID:
            retval = proc_setresgid_user(proc_copy, ida, idb, idc);
            break;
        default:
            break;
    }
    
    /* only update on succession */
    if(retval == 0)
    {
        /* update the original process with the copy */
        proc_copy_update(proc_copy);
    }
    
    /* destroying the copy and with that the reference to the process */
    proc_copy_destroy(proc_copy);
    
    return retval;
}
