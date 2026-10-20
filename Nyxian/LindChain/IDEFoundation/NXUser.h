/*
 SPDX-License-Identifier: LicenseRef-EPSL-1.1

 Copyright (C) 2025 - 2026 emexlab

 This file is part of Nyxian.

 Licensed under the emexLabs Public Source License, version 1.1
 (EPSL 1.1).

 Private use and modification are permitted under the license.
 Redistribution of source or binaries, modified or unmodified,
 requires prior written permission from emexLabs.

 External deployment is subject to the source-availability
 requirements and other conditions of the license.

 Provided "AS IS", without warranty, to the extent permitted by law.

 See LICENSE for the full license terms.
*/

#ifndef NXUSER_H
#define NXUSER_H

#import <Foundation/Foundation.h>

@interface NXUser : NSObject

@property (nonatomic,strong,readwrite) NSString *projectName;
@property (nonatomic,strong,readwrite) NSString *username;
@property (nonatomic,strong,readonly) NSString *datestring;

+ (NXUser*)shared;

- (NSString*)generateHeaderForFileName:(NSString*)fileName;
- (NSString*)generateFileCreationContentForName:(NSString*)fileName;

@end

#endif /* NXUSER_H */
