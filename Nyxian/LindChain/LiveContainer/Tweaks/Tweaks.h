/*
 SPDX-License-Identifier: AGPL-3.0-or-later

 Copyright (C) 2023 - 2026 LiveContainer
 Copyright (C) 2026 cr4zyengineer

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

#ifndef TWEAKS_TWEAKS_H
#define TWEAKS_TWEAKS_H

bool performHookDyldApi(const char* functionName, uint32_t adrpOffset, void** origFunction, void* hookFunction);

void NUDGuestHooksInit(void);
void SecItemGuestHooksInit(void);
void DyldHooksInit(void);
void NSFMGuestHooksInit(void);

@interface NSBundle(LiveContainer)
- (instancetype)initWithPathForMainBundle:(NSString *)path;
@end

extern uint32_t appMainImageIndex;
extern void* appExecutableHandle;
extern bool tweakLoaderLoaded;
void* getGuestAppHeader(void);
void* dlopenBypassingLock(const char *path, int mode);
void initDead10ccFix(void);
void UIKitGuestHooksInit(void);

#endif /* TWEAKS_TWEAKS_H */
