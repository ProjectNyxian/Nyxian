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
#import <Nyxian-Swift.h>

@interface LDEApplicationWorkspace ()

@property (nonatomic,strong) NSMutableArray<LDEApplicationObject*> *apps;

@end

@implementation LDEApplicationWorkspace

- (instancetype)init
{
    self = [super init];
    if(self)
    {
        _apps = [[NSMutableArray alloc] init];
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

- (BOOL)connect
{
    __weak typeof(self) weakSelf = self;
    _connection = nil;
    LaunchServices *launchServices = [LaunchServices shared];
    
    if(launchServices != nil)
    {
        NSLog(@"connecting to installd");
        _connection = [launchServices connectToService:@"com.cr4zy.installd" protocol:@protocol(LDEApplicationWorkspaceProxyProtocol) observer:self observerProtocol:@protocol(LDEApplicationWorkspaceProtocol)];
        _connection.invalidationHandler = ^{
            [weakSelf connect];
        };
        
        return YES;
    }
    
    return NO;
}

- (void)ping
{
    [_connection.remoteObjectProxy ping];
}

- (BOOL)installApplicationAtBundlePath:(NSString*)bundlePath
{
    if(_connection == nil && ![self connect])
    {
        return NO;
    }
    
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
    if(_connection == nil && ![self connect])
    {
        return NO;
    }
    
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
    if(_connection == nil && ![self connect])
    {
        return NO;
    }
    
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
    if(_connection == nil && ![self connect])
    {
        return NO;
    }
    
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
    if(_connection == nil && ![self connect])
    {
        return nil;
    }
    
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
    if(_connection == nil && ![self connect])
    {
        return nil;
    }
    
    return _apps;
}

- (BOOL)clearContainerForBundleID:(NSString *)bundleID
{
    if(_connection == nil && ![self connect])
    {
        return NO;
    }
    
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
    if(_connection == nil && ![self connect])
    {
        return nil;
    }
    
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
    if(_connection == nil && ![self connect])
    {
        return nil;
    }
    
    __block LDEApplicationObject *application = nil;
    dispatch_semaphore_t sema = dispatch_semaphore_create(0);
    [_connection.remoteObjectProxy applicationObjectForExecutablePath:executablePath withReply:^(LDEApplicationObject *applicationReply){
        application = applicationReply;
        dispatch_semaphore_signal(sema);
    }];
    dispatch_semaphore_wait(sema, DISPATCH_TIME_FOREVER);
    return application;
}

- (void)applicationWasInstalled:(LDEApplicationObject*)app
{
    dispatch_async(dispatch_get_main_queue(), ^{
        [[ApplicationManagementViewController shared] applicationWasInstalled:app];
        LDEAppLaunchpad *launchPad = [[LDEWindowServer shared] getOrCreateLaunchpad];
        [launchPad registerAppWithBundleID:app.bundleIdentifier displayName:app.displayName icon:app.icon appPath:app.executablePath];
    });
}

- (void)applicationWithBundleIdentifierWasUninstalled:(NSString*)bundleIdentifier
{
    if(_connection == nil && ![self connect])
    {
        return;
    }
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [[ApplicationManagementViewController shared] applicationWithBundleIdentifierWasUninstalled:bundleIdentifier];
        LDEAppLaunchpad *launchPad = [[LDEWindowServer shared] getOrCreateLaunchpad];
        [launchPad unregisterAppWithBundleID:bundleIdentifier];
    });
}

@end
