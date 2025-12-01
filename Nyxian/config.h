/*
 Copyright (C) 2025 cr4zyengineer
 Copyright (C) 2025 expo

 This file is part of Nyxian.

 FridaCodeManager is free software: you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.

 FridaCodeManager is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 GNU General Public License for more details.

 You should have received a copy of the GNU General Public License
 along with Nyxian. If not, see <https://www.gnu.org/licenses/>.
*/

#ifndef NXCONFIG_H
#define NXCONFIG_H

/* AppStore */
#define APP_STORE_FRIENDLY_ENABLED 0

/* KSurface */
#define KSURFACE_ENABLED 1
#define KSURFACE_KLOG_ENABLED 1
#define KSURFACE_PROC_DEBUGGING_ENABLED 0
#define KSURFACE_PROC_ENUMERATION_ENABLED 1
#define KSURFACE_PROC_KILL_ENABLED 1
#define KSURFACE_PROC_SPAWN_ENABLED 1
#define KSURFACE_PROC_SIGN_UNSIGNED 1

/* KSurface Security */
#define KSURFACE_SECURITY_ENTITLEMENT_ENFORCEMENT_ENABLED 1
#define KSURFACE_SECURITY_TRUSTD_ENABLED 1
#define KSURFACE_SECURITY_CRED_ENABLED 1

/* ProcEnvironment */
#define PE_TASK_FOR_PID_FIX_ENABLED 1
#define PE_POSIX_SPAWN_FIX_ENABLED 1
#define PE_FORK_FIX_ENABLED 1
#define PE_SYSCTL_FIX_ENABLED 1

/* Nyxian */
#define NXPROJECT_APP_ENABLED 1
#define NXPROJECT_UTILITY_ENABLED 1
#define NXPROJECT_REACT_NATIVE_ENABLED 0
#define NXPROJECT_LUA_ENABLED 0
#define NXPROJECT_PYTHON_ENABLED 0
#define NXPROJECT_WEBDEV_ENABLED 0

#endif /* NXCONFIG_H */
