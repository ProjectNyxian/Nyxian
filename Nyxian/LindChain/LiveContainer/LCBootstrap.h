/*
 SPDX-License-Identifier: AGPL-3.0-or-later

 Copyright (C) 2023 - 2026 LiveContainer
 Copyright (C) 2026 mach-port-t

 This file is part of LiveContainer.

 LiveContainer is free software: you can redistribute it and/or modify
 it under the terms of the GNU Affero General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.

 LiveContainer is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 GNU Affero General Public License for more details.

 You should have received a copy of the GNU Affero General Public License
 along with Nyxian. If not, see <https://www.gnu.org/licenses/>.
*/

#ifndef LIGHTCONTAINER_LCBOOTSTRAP_H
#define LIGHTCONTAINER_LCBOOTSTRAP_H

#import <Foundation/Foundation.h>

void LCOverwriteExecutablePath(NSString *executablePath);
int LCBootstrapMain(NSString *executablePath, int argc, char *argv[]);

#endif /* LIGHTCONTAINER_LCBOOTSTRAP_H */
