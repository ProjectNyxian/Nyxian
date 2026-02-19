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

#ifndef CHECKFILE_H
#define CHECKFILE_H

/* ----------------------------------------------------------------------
 *  Apple API Headers
 * -------------------------------------------------------------------- */
#import <Foundation/Foundation.h>

/* ----------------------------------------------------------------------
 *  Clang API Headers
 * -------------------------------------------------------------------- */
#include <clang-c/Index.h>

@class CheckEngine;

@interface CheckFile : NSObject

@property (nonatomic,readonly,weak) CheckEngine *engine;
@property (nonatomic,readonly) struct CXUnsavedFile unsavedFile;

- (instancetype)initWithEngine:(CheckEngine*)engine withPath:(NSString*)path;

- (void)reparseFileWithContent:(NSString*)content;

@end

#endif /* CHECKFILE_H */
