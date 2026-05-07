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

#ifndef SURFACE_SYS_PECTL_H
#define SURFACE_SYS_PECTL_H

#include <LindChain/ProcEnvironment/Surface/surface.h>

/* launch services */
#define PECTL_LS_SET_ENDPOINT   0b00000000  /* sets the endpoint of a launch service identifier (i.e. com.mycompany.daemon) */
#define PECTL_LS_GET_ENDPOINT   0b00000001  /* gets the endpoint of a launch service identifier (i.e. com.cr4zy.containerd) */

/* environment */
#define PECTL_PE_SET_BAMSET     0b00000010  /* sets background audio mode (i.e Spotify playing music in background)         */

/* code signing */
#define PECTL_CS_GET_PUBKEY     0b00000011  /* getting the code signature public key                                        */
#define PECTL_CS_GET_PRVKEY     0b00000100  /* noop                                                                         */
#define PECTL_CS_SIGN_PATH      0b00000101  /* signs executable at a specific path                                          */

DEFINE_SYSCALL_HANDLER(pectl);

#endif /* SURFACE_SYS_PECTL_H */
