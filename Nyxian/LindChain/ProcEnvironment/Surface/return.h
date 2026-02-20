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

#ifndef PROCENVIRONMENT_RETURN_H
#define PROCENVIRONMENT_RETURN_H

typedef uint8_t ksurface_return_t;

#define SURFACE_SUCCESS         0

#define SURFACE_NULLPTR         1
#define SURFACE_DENIED          2
#define SURFACE_FAILED          4
#define SURFACE_UNAVAILABLE     5
#define SURFACE_INUSE           6
#define SURFACE_NOMEM           7
#define SURFACE_RETAIN_FAILED   8
#define SURFACE_DUPLICATE       9
#define SURFACE_LIMIT           10
#define SURFACE_LOOKUP_FAILED   11

#endif /* PROCENVIRONMENT_RETURN_H */
