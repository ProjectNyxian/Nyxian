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

#ifndef SURFACE_KVOBJECT_COPY_H
#define SURFACE_KVOBJECT_COPY_H

#import <LindChain/ProcEnvironment/Surface/obj/defs.h>
#import <LindChain/ProcEnvironment/Surface/return.h>

kvobject_t *kvobject_copy(kvobject_t *kvo, kvobj_copy_option_t option);

ksurface_return_t kvobject_copy_update(kvobject_t *kvo_copy);
ksurface_return_t kvobject_copy_recopy(kvobject_t *kvo_copy);
ksurface_return_t kvobject_copy_destroy(kvobject_t *kvo_copy);

#endif /* SURFACE_KVOBJECT_COPY_H */
