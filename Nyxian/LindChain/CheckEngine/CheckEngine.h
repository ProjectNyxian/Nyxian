/*
 Copyright (C) 2026 cr4zyengineer

 This file is part of Nyxian.

 Nyxian is free software: you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.

 Nyxian is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 GNU General Public License for more details.

 You should have received a copy of the GNU General Public License
 along with Nyxian. If not, see <https://www.gnu.org/licenses/>.
*/

#ifndef CHECKENGINE_H
#define CHECKENGINE_H

/* ----------------------------------------------------------------------
 *  Apple API Headers
 * -------------------------------------------------------------------- */
#import <Foundation/Foundation.h>

/* ----------------------------------------------------------------------
 *  CheckEngine API Headers
 * -------------------------------------------------------------------- */
#import <LindChain/CheckEngine/CheckFile.h>

/* ----------------------------------------------------------------------
 *  Clang API Headers
 * -------------------------------------------------------------------- */
#include <clang-c/Index.h>

@class NXProject;

@interface CheckEngine : NSObject

- (instancetype)initWithProject:(NXProject*)project;

/*
 * allocates a CheckFile object that will stay
 * in sync with the engine all time till deallocated,
 * on deallocation it will automatically fall back to
 * the file systems file.
 */
- (CheckFile*)unsavedFileForPath:(NSString*)path;

- (void)reparse;

@end

#endif /* CHECKENGINE_H */
