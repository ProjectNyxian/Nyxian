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

#ifndef PROC_COPY_H
#define PROC_COPY_H

#import <LindChain/ProcEnvironment/Surface/surface.h>

enum kProcCopyOption {
    kProcCopyOptionRetainedCopy = 0,
    kProcCopyOptionConsumedReferenceCopy = 1,
    kProcCopyOptionStaticCopy = 2
};

typedef enum kProcCopyOption kproc_copy_option_t;

ksurface_proc_copy_t *proc_copy_for_proc(ksurface_proc_t *proc, kproc_copy_option_t option);
ksurface_return_t proc_copy_update(ksurface_proc_copy_t *proc_copy);
ksurface_return_t proc_copy_recopy(ksurface_proc_copy_t *proc_copy);
ksurface_return_t proc_copy_destroy(ksurface_proc_copy_t *proc_copy);

#endif /* PROC_COPY_H */
