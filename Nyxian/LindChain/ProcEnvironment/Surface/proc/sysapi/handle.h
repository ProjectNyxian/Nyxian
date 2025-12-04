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

#ifndef PROC_SYSAPI_HANDLE_H
#define PROC_SYSAPI_HANDLE_H

#import <Foundation/Foundation.h>
#import <LindChain/ProcEnvironment/Surface/surface.h>
#import <LindChain/Multitask/WindowServer/LDEWindowServer.h>
#import <LindChain/ProcEnvironment/Object/FDMapObject.h>
#import <sys/types.h>
#import <stdbool.h>
#import <CoreGraphics/CoreGraphics.h>

typedef struct proc_handle_t proc_handle_t;

/* symbol to get kernel process handle */
proc_handle_t *proc_handle_alloc_khandle(void);

/* symbols to manage process handles */
proc_handle_t *proc_handle_spawn(NSString *executable_path, proc_handle_t *parent_handle, NSArray<NSString*> *arguments, NSDictionary *environ, FDMapObject *mapObject);
void proc_handle_free(proc_handle_t *h);

#endif /* PROC_SYSAPI_HANDLE_H */
