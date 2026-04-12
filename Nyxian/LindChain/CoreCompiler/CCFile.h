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

#ifndef CCFILE_H
#define CCFILE_H

#include <LindChain/CoreCompiler/CCBase.h>

typedef struct opaque_ccfile *CCFileRef;

CC_EXPORT CFTypeID CCFileGetTypeID(void);

CC_EXPORT CCFileRef CF_RETURNS_RETAINED CCFileCreate(CFAllocatorRef allocator, CFURLRef fileURL);

CC_EXPORT CFURLRef CCFileGetFileURL(CCFileRef file);

#endif /* CCFILE_H */
