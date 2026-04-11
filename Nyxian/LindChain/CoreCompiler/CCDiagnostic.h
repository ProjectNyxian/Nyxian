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

#ifndef CCDIAGNOSTIC_H
#define CCDIAGNOSTIC_H

#include <LindChain/CoreCompiler/CCBase.h>
#include <LindChain/CoreCompiler/CCSourceLocation.h>

typedef struct opaque_ccdiag *CCDiagnosticRef;

CC_EXPORT CFTypeID CCDiagnosticGetTypeID(void);

CC_EXPORT CCDiagnosticRef CF_RETURNS_RETAINED CCDiagnosticCreate(CFAllocatorRef allocator, CCDiagType type, CCDiagLevel level, CFURLRef fileURL, CCSourceLocation location, CFStringRef message);

CC_EXPORT CCDiagType CCDiagnosticGetType(CCDiagnosticRef diagnostic);
CC_EXPORT CCDiagLevel CCDiagnosticGetLevel(CCDiagnosticRef diagnostic);
CC_EXPORT CFURLRef CF_RETURNS_RETAINED CCDiagnosticGetFileURL(CCDiagnosticRef diagnostic);
CC_EXPORT CCSourceLocation CCDiagnosticGetLocation(CCDiagnosticRef diagnostic);
CC_EXPORT CFStringRef CF_RETURNS_RETAINED CCDiagnosticGetMessage(CCDiagnosticRef diagnostic);

#endif /* CCDIAGNOSTIC_H */
