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

#ifndef CCMUTABLEUNIT_T
#define CCMUTABLEUNIT_T

#include <LindChain/CoreCompiler/CCBase.h>
#include <LindChain/CoreCompiler/CCDiagnostic.h>

typedef struct opaque_ccmutableunit *CCMutableUnitRef;

CC_EXPORT CFTypeID CCMutableUnitGetTypeID(void);

CC_EXPORT CCMutableUnitRef CF_RETURNS_RETAINED CCMutableUnitCreate(CFAllocatorRef allocator);

CC_EXPORT bool CCMutableUnitReparse(CCMutableUnitRef mutableUnit);

CC_EXPORT void CCMutableUnitSetArguments(CCMutableUnitRef mutableUnit, CFArrayRef arguments);
CC_EXPORT void CCMutableUnitSetFileContent(CCMutableUnitRef mutableUnit, CFURLRef fileURL, CFDataRef content);

CC_EXPORT CFIndex CCMutableUnitGetDiagnosticCount(CCMutableUnitRef mutableUnit);
CC_EXPORT CCDiagnosticRef CF_RETURNS_RETAINED CCDiagnosticCreateFromMutableUnit(CCMutableUnitRef mutableUnit, uint64_t index);

#endif /* CCMUTABLEUNIT_T */
