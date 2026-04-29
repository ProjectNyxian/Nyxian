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

#ifndef NXDOCUMENT_H
#define NXDOCUMENT_H

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@class NXDocument;

@protocol NXDocumentDelegate <NSObject>

- (NSString *)documentRequestsText:(NXDocument *)document;

@end

@interface NXDocument : UIDocument

@property (nonatomic, weak) id<NXDocumentDelegate> delegate;
@property (nonatomic,strong) NSString *text;
@property (nonatomic) BOOL isLocked;

- (BOOL)loadFromContents:(id)contents ofType:(NSString *)typeName error:(NSError **)outError;
- (id)contentsForType:(NSString *)typeName error:(NSError **)outError;

@end

#endif /* NXDOCUMENT_H */
