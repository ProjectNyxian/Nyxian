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

#ifndef LINDCHAIN_KERN_KERN_H
#define LINDCHAIN_KERN_KERN_H

#import <LindChain/ProcEnvironment/Sysctl/sysctl.h>

int sysctl_kernmaxproc(sysctl_req_t *req);
int sysctl_kernprocall(sysctl_req_t *req);
int sysctl_kernprocargs2(sysctl_req_t *req);

#endif /* LINDCHAIN_KERN_KERN_H */
