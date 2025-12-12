/*
 Copyright (C) 2025 cr4zyengineer
 Copyright (C) 2025 expo

 This file is part of Nyxian.

 FridaCodeManager is free software: you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.

 FridaCodeManager is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 GNU General Public License for more details.

 You should have received a copy of the GNU General Public License
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
#import <LindChain/Utils/Zip.h>
#import <LindChain/Utils/LDEDebouncer.h>
#import <LindChain/Utils/LDEThreadGroupController.h>

/* LiveContainer Headers */
#import <LindChain/LiveContainer/LCAppInfo.h>
#import <LindChain/LiveContainer/LCUtils.h>
#import <LindChain/LiveContainer/LCMachOUtils.h>
#import <LindChain/LiveContainer/ZSign/zsigner.h>

/* Daemon Interfaces Headers */
#import <LindChain/Services/applicationmgmtd/LDEApplicationWorkspace.h>
#import <LindChain/Services/trustd/LDETrust.h>

/* Multitask Headers */
#import <LindChain/Multitask/ProcessManager/LDEProcessManager.h>
#import <LindChain/Multitask/WindowServer/LDEWindowServer.h>
#import <LindChain/Multitask/WindowServer/Session/LDEWindowSessionApplication.h>
#import <LindChain/Multitask/WindowServer/Session/LDEWindowSessionTerminal.h>
#import <LindChain/LaunchServices/LaunchService.h>

/* Kernel Virtualisation Layer Headers */
#import <LindChain/ProcEnvironment/Utils/klog.h>
#import <LindChain/ProcEnvironment/Surface/surface.h>
#import <LindChain/ProcEnvironment/Server/Trust.h>
#import <LindChain/ProcEnvironment/Object/MachOObject.h>

/* Project Headers */
#import <Project/NXUser.h>
#import <Project/NXCodeTemplate.h>
#import <Project/NXPlistHelper.h>
#import <Project/NXProject.h>

/* UI Headers */
#import <UI/TableCells/NXProjectTableCell.h>
#import <UI/XCodeButton.h>
