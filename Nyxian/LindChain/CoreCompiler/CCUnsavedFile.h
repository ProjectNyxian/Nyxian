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

#ifndef CCUNSAVEDFILE_H
#define CCUNSAVEDFILE_H

#include <LindChain/CoreCompiler/CCBase.h>

typedef struct opaque_ccunsavedfile *CCUnsavedFileRef;

CC_EXPORT CFTypeID CCUnsavedFileGetTypeID(void);

CC_EXPORT CCUnsavedFileRef CF_RETURNS_RETAINED CCUnsavedFileCreate(CFAllocatorRef allocator, CFURLRef fileURL, CFDataRef data);

CC_EXPORT CFURLRef CCUnsavedFileGetFileURL(CCUnsavedFileRef unsavedFile);
CC_EXPORT CFDataRef CCUnsavedFileGetData(CCUnsavedFileRef unsavedFile);

CC_EXPORT void CCUnsavedFileSetFileURL(CCUnsavedFileRef unsavedFile, CFURLRef fileURL);
CC_EXPORT void CCUnsavedFileSetData(CCUnsavedFileRef unsavedFile, CFDataRef data);

#endif /* CCUNSAVEDFILE_H */
