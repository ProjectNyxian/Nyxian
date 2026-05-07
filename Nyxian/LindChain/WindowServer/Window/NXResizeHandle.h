/*
 SPDX-License-Identifier: AGPL-3.0-or-later

 Copyright (C) 2023 - 2025 LiveContainer
 Copyright (C) 2025 - 2026 mach-port-t

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

// Duy, please don't forget to use header gates, then you also dont have to use any @import's anymore :)

#ifndef NXRESIZEHANDLE_H
#define NXRESIZEHANDLE_H

#import <UIKit/UIKit.h>

@interface NXResizeHandle : UIView

- (instancetype)initWithFrame:(CGRect)frame;

@end

#endif /* NXRESIZEHANDLE_H */
