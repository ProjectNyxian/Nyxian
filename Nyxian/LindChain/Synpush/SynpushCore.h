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

#ifndef SYNPUSHCORE_H
#define SYNPUSHCORE_H

#include <stdint.h>
#include <stddef.h>

#include <CoreFoundation/CoreFoundation.h>
#include <LindChain/CoreCompiler/CCDiagnostic.h>

#ifdef __cplusplus
extern "C" {
#endif /* __cplusplus */

typedef struct opaque_synpushunit *SPUnit;

CFTypeID SPUnitGetTypeID(void);

SPUnit CF_RETURNS_RETAINED SPUnitCreate(const CFAllocatorRef allocator);
bool SPUnitReparse(SPUnit unit);

void SPUnitSetArguments(SPUnit unit, int argc, const char **argv);
void SPUnitSetFileContent(SPUnit unit, const char *filepath, const char *content, size_t length);

uint64_t SPUnitGetDiagnosticCount(SPUnit unit);
CCDiagnosticRef CF_RETURNS_RETAINED CCDiagnosticCreateFromUnit(SPUnit unit, uint64_t index);

#ifdef __cplusplus
}
#endif /* __cplusplus */

#endif /* SYNPUSHCORE_H */
