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

#ifdef __OBJC__
#import <Foundation/Foundation.h>
#endif /* __OBJC__ */

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif /* __cplusplus */

#ifdef __OBJC__
typedef NS_ENUM(uint8_t, SPDiagType) {
#else
typedef enum SPDiagType : uint8_t {
#endif /* __OBJC__ */
    SPDiagTypeFile = 0,
    SPDiagTypeTargetFile,
    SPDiagTypeInternal,
#ifdef __OBJC__
};
#else
} SPDiagType;
#endif /* __OBJC__ */

#ifdef __OBJC__
typedef NS_ENUM(uint8_t, SPDiagLevel) {
#else
typedef enum SPDiagLevel : uint8_t  {
#endif /* __OBJC__ */
    SPDiagLevelNote = 0,
    SPDiagLevelRemark,
    SPDiagLevelWarning,
    SPDiagLevelError,
    SPDiagLevelFatal,
#ifdef __OBJC__
};
#else
} SPDiagLevel;
#endif /* __OBJC__ */

typedef struct spdiag {
    SPDiagType type;
    SPDiagLevel level;
    
    const char *filepath;
    
    uint64_t line;
    uint64_t column;
    
    const char *message;
} spdiag_t;

typedef struct opaque_synpushcore *spcore_t;

spcore_t SPCreateCore(int argc, const char **argv);
void SPFreeCore(spcore_t spc);

bool SPCreateUnit(spcore_t spc);
void SPDestroyUnit(spcore_t spc);

void SPUpdateArguments(spcore_t spc, int argc, const char **argv);
void SPUpdateFileContent(spcore_t spc, const char *filepath, const char *content);

uint64_t SPDiagnosticCount(spcore_t spc);
spdiag_t SPDiagnosticGet(spcore_t spc, uint64_t index);
void SPDiagnosticDestroy(spdiag_t syndiag);

#ifdef __cplusplus
}
#endif /* __cplusplus */

#endif /* SYNPUSHCORE_H */
