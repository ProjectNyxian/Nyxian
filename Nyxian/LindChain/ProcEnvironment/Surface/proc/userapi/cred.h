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

#ifndef PROC_USERAPI_CRED_H
#define PROC_USERAPI_CRED_H

#import <LindChain/ProcEnvironment/Surface/proc/proc.h>

typedef NS_OPTIONS(uint64_t, ProcessInfo) {
    ProcessInfoUID              = 0,
    ProcessInfoEUID             = 1,
    ProcessInfoRUID             = 2,
    ProcessInfoGID              = 3,
    ProcessInfoEGID             = 4,
    ProcessInfoRGID             = 5,
    ProcessInfoPID              = 6,
    ProcessInfoPPID             = 7,
    ProcessInfoEntitlements     = 8,
    ProcessInfoMAX              = 9,
};

unsigned long proc_cred_get(ksurface_proc_t *proc, ProcessInfo Info);
unsigned long proc_cred_set(ksurface_proc_t *proc, ProcessInfo Info, uid_t uid);

#endif /* PROC_USERAPI_CRED_H */
