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

#ifndef CCASTUNIT_T
#define CCASTUNIT_T

#include <LindChain/CoreCompiler/CCBase.h>
#include <LindChain/CoreCompiler/CCDiagnostic.h>
#ifdef __cplusplus
#include <clang/Frontend/ASTUnit.h>
#include <clang/Frontend/CompilerInstance.h>
#include <clang/Tooling/Tooling.h>
#include <clang/Basic/DiagnosticOptions.h>
#include <llvm/Support/raw_ostream.h>
#include <llvm/ADT/StringRef.h>
#include <clang/Basic/LLVM.h>
#endif /* __cplusplus */

typedef struct opaque_ccastunit *CCMutableASTUnitRef;
typedef struct opaque_ccastunit *CCASTUnitRef;

CC_EXPORT CFTypeID CCAstUnitGetTypeID(void);

CC_EXPORT CCMutableASTUnitRef CF_RETURNS_RETAINED CCASTUnitCreateMutable(CFAllocatorRef allocator);
#ifdef __cplusplus
CC_EXPORT CCASTUnitRef CF_RETURNS_RETAINED CCASTUnitCreateWithASTUnit(CFAllocatorRef allocator, std::unique_ptr<clang::ASTUnit> astUnit);
#endif /* __cplusplus */

CC_EXPORT Boolean CCASTUnitReparse(CCMutableASTUnitRef mutableUnit);

CC_EXPORT void CCASTUnitSetArguments(CCMutableASTUnitRef mutableUnit, CFArrayRef arguments);
CC_EXPORT void CCASTUnitSetFileContent(CCMutableASTUnitRef mutableUnit, CFURLRef fileURL, CFDataRef content);
CC_EXPORT CFURLRef CCASTUnitGetFileURL(CCASTUnitRef unit);
CC_EXPORT Boolean CCASTUnitErrorOccured(CCASTUnitRef unit);

CC_EXPORT CFArrayRef CF_RETURNS_RETAINED CCASTUnitCopyDiagnostics(CCASTUnitRef unit);

#endif /* CCASTUNIT_T */
