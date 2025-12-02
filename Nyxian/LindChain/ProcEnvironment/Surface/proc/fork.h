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

#ifndef PROC_FORK_H
#define PROC_FORK_H

#import <LindChain/ProcEnvironment/Surface/surface.h>

ksurface_proc_t *proc_fork(ksurface_proc_t *parent, pid_t child_pid, const char *path);

ksurface_error_t proc_exit(ksurface_proc_t *child);

#endif /* PROC_FORK_H */
