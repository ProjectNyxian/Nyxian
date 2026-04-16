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

#ifndef LDEDRIVER_H
#define LDEDRIVER_H

#import <Foundation/Foundation.h>
#import <LindChain/CoreCompiler/CCDriver.h>
#import <LindChain/Compiler/LDECFType.h>
#import <LindChain/Compiler/LDEJob.h>
#import <LindChain/Compiler/LDESDK.h>

@interface LDEDriver : LDECFType

@property (nonatomic, readonly, copy) NSArray<LDEJob*> *jobs;
@property (nonatomic, readwrite) NSString *(^outputPathCallback)(NSString *baseInput);
@property (nonatomic, readonly, copy) NSURL *sysrootURL;
@property (nonatomic, readonly, copy) LDESDK *sdk;

+ (instancetype)driverWithArguments:(NSArray<NSString*>*)arguments;

@end

#endif /* LDEDRIVER_H */
