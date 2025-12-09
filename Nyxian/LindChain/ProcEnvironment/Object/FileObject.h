/*
 Copyright (C) 2025 cr4zyengineer

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

#ifndef PROCENVIRONMENT_FILEOBJECT_H
#define PROCENVIRONMENT_FILEOBJECT_H

/* ----------------------------------------------------------------------
 *  Apple API Headers
 * -------------------------------------------------------------------- */
#import <Foundation/Foundation.h>

/* ----------------------------------------------------------------------
 *  Environment API Headers
 * -------------------------------------------------------------------- */
#import <LindChain/ProcEnvironment/Object/PEObject.h>

@interface FileObject : PEObject <NSSecureCoding>

@property (nonatomic) NSString *path;
@property (nonatomic) int fd;

- (instancetype)initWithPath:(NSString*)path withFlags:(UInt32)flags;
- (instancetype)initWithPath:(NSString*)path;
- (instancetype)initWithFileDescriptor:(int)fd withPath:(NSString*)path;

- (BOOL)writeOut:(NSString*)path;
- (BOOL)writeIn:(NSString*)path;

@end

#endif /* PROCENVIRONMENT_FILEOBJECT_H */
