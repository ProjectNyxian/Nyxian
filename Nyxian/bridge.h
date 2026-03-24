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

/* Apple Private API Headers */
#import <LindChain/Private/UIKitPrivate.h>

/* LindChain Core Headers */
#import <LindChain/Compiler/Compiler.h>
#import <LindChain/Linker/linker.h>
#import <LindChain/Synpush/Synpush.h>
#import <LindChain/Downloader/fdownload.h>
#import <LindChain/Core/LDEFilesFinder.h>
#import <LindChain/Core/LDEHeaderIncludationsGatherer.h>
#import <LindChain/Utils/Zip.h>
#import <LindChain/Utils/LDEDebouncer.h>
#import <LindChain/Utils/LDEThreadGroupController.h>

#if !JAILBREAK_ENV

/* LiveContainer Headers */
#import <LindChain/LiveContainer/LCUtils.h>
#import <LindChain/LiveContainer/LCMachOUtils.h>
#import <LindChain/LiveContainer/ZSign/zsigner.h>
#import <LindChain/ProcEnvironment/Surface/trust.h>

/* Daemon Interfaces Headers */
#import <LindChain/Services/applicationmgmtd/LDEApplicationWorkspace.h>

/* Multitask Headers */
#import <LindChain/Multitask/ProcessManager/LDEProcessManager.h>
#import <LindChain/Multitask/WindowServer/LDEWindowServer.h>
#import <LindChain/Multitask/WindowServer/Session/LDEWindowSessionApplication.h>
#import <LindChain/Multitask/WindowServer/Session/LDEWindowSessionTerminal.h>
#import <LindChain/Debugger/MachServer.h>
#import <LindChain/LaunchServices/LaunchService.h>

/* Kernel Virtualisation Layer Headers */
#import <LindChain/ProcEnvironment/Utils/klog.h>
#import <LindChain/ProcEnvironment/Surface/surface.h>
#import <LindChain/ProcEnvironment/Object/MachOObject.h>

bool liveProcessIsAvailable(void);

#endif /* !JAILBREAK_ENV */

/* Project Headers */
#import <LindChain/Project/NXUser.h>
#import <LindChain/Project/NXCodeTemplate.h>
#import <LindChain/Project/NXPlistHelper.h>
#import <LindChain/Project/NXProject.h>

/* UI Headers */
#import <UI/TableCells/NXProjectTableCell.h>
#import <UI/XCodeButton.h>
#import <LindChain/Debugger/Logger.h>
