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

#ifndef CFTOOLS_H
#define CFTOOLS_H

#include <stdint.h>
#include <CoreFoundation/CoreFoundation.h>
#include <LindChain/Private/CoreFoundation/CFRuntime.h>

#define cfheader_size() sizeof(CFRuntimeBase)

void CFOverwrite(CFTypeRef dst, CFTypeRef src);

#endif /* CFTOOLS_H */
