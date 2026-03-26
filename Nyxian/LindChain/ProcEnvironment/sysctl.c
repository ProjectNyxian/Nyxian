/*
 SPDX-License-Identifier: AGPL-3.0-or-later

 Copyright (C) 2025 - 2026 cr4zyengineer

 This file is part of Nyxian.

 Nyxian is free software: you can redistribute it and/or modify
 it under the terms of the GNU Affero General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.

 Nyxian is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 GNU Affero General Public License for more details.

 You should have received a copy of the GNU Affero General Public License
 along with Nyxian. If not, see <https://www.gnu.org/licenses/>.
*/

#include <LindChain/ProcEnvironment/sysctl.h>
#include <LindChain/ProcEnvironment/syscall.h>
#include <LindChain/litehook/litehook.h>
#include <LindChain/ProcEnvironment/Surface/surface.h>
#include <sys/sysctl.h>
#include <errno.h>

DEFINE_HOOK(sysctl, int, (int *name,
                          u_int namelen,
                          void *__sized_by(*oldlenp) oldp,
                          size_t *oldlenp,
                          void *__sized_by(newlen) newp,
                          size_t newlen))
{
    int ret = (int)environment_syscall(SYS_sysctl, name, namelen, oldp, oldlenp, newp, newlen);
    return (ret == -1 && errno == ENOSYS) ? ORIG_FUNC(sysctl)(name, namelen, oldp, oldlenp, newp, newlen) : ret;
}

DEFINE_HOOK(sysctlbyname, int, (const char *name,
                                void *__sized_by(*oldlenp) oldp,
                                size_t *oldlenp,
                                void *__sized_by(newlen) newp,
                                size_t newlen))
{
    int ret = (int)environment_syscall(SYS_sysctlbyname, name, oldp, oldlenp, newp, newlen);
    return (ret == -1 && errno == ENOSYS) ? ORIG_FUNC(sysctlbyname)(name, oldp, oldlenp, newp, newlen) : ret;
}

DEFINE_HOOK(gethostname, int, (char *name,
                               size_t len))
{
    int mib[2] = { CTL_KERN, KERN_HOSTNAME };
    int retval = (int)environment_syscall(SYS_sysctl, mib, 2, name, &len, NULL, NULL);
    name[len] = '\0';
    return retval;
}

DEFINE_HOOK(sethostname, int, (char *name,
                               size_t len))
{
    int mib[2] = { CTL_KERN, KERN_HOSTNAME };
    return (int)environment_syscall(SYS_sysctl, mib, 2, NULL, NULL, name, len);
}

void environment_sysctl_init(void)
{
    DO_HOOK_GLOBAL(sysctl);
    DO_HOOK_GLOBAL(sysctlbyname);
    DO_HOOK_GLOBAL(gethostname);
    DO_HOOK_GLOBAL(sethostname);
}
