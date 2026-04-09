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


#import <LindChain/Project/NXDocument.h>

@implementation NXDocument

- (void)autosaveWithCompletionHandler:(void (^)(BOOL))completionHandler
{
    /* REQUIRED, OTHERWISE YOUR CODE IS GONE AFTER CLOSING PROJECT */
    if(!self.hasUnsavedChanges)
    {
        if (completionHandler) completionHandler(YES);
        return;
    }
    [self saveToURL:self.fileURL
   forSaveOperation:UIDocumentSaveForOverwriting
  completionHandler:^(BOOL success) {
        [super autosaveWithCompletionHandler:^(BOOL _) {
            if(completionHandler) completionHandler(success);
        }];
    }];
}

- (void)setText:(NSString *)text
{
    _text = [text copy];
    [self updateChangeCount:UIDocumentChangeDone];
}

- (BOOL)loadFromContents:(id)contents
                  ofType:(NSString *)typeName
                   error:(NSError **)outError
{
    NSData *data = contents;
    _text = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    
    /* fallback encodings so my japanese and chinese users are happy */
    if(!_text)
    {
        NSStringEncoding detected;
        _text = [NSString stringWithContentsOfURL:self.fileURL usedEncoding:&detected error:outError];
    }
    
    if(!_text)
    {
        _text = [[NSString alloc] initWithData:data encoding:NSISOLatin1StringEncoding];
    }
    
    return YES;
}

- (id)contentsForType:(NSString *)typeName error:(NSError **)outError
{
    NSData *data = [self.text dataUsingEncoding:NSUTF8StringEncoding allowLossyConversion:NO];
    
    if(!data)
    {
        if(outError)
        {
            *outError = [NSError errorWithDomain:NSCocoaErrorDomain code:NSFileWriteInapplicableStringEncodingError userInfo:nil];
        }
        return nil;
    }
    
    return data;
}

@end
