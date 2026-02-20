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

#ifndef KVOBJECT_ALLOC_H
#define KVOBJECT_ALLOC_H

#import <LindChain/ProcEnvironment/Surface/obj/defs.h>

#define kvo_alloc(size, init, deinit) (void*)kvobject_alloc(size, init, deinit)
#define kvo_alloc_fastpath(size, name) kvo_alloc(size, GET_KVOBJECT_INIT_HANDLER(name), GET_KVOBJECT_DEINIT_HANDLER(name))
#define kvo_copy(kvo) (void*)kvobject_copy((kvobject_t*)kvo)

kvobject_strong_t *kvobject_alloc(size_t size, kvobject_init_handler_t init, kvobject_deinit_handler_t deinit);
kvobject_strong_t *kvobject_copy(kvobject_t *kvo);

#endif /* KVOBJECT_ALLOC_H */
