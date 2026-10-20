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

#import <LindChain/IDEFoundation/NXDocumentManager.h>
#import <os/lock.h>
#import <MobileDevelopmentKit/MDKThreadPoolGroup.h>

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
    [_documents removeObjectForKey:url];
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
    
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_BACKGROUND, 0), ^{
        MDKThreadPoolGroup *threadPoolGroup = [[MDKThreadPoolGroup alloc] initWithThreads:CCGetMaximumPerformanceCores()];

        for(NXDocument *document in documents)
        {
            (void)document; /* compiler, ignore this ^^ */
            [threadPoolGroup enter];
        }
        
        for(NXDocument *document in documents)
        {
            [threadPoolGroup dispatchExecution:^{
                if(!document.hasUnsavedChanges) return;
                dispatch_semaphore_t sema = dispatch_semaphore_create(0);
                [document saveToURL:document.fileURL forSaveOperation:UIDocumentSaveForOverwriting completionHandler:^(BOOL success) {
                    dispatch_semaphore_signal(sema);
                }];
                dispatch_semaphore_wait(sema, DISPATCH_TIME_FOREVER);
            } withCompletion:nil];
        }
        
        [threadPoolGroup wait];
        if(completion) dispatch_async(dispatch_get_main_queue(), ^{ completion(); });
    });
}

- (void)changeAllLockStateToBoolean:(BOOL)isLocked
{
    os_unfair_lock_lock(&_lock);
    for(NXDocument *document in _documents.allValues)
    {
        [document setIsLocked:isLocked];
    }
    os_unfair_lock_unlock(&_lock);
}

@end
