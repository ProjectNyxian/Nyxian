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

/* idk somehow the bridging header needs its own */
#define JAILBREAK_ENV 1

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
#import <LindChain/jbroot.h>

/* Project Headers */
#import <LindChain/Project/NXUser.h>
#import <LindChain/Project/NXCodeTemplate.h>
#import <LindChain/Project/NXPlistHelper.h>
#import <LindChain/Project/NXProject.h>

/* UI Headers */
#import <UI/TableCells/NXProjectTableCell.h>
#import <UI/XCodeButton.h>
