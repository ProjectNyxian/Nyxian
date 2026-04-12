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

#ifndef LDEOBJECTCOMPILER_H
#define LDEOBJECTCOMPILER_H

#include <LindChain/CoreCompiler/CCUnit.h>

#ifdef __cplusplus
extern "C" {
#endif /* __cplusplus */

typedef struct opaque_compiler *object_compiler_t;

object_compiler_t CreateObjectCompiler(int argc, const char **argv);
void FreeObjectCompiler(object_compiler_t cmp);

/* MARK: this will mark that this API will deprecate and will become CCObjectFile or CCObjectCompiler */
CCUnitRef CompileObject(object_compiler_t cmp, const char *inputFilePath, const char *outputFilePath, bool *didSucceed);

#ifdef __cplusplus
}
#endif /* __cplusplus */

#endif /* LDEOBJECTCOMPILER_H */
