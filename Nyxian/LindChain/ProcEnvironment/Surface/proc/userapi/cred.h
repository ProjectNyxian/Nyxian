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

typedef NS_OPTIONS(uint64_t, ProcessCredOp) {
    ProcessCredOpSetUID         = 0,
    ProcessCredOpSetEUID        = 1,
    ProcessCredOpSetRUID        = 2,
    ProcessCredOpSetREUID       = 3,
    ProcessCredOpSetRESUID      = 4,
    ProcessCredOpSetGID         = 5,
    ProcessCredOpSetEGID        = 6,
    ProcessCredOpSetRGID        = 7,
    ProcessCredOpSetREGID       = 8,
    ProcessCredOpSetRESGID      = 9,
};

unsigned long proc_cred_get(ksurface_proc_t *proc, ProcessInfo Info);
unsigned long proc_cred_set(ksurface_proc_t *proc, ProcessCredOp Op, id_t ida, id_t idb, id_t idc);

#endif /* PROC_USERAPI_CRED_H */
