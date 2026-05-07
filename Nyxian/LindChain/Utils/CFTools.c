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

#include <LindChain/Utils/CFTools.h>
#include <assert.h>
#include <malloc/malloc.h>

void CFOverwrite(CFTypeRef dst,
                 CFTypeRef src)
{
    assert(src != NULL && dst != NULL);
    
    /* literally overwriting object, this is normal memory */
    CFTypeID srcID = CFGetTypeID(src);
    CFTypeID dstID = CFGetTypeID(dst);
    assert(srcID == dstID);
    
    /*
     * CFRuntimeBase = isa (8) + refcount/flags (8) = 16 bytes
     * skip it... preserve identity (pointer) and retain count
     */
    size_t src_size = malloc_size(src);
    size_t size = malloc_size(dst);
    assert(src_size <= size);
    
    /*
     * retain everything in src payload first
     * so objects survive when dst's old pointers get orphaned.
     */
    CFRetain(src);
    
    memcpy((uint8_t *)dst + cfheader_size(), (uint8_t *)src + cfheader_size(), size - cfheader_size());
}
