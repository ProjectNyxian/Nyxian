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

#import <LindChain/Project/NXDocumentManager.h>
#import <os/lock.h>
#import <LindChain/Utils/LDEThreadGroupController.h>

@implementation NXDocumentManager {
    NSMutableDictionary<NSURL*,NXDocument*> *_documents;
    os_unfair_lock _lock;
}

- (instancetype)init
{
    self = [super init];
    _lock = OS_UNFAIR_LOCK_INIT;
    _documents = [NSMutableDictionary dictionary];
    return self;
}

+ (instancetype)shared
{
    static NXDocumentManager *manangerSingleton;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        manangerSingleton = [[NXDocumentManager alloc] init];
    });
    return manangerSingleton;
}

- (void)open:(NSURL*)url
  completion:(void (^)(NXDocument*))completion
{
    os_unfair_lock_lock(&_lock);
    NXDocument *document = _documents[url];
    os_unfair_lock_unlock(&_lock);
    if(document)
    {
        if(completion) completion(document);
        return;
    }
    
    document = [[NXDocument alloc] initWithFileURL:url];
    if(document == nil)
    {
        if(completion) completion(nil);
        return;
    }
    
    __weak typeof(self) weakSelf = self;
    [document openWithCompletionHandler:^(BOOL success){
        __strong typeof(self) innerSelf = weakSelf;
        if(!success)
        {
            if(completion) completion(nil);
            return;
        }
        
        os_unfair_lock_lock(&innerSelf->_lock);
        innerSelf->_documents[url] = document;
        os_unfair_lock_unlock(&innerSelf->_lock);
        completion(document);
    }];
}

- (void)close:(NSURL*)url
   completion:(void (^)(void))completion
{
    os_unfair_lock_lock(&_lock);
    NXDocument *document = _documents[url];
    os_unfair_lock_unlock(&_lock);
    if(!document)
    {
        goto out_complete;
    }
    
    [document closeWithCompletionHandler:^(BOOL success){}];
    
out_complete:
    if(completion) completion();
    return;
}

- (void)saveAllWithCompletion:(void (^)(void))completion
{
    os_unfair_lock_lock(&_lock);
    NSArray<NXDocument *> *documents = _documents.allValues;
    os_unfair_lock_unlock(&_lock);
    
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
        LDEThreadGroupController *threadGroupController = [[LDEThreadGroupController alloc] initWithUsersetThreadCount];

        for(NXDocument *document in documents)
        {
            (void)document; /* compiler, ignore this ^^ */
            [threadGroupController enter];
        }
        
        for(NXDocument *document in documents)
        {
            [threadGroupController dispatchExecution:^{
                if(!document.hasUnsavedChanges) return;
                dispatch_semaphore_t sema = dispatch_semaphore_create(0);
                [document saveToURL:document.fileURL forSaveOperation:UIDocumentSaveForOverwriting completionHandler:^(BOOL success) {
                    dispatch_semaphore_signal(sema);
                }];
                dispatch_semaphore_wait(sema, DISPATCH_TIME_FOREVER);
            } withCompletion:nil];
        }
        
        [threadGroupController wait];
        if(completion) dispatch_async(dispatch_get_main_queue(), ^{ completion(); });
    });
}

@end
