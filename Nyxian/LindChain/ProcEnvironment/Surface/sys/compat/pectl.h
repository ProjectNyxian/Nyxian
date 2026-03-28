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

#ifndef SURFACE_SYS_PECTL_H
#define SURFACE_SYS_PECTL_H

#import <LindChain/ProcEnvironment/Surface/surface.h>

/* launch services */
#define PECTL_SET_ENDPOINT  0b00000000
#define PECTL_GET_ENDPOINT  0b00000001

/* environment */
#define PECTL_SET_BAMSET    0b00000010
/*
 * more compat will move into process
 * environment ctl likely soon, like
 * SYS_enttoken and SYS_handoffep
 */

DEFINE_SYSCALL_HANDLER(pectl);

#endif /* SURFACE_SYS_PECTL_H */
