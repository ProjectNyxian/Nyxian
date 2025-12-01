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

#import "LDEApplicationWorkspace.h"
#import <LindChain/Private/FoundationPrivate.h>
#import <LindChain/ProcEnvironment/Server/Server.h>
#import <LindChain/ProcEnvironment/Object/ArchiveObject.h>
#import <LindChain/Utils/Zip.h>
#import <LindChain/Multitask/ProcessManager/LDEProcessManager.h>
#import <LindChain/LaunchServices/LaunchService.h>

@implementation LDEApplicationWorkspace

- (instancetype)init
{
    self = [super init];
    if(self)
    {
        [self connect];
    }
    return self;
}

+ (instancetype)shared
{
    static LDEApplicationWorkspace *applicationWorkspaceSingleton = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        applicationWorkspaceSingleton = [[LDEApplicationWorkspace alloc] init];
    });
    return applicationWorkspaceSingleton;
}

- (void)connect
{
    __weak typeof(self) weakSelf = self;
    _connection = [[LaunchServices shared] connectToService:@"com.cr4zy.installd" protocol:@protocol(LDEApplicationWorkspaceProxyProtocol) observer:self observerProtocol:@protocol(LDEApplicationWorkspaceProtocol)];
    _connection.invalidationHandler = ^{
        [weakSelf connect];
    };
}

- (BOOL)installApplicationAtBundlePath:(NSString*)bundlePath
{
    __block BOOL result = NO;
    ArchiveObject *archiveObject = [[ArchiveObject alloc] initWithDirectory:bundlePath];
    dispatch_semaphore_t sema = dispatch_semaphore_create(0);
    [_connection.remoteObjectProxy installApplicationWithArchiveObject:archiveObject withReply:^(BOOL replyResult){
        result = replyResult;
        dispatch_semaphore_signal(sema);
    }];
    dispatch_semaphore_wait(sema, DISPATCH_TIME_FOREVER);
    return result;
}

- (BOOL)installApplicationAtPackagePath:(NSString*)packagePath
{
    __block BOOL result = NO;
    ArchiveObject *archiveObject = [[ArchiveObject alloc] initWithArchive:packagePath];
    dispatch_semaphore_t sema = dispatch_semaphore_create(0);
    [_connection.remoteObjectProxy installApplicationWithArchiveObject:archiveObject withReply:^(BOOL replyResult){
        result = replyResult;
        dispatch_semaphore_signal(sema);
    }];
    dispatch_semaphore_wait(sema, DISPATCH_TIME_FOREVER);
    return result;
}

- (BOOL)deleteApplicationWithBundleID:(NSString *)bundleID
{
    __block BOOL result = NO;
    dispatch_semaphore_t sema = dispatch_semaphore_create(0);
    [_connection.remoteObjectProxy deleteApplicationWithBundleID:bundleID withReply:^(BOOL replyResult){
        result = replyResult;
        dispatch_semaphore_signal(sema);
    }];
    dispatch_semaphore_wait(sema, DISPATCH_TIME_FOREVER);
    return result;
}

- (BOOL)applicationInstalledWithBundleID:(NSString *)bundleID
{
    __block BOOL result = NO;
    dispatch_semaphore_t sema = dispatch_semaphore_create(0);
    [_connection.remoteObjectProxy applicationInstalledWithBundleID:bundleID withReply:^(BOOL replyResult){
        result = replyResult;
        dispatch_semaphore_signal(sema);
    }];
    dispatch_semaphore_wait(sema, DISPATCH_TIME_FOREVER);
    return result;
}

- (LDEApplicationObject*)applicationObjectForBundleID:(NSString*)bundleID
{
    __block LDEApplicationObject *result = nil;
    dispatch_semaphore_t sema = dispatch_semaphore_create(0);
    [_connection.remoteObjectProxy applicationObjectForBundleID:bundleID withReply:^(LDEApplicationObject *replyResult){
        result = replyResult;
        dispatch_semaphore_signal(sema);
    }];
    dispatch_semaphore_wait(sema, DISPATCH_TIME_FOREVER);
    return result;
}

- (NSArray<LDEApplicationObject*>*)allApplicationObjects
{
    __block NSArray<LDEApplicationObject*> *result = nil;
    dispatch_semaphore_t sema = dispatch_semaphore_create(0);
    [_connection.remoteObjectProxy allApplicationObjectsWithReply:^(LDEApplicationObjectArray *replyResult) {
        result = replyResult.applicationObjects;
        dispatch_semaphore_signal(sema);
    }];
    dispatch_semaphore_wait(sema, DISPATCH_TIME_FOREVER);
    return result;
}

- (BOOL)clearContainerForBundleID:(NSString *)bundleID
{
    __block BOOL result = NO;
    dispatch_semaphore_t sema = dispatch_semaphore_create(0);
    [_connection.remoteObjectProxy clearContainerForBundleID:bundleID withReply:^(BOOL replyResult){
        result = replyResult;
        dispatch_semaphore_signal(sema);
    }];
    dispatch_semaphore_wait(sema, DISPATCH_TIME_FOREVER);
    return result;
}

- (NSString*)fastpathUtility:(NSString*)utilityPath
{
    __block NSString *fastpath = nil;
    dispatch_semaphore_t sema = dispatch_semaphore_create(0);
    [_connection.remoteObjectProxy fastpathUtility:[[FileObject alloc] initWithPath:utilityPath] withReply:^(NSString *fastPathRet, BOOL fastSigned){
        fastpath = fastSigned ? fastPathRet : nil;
        dispatch_semaphore_signal(sema);
    }];
    dispatch_semaphore_wait(sema, DISPATCH_TIME_FOREVER);
    return fastpath;
}

- (LDEApplicationObject*)applicationObjectForExecutablePath:(NSString*)executablePath
{
    __block LDEApplicationObject *application = nil;
    dispatch_semaphore_t sema = dispatch_semaphore_create(0);
    [_connection.remoteObjectProxy applicationObjectForExecutablePath:executablePath withReply:^(LDEApplicationObject *applicationReply){
        application = applicationReply;
        dispatch_semaphore_signal(sema);
    }];
    dispatch_semaphore_wait(sema, DISPATCH_TIME_FOREVER);
    return application;
}

- (BOOL)openApplicationWithBundleIdentifier:(NSString*)bundleIdentifier
{
    __block BOOL retval = NO;
    dispatch_semaphore_t sema = dispatch_semaphore_create(0);
    [_connection.remoteObjectProxy openApplicationWithBundleIdentifier:bundleIdentifier withReply:^(BOOL result){
        retval = result;
        dispatch_semaphore_signal(sema);
    }];
    dispatch_semaphore_wait(sema, DISPATCH_TIME_FOREVER);
    return retval;
}

- (void)applicationsInitial:(LDEApplicationObjectArray*)array
{
    NSLog(@"Received %@",array.applicationObjects);
}

- (void)applicationWasInstalled:(LDEApplicationObject*)app
{
    NSLog(@"Installed: %@", app);
}

- (void)applicationWasUninstalled:(LDEApplicationObject*)app
{
    NSLog(@"Uninstalled: %@", app);
}

@end
