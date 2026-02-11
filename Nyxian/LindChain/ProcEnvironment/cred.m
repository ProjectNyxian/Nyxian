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
#import <LindChain/litehook/litehook.h>
#import <LindChain/ProcEnvironment/cred.h>
#import <LindChain/ProcEnvironment/syscall.h>

DEFINE_HOOK(getuid, uid_t, (void))
{
    return (uid_t)environment_syscall(SYS_GETUID);
}

DEFINE_HOOK(getgid, gid_t, (void))
{
    return (uid_t)environment_syscall(SYS_GETGID);
}

DEFINE_HOOK(geteuid, uid_t, (void))
{
    return (uid_t)environment_syscall(SYS_GETEUID);
}

DEFINE_HOOK(getegid, gid_t, (void))
{
    return (uid_t)environment_syscall(SYS_GETEGID);
}

DEFINE_HOOK(getpid, pid_t, (void))
{
    return (uid_t)environment_syscall(SYS_GETPID);
}

DEFINE_HOOK(getppid, pid_t, (void))
{
    return (uid_t)environment_syscall(SYS_GETPPID);
}

DEFINE_HOOK(setuid, int, (uid_t uid))
{
    return (int)environment_syscall(SYS_SETUID, uid);
}

DEFINE_HOOK(seteuid, int, (uid_t euid))
{
    return (int)environment_syscall(SYS_SETEUID, euid);
}

DEFINE_HOOK(setruid, int, (uid_t uid))
{
    return (int)environment_syscall(SYS_SETREUID, uid, -1);
}

DEFINE_HOOK(setreuid, int, (uid_t ruid, uid_t euid))
{
    return (int)environment_syscall(SYS_SETREUID, ruid, euid);
}

DEFINE_HOOK(setgid, int, (gid_t gid))
{
    return (int)environment_syscall(SYS_SETGID, gid);
}

DEFINE_HOOK(setegid, int, (gid_t gid))
{
    return (int)environment_syscall(SYS_SETEGID, gid);
}

DEFINE_HOOK(setrgid, int, (gid_t gid))
{
    return (int)environment_syscall(SYS_SETREGID, gid, -1);
}

DEFINE_HOOK(setregid, int, (gid_t egid, gid_t rgid))
{
    return (int)environment_syscall(SYS_SETREGID, egid, rgid);
}

DEFINE_HOOK(getsid, pid_t, (pid_t pid))
{
    return (pid_t)environment_syscall(SYS_GETSID, pid);
}

DEFINE_HOOK(setsid, int, (void))
{
    return (int)environment_syscall(SYS_SETSID);
}

void environment_cred_init(void)
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        if(environment_is_role(EnvironmentRoleGuest))
        {
            DO_HOOK_GLOBAL(getuid);
            DO_HOOK_GLOBAL(getgid);
            DO_HOOK_GLOBAL(geteuid);
            DO_HOOK_GLOBAL(getegid);
            DO_HOOK_GLOBAL(getppid);
            DO_HOOK_GLOBAL(setuid);
            DO_HOOK_GLOBAL(setgid);
            DO_HOOK_GLOBAL(setruid);
            DO_HOOK_GLOBAL(setreuid);
            DO_HOOK_GLOBAL(setrgid);
            DO_HOOK_GLOBAL(seteuid);
            DO_HOOK_GLOBAL(setegid);
            DO_HOOK_GLOBAL(setregid);
            DO_HOOK_GLOBAL(getpid);
            DO_HOOK_GLOBAL(getsid);
            DO_HOOK_GLOBAL(setsid);
        }
    });
}
