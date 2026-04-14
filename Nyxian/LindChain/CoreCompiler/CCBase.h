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

#ifndef CCBASE_H
#define CCBASE_H

#include <CoreFoundation/CoreFoundation.h>
#include <LindChain/Private/CoreFoundation/CFRuntime.h>

#ifdef __cplusplus
#define CC_EXPORT extern "C" __attribute__((visibility("default")))
#define CC_CXX_EXPORT extern __attribute__((visibility("default")))
#else
#define CC_EXPORT extern __attribute__((visibility("default")))
#endif

typedef CF_ENUM(uint8_t, CCDiagnosticType) {
    CCDiagnosticTypeFile = 0,
    CCDiagnosticTypeTargetFile,
    CCDiagnosticTypeInternal,
    CCDiagnosticTypeUnknown,
};

typedef CF_ENUM(uint8_t, CCDiagnosticLevel) {
    CCDiagnosticLevelNote = 0,
    CCDiagnosticLevelRemark,
    CCDiagnosticLevelWarning,
    CCDiagnosticLevelError,
    CCDiagnosticLevelFatal,
    CCDiagnosticLevelUnknown,
};

typedef CF_ENUM(uint8_t, CCJobType) {
    CCJobTypeCompiler = 0,
    CCJobTypeLinker,
    CCJobTypeUnknown
};

#endif /* CCBASE_H */
