/*
 SPDX-License-Identifier: AGPL-3.0-or-later

 Copyright (C) 2025 - 2026 cr4zyengineer

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

#ifndef SURFACE_SYSCTL_H
#define SURFACE_SYSCTL_H

#include <LindChain/ProcEnvironment/Surface/surface.h>
#include <stdbool.h>

bool is_valid_hostname_regex(const char *hostname);

DEFINE_SYSCALL_HANDLER(sysctl);
DEFINE_SYSCALL_HANDLER(sysctlbyname);

#endif /* SURFACE_SYSCTL_H */
