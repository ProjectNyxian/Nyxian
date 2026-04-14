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

#ifndef CCJOB_H
#define CCJOB_H

#include <LindChain/CoreCompiler/CCBase.h>
#include <LindChain/CoreCompiler/CCDiagnostic.h>
#ifdef __cplusplus
#include <clang/Driver/Job.h>
#endif /* __cplusplus */

typedef struct opaque_ccjob *CCJobRef;

CC_EXPORT CFTypeID CCJobGetTypeID(void);

#ifdef __cplusplus
CC_CXX_EXPORT CCJobRef CCJobCreate(CFAllocatorRef allocator, CFTypeRef driver, const clang::driver::Command *Cmd);
#endif /* __cplusplus */

CC_EXPORT CCJobType CCJobGetType(CCJobRef job);
CC_EXPORT CFArrayRef CCJobCopyArguments(CCJobRef job);
CC_EXPORT CFArrayRef CCJobGetInput(CCJobRef job);
CC_EXPORT CFArrayRef CCJobGetOutput(CCJobRef job);
CC_EXPORT void CCJobSetInput(CCJobRef job, CFArrayRef input);
CC_EXPORT void CCJobSetOutput(CCJobRef job, CFArrayRef output);

/*
 * TODO: create a easy job execution method
 *
 * CC_EXPORT Boolean CCJobExecute(CCJobRef job, CFArrayRef *diagnostics);
 */

#endif /* CCJOB_H */
