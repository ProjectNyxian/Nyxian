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

#ifdef __cplusplus
extern "C" {
#endif /* __cplusplus */

#ifdef __OBJC__
typedef NS_ENUM(uint8_t, SynpushType) {
#else
typedef enum SynpushType : uint8_t {
#endif /* __OBJC__ */
    SynpushTypeFile = 0,
    SynpushTypeTargetFile,
    SynpushTypeInternal,
#ifdef __OBJC__
};
#else
} SynpushType;
#endif /* __OBJC__ */

#ifdef __OBJC__
typedef NS_ENUM(uint8_t, SynpushLevel) {
#else
typedef enum SynpushLevel : uint8_t  {
#endif /* __OBJC__ */
    SynpushLevelNote = 0,
    SynpushLevelRemark,
    SynpushLevelWarning,
    SynpushLevelError,
    SynpushLevelFatal,
#ifdef __OBJC__
};
#else
} SynpushLevel;
#endif /* __OBJC__ */

typedef struct opaque_synpushcore *synpushcore_t;

typedef struct synpushitem {
    SynpushType type;
    SynpushLevel level;
    
    const char *filepath;
    
    uint64_t line;
    uint64_t column;
    
    const char *message;
} synpushdiag_t;

synpushcore_t SPCCreateCore(int argc, const char **argv);
void SPCFreeCore(synpushcore_t spc);

void SPCCreateUnit(synpushcore_t spc);
void SPCDestroyUnit(synpushcore_t spc);

void SPCUpdateArguments(synpushcore_t spc, int argc, const char **argv);
void SPCUpdateFileContent(synpushcore_t spc, const char *filepath, const char *content);

uint64_t SPCDiagnosticCount(synpushcore_t spc);
synpushdiag_t SPCDiagnosticGet(synpushcore_t spc, uint64_t index);
void SPCDiagnosticDestroy(synpushdiag_t syndiag);

#ifdef __cplusplus
}
#endif /* __cplusplus */

#endif /* SYNPUSHCORE_H */
