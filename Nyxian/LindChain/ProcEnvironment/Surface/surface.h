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

#ifndef PROCENVIRONMENT_SURFACE_H
#define PROCENVIRONMENT_SURFACE_H

#import <Foundation/Foundation.h>

#import <LindChain/ProcEnvironment/Surface/limits.h>
#import <LindChain/ProcEnvironment/Surface/return.h>
#import <LindChain/ProcEnvironment/Surface/mapping.h>

/* Internal kernel information */
extern ksurface_mapping_t *ksurface;

void kern_sethostname(NSString *hostname);

void ksurface_kinit(void);

#endif /* PROCENVIRONMENT_SURFACE_H */
