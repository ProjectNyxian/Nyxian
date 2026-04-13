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

#ifndef PROCENVIRONMENT_RETURN_H
#define PROCENVIRONMENT_RETURN_H

#include <stdint.h>

typedef uint8_t ksurface_return_t;

#define SURFACE_SUCCESS         0

#define SURFACE_NULLPTR         1
#define SURFACE_DENIED          2
#define SURFACE_UNAVAILABLE     3
#define SURFACE_INUSE           4
#define SURFACE_NOMEM           5
#define SURFACE_DUPLICATE       6
#define SURFACE_LIMIT           7
#define SURFACE_INVALID         8

#define SURFACE_FAILURE         20
#define SURFACE_RETAIN_FAILURE  21
#define SURFACE_LOOKUP_FAILURE  22
#define SURFACE_ACQUIRE_FAILURE 23

#endif /* PROCENVIRONMENT_RETURN_H */
