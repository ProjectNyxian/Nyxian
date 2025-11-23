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

#ifndef PROCENVIRONMENT_SYSCTL_H
#define PROCENVIRONMENT_SYSCTL_H

#include <sys/sysctl.h>

typedef struct {
    int *name;
    u_int namelen;
    void *__sized_by(*oldlenp) oldp;
    size_t *oldlenp;
    void *__sized_by(newlen) newp;
    size_t newlen;
} sysctl_req_t;

typedef int (*sysctl_fn_t)(sysctl_req_t *req);

typedef struct {
    const int *mib;
    size_t mib_len;
    sysctl_fn_t fn;
} sysctl_map_entry_t;

void environment_sysctl_init(void);

#endif /* PROCENVIRONMENT_SYSCTL_H */
