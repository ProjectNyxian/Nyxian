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

/* idk somehow the bridging header needs its own */
#define JAILBREAK_ENV 1

/* Apple Private API Headers */
#import <LindChain/Private/UIKitPrivate.h>

/* LindChain Core Headers */
#import <LindChain/ProcEnvironment/Surface/extra/relax.h>
#import <LindChain/ProcEnvironment/Process/PEProcessManager.h>
#import <LindChain/WindowServer/NXWindowServer.h>
#import <LindChain/WindowServer/Session/NXWindowSessionApplication.h>
#import <LindChain/Synpush/Synpush.h>
#import <LindChain/Downloader/fdownload.h>
#import <LindChain/Core/LDEFilesFinder.h>
#import <LindChain/Utils/Zip.h>
#import <LindChain/Utils/LDEDebouncer.h>
#import <LindChain/Utils/Utils.h>
#import <LindChain/JBSupport/Shell.h>
#import <LindChain/LiveContainer/ZSign/zsigner.h>

/* Project Headers */
#import <LindChain/Project/NXUser.h>
#import <LindChain/Project/NXCodeTemplate.h>
#import <LindChain/Project/NXPlist.h>
#import <LindChain/Project/NXProject.h>
#import <LindChain/Project/NXDocumentManager.h>
#import <LindChain/Project/NXUtils.h>
#import <NXBootstrap.h>

/* UI Headers */
#import <UI/TableCells/NXProjectTableCell.h>
#import <UI/XCodeButton.h>
#import <LindChain/Debugger/Logger.h>
