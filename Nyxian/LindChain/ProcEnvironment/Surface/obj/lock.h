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

#ifndef SURFACE_KVOBJECT_LOCK_H
#define SURFACE_KVOBJECT_LOCK_H

#import <LindChain/ProcEnvironment/Surface/obj/defs.h>

#define kvo_rdlock(obj) kvobject_rdlock((kvobject_t *)(obj))
#define kvo_wrlock(obj) kvobject_wrlock((kvobject_t *)(obj))
#define kvo_unlock(obj) kvobject_unlock((kvobject_t *)(obj))

void kvobject_rdlock(kvobject_t *kvo);
void kvobject_wrlock(kvobject_t *kvo);
void kvobject_unlock(kvobject_t *kvo);

#endif /* SURFACE_KVOBJECT_LOCK_H */
