/*
 SPDX-License-Identifier: AGPL-3.0-or-later

 Copyright (C) 2025 - 2026 mach-port-t

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

#ifndef PROCENVIRONMENT_SURFACE_H
#define PROCENVIRONMENT_SURFACE_H

#ifdef __OBJC__
#import <Foundation/Foundation.h>
#endif /* __OBJC__ */

#import <LindChain/ProcEnvironment/Surface/limits.h>
#import <LindChain/ProcEnvironment/Surface/return.h>
#import <LindChain/ProcEnvironment/Surface/mapping.h>
#include <assert.h>
#include <errno.h>

extern ksurface_mapping_t *ksurface;

#ifdef __OBJC__
int ksurface_sethostname(NSString *hostname);
#endif /* __OBJC__ */

void ksurface_kinit(void);

#endif /* PROCENVIRONMENT_SURFACE_H */
