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

#import "LDEApplicationWorkspaceInternal.h"
#import <LindChain/ProcEnvironment/environment.h>
#import <LindChain/Utils/Zip.h>
#import <Security/Security.h>
#import <LindChain/ProcEnvironment/Object/FDMapObject.h>
#import <LindChain/Services/applicationmgmtd/LDEApplicationWorkspaceProtocol.h>

bool checkCodeSignature(const char* path);

@interface LDEApplicationWorkspaceInternal ()

@property (nonatomic,strong) NSURL *applicationsURL;
@property (nonatomic,strong) NSURL *containersURL;
@property (nonatomic,strong) NSURL *binaryURL;
@property (nonatomic,strong) NSURL *homeURL;
@property (nonatomic, strong) dispatch_queue_t workspaceQueue;

@end

@implementation LDEApplicationWorkspaceInternal

- (instancetype)init
{
    self = [super init];
    
    // Setting up paths
    NSString *documentsDir = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject];
    self.applicationsURL = [NSURL fileURLWithPath:[documentsDir stringByAppendingPathComponent:@"Bundle/Application"]];
    self.containersURL   = [NSURL fileURLWithPath:[documentsDir stringByAppendingPathComponent:@"Data/Application"]];
    self.binaryURL   = [NSURL fileURLWithPath:[documentsDir stringByAppendingPathComponent:@"usr/bin"]];
    self.homeURL = [NSURL fileURLWithPath:[documentsDir stringByAppendingPathComponent:@"var/mobile"]];
    
    // Creating paths if they dont exist
    NSFileManager *fileManager = [NSFileManager defaultManager];
    if(![fileManager fileExistsAtPath:self.applicationsURL.path])
        [fileManager createDirectoryAtURL:self.applicationsURL
              withIntermediateDirectories:YES
                               attributes:nil
                                    error:nil];
    
    if(![fileManager fileExistsAtPath:self.containersURL.path])
        [fileManager createDirectoryAtURL:self.containersURL
              withIntermediateDirectories:YES
                               attributes:nil
                                    error:nil];
    
    if(![fileManager fileExistsAtPath:self.binaryURL.path])
        [fileManager createDirectoryAtURL:self.binaryURL
              withIntermediateDirectories:YES
                               attributes:nil
                                    error:nil];
    
    if(![fileManager fileExistsAtPath:self.homeURL.path])
        [fileManager createDirectoryAtURL:self.homeURL
              withIntermediateDirectories:YES
                               attributes:nil
                                    error:nil];
    
    // Enumerating all app bundles
    NSArray<NSURL*> *uuidURLs = [fileManager contentsOfDirectoryAtURL:self.applicationsURL includingPropertiesForKeys:nil options:0 error:nil];
    self.bundles = [[NSMutableDictionary alloc] init];
    for(NSURL *uuidURL in uuidURLs)
    {
        NSArray<NSString *> *contents = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:[uuidURL path] error:nil];

        for(NSString *item in contents)
        {
            if([[item pathExtension] isEqualToString:@"app"])
            {
                NSString *fullPath = [[uuidURL path] stringByAppendingPathComponent:item];
                NSBundle *bundle = [NSBundle bundleWithPath:fullPath];
                [self.bundles setObject:bundle forKey:bundle.bundleIdentifier];
            }
            else
            {
                /* what the user cant manage the user cant manage */
                [[NSFileManager defaultManager] removeItemAtURL:uuidURL error:nil];
            }
        }
    }
    
    self.workspaceQueue = dispatch_queue_create("com.cr4zy.installd.workspace", DISPATCH_QUEUE_SERIAL);
    
    return self;
}

+ (LDEApplicationWorkspaceInternal*)shared
{
    static LDEApplicationWorkspaceInternal *applicationWorkspaceSingleton = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        applicationWorkspaceSingleton = [[LDEApplicationWorkspaceInternal alloc] init];
    });
    return applicationWorkspaceSingleton;
}

/*
 Action
 */
- (BOOL)doWeTrustThatBundle:(NSBundle*)bundle
{
    if(!bundle) return NO;
    //else if(![bundle validateBundleMetadataWithError:nil]) return NO;
    //else if(![bundle isAppTypeBundle]) return NO;
    //else if(![bundle validateAppMetadataWithError:nil]) return NO;
    //else if(![bundle isApplicableToCurrentOSVersionWithError:nil]) return NO;
    //else if(![bundle isApplicableToCurrentDeviceFamilyWithError:nil]) return NO;
    //else if(![bundle isApplicableToCurrentDeviceCapabilitiesWithError:nil]) return NO;
    
    // MARK: Validate certificate using LC`s CS Check
    if(!checkCodeSignature([[bundle.executableURL path] UTF8String])) return NO;
    
    return YES;
}

- (BOOL)installApplicationWithPayloadPath:(NSString*)payloadPath
{
    // finding bundle
    NSBundle *bundle = nil;
    NSArray<NSString *> *contents = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:payloadPath error:nil];
    
    for(NSString *item in contents)
    {
        if([[item pathExtension] isEqualToString:@"app"])
        {
            NSString *fullPath = [payloadPath stringByAppendingPathComponent:item];
            bundle = [NSBundle bundleWithPath:fullPath];
            break;
        }
    }
    
    // Check if bundle is valid for LDEApplicationWorkspace
    if(!bundle) return NO;
    else if(![self doWeTrustThatBundle:bundle]) return NO;
    
    // File manager
    NSFileManager *fileManager = [NSFileManager defaultManager];
    
    // Now generate installPath
    NSURL *installURL = nil;
    NSBundle *previousApplication = [self applicationBundleForBundleID:[bundle bundleIdentifier]];
    if(previousApplication)
    {
        // It existed before, using old path
        installURL = previousApplication.bundleURL;
        [fileManager removeItemAtURL:installURL error:nil];
        previousApplication = nil;
    }
    else
    {
        // It didnt existed before, using new path
        installURL = [[self.applicationsURL URLByAppendingPathComponent:[[NSUUID UUID] UUIDString]] URLByAppendingPathComponent:[bundle.bundleURL lastPathComponent]];
    }
    
    // Now installing at install location
    if(![fileManager createDirectoryAtURL:[installURL URLByDeletingLastPathComponent] withIntermediateDirectories:YES attributes:nil error:nil]) return NO;
    if(![fileManager moveItemAtURL:bundle.bundleURL toURL:installURL error:nil]) return NO;
    
    // If existed we add object
    NSError *error = nil;
    bundle = [NSBundle bundleWithURL:installURL];
    
    // checking if adding it was successful
    if(bundle != nil)
    {
        [self.bundles setObject:bundle forKey:bundle.bundleIdentifier];
        LDEApplicationObject *object = [[LDEApplicationObject alloc] initWithNSBundle:bundle];
        if(object != nil)
        {
            for(NSXPCConnection *client in [[ServiceServer sharedService] clients])
            {
                [client.remoteObjectProxy applicationWasInstalled:object];
            }
        }
        return YES;
    }
    else
    {
        return NO;
    }
}

- (BOOL)deleteApplicationWithBundleID:(NSString *)bundleID
{
    NSBundle *previousApplication = [self applicationBundleForBundleID:bundleID];
    
    if(previousApplication == nil)
    {
        return NO;
    }
    
    LDEApplicationObject *appObject = [[LDEApplicationObject alloc] initWithNSBundle:previousApplication];
    
    if(appObject == nil)
    {
        return NO;
    }
    
    [[NSFileManager defaultManager] removeItemAtURL:[[previousApplication bundleURL] URLByDeletingLastPathComponent] error:nil];
    [[NSFileManager defaultManager] removeItemAtPath:[appObject containerPath] error:nil];
    [self.bundles removeObjectForKey:bundleID];
    
    for(NSXPCConnection *client in [[ServiceServer sharedService] clients])
    {
        [client.remoteObjectProxy applicationWithBundleIdentifierWasUninstalled:appObject.bundleIdentifier];
    }
    
    return YES;
}

- (BOOL)applicationInstalledWithBundleID:(NSString*)bundleID
{
    __block BOOL result = NO;
    dispatch_sync(self.workspaceQueue, ^{
        result = [self.bundles objectForKey:bundleID] ? YES : NO;
    });
    return result;
}

- (NSBundle*)applicationBundleForBundleID:(NSString *)bundleID
{
    __block NSBundle *result = nil;
    dispatch_sync(self.workspaceQueue, ^{
        result = [self.bundles objectForKey:bundleID];
    });
    return result;
}

- (NSURL*)applicationContainerForBundleID:(NSString *)bundleID
{
    NSBundle *bundle = [self applicationBundleForBundleID:bundleID];
    if(!bundle) return nil;
    NSString *uuid = [[bundle.bundleURL URLByDeletingLastPathComponent] lastPathComponent];
    return [self.containersURL URLByAppendingPathComponent:uuid];
}

- (BOOL)clearContainerForBundleID:(NSString*)bundleID
{
    NSURL *containerURL = [self applicationContainerForBundleID:bundleID];
    [[NSFileManager defaultManager] removeItemAtURL:containerURL error:nil];
    [[NSFileManager defaultManager] createDirectoryAtURL:containerURL
                             withIntermediateDirectories:true
                                              attributes:nil
                                                   error:nil];
    return YES;
}

@end

@implementation LDEApplicationWorkspaceProxy

- (void)ping
{
    return;
}

- (void)applicationInstalledWithBundleID:(NSString *)bundleID
                               withReply:(void (^)(BOOL))reply {
    reply([[LDEApplicationWorkspaceInternal shared] applicationInstalledWithBundleID:bundleID]);
}

- (void)deleteApplicationWithBundleID:(NSString *)bundleID
                            withReply:(void (^)(BOOL))reply {
    reply([[LDEApplicationWorkspaceInternal shared] deleteApplicationWithBundleID:bundleID]);
}

- (void)installApplicationWithArchiveObject:(ArchiveObject*)archiveObject
                                  withReply:(void (^)(BOOL))reply {
    /* validate object*/
    if(archiveObject == NULL)
    {
        reply(NO);
        return;
    }
    
    /* running installation on background queue */
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        NSFileManager *fileManager = [NSFileManager defaultManager];
        NSString *tempBundle = nil;
        BOOL didInstall = NO;
        
        @try {
            tempBundle = [archiveObject extractArchive];
            if(tempBundle != NULL)
            {
                didInstall = [[LDEApplicationWorkspaceInternal shared]
                              installApplicationWithPayloadPath:tempBundle];
            }
        } @catch (NSException *exception) {
            NSLog(@"[installd] Exception during install: %@", exception);
            didInstall = NO;
        } @finally {
            if(tempBundle != NULL)
            {
                [fileManager removeItemAtPath:tempBundle error:nil];
            }
            reply(didInstall);
        }
    });
}

- (void)applicationObjectForBundleID:(NSString *)bundleID
                           withReply:(void (^)(LDEApplicationObject *))reply
{
    NSBundle *bundle = [[LDEApplicationWorkspaceInternal shared] applicationBundleForBundleID:bundleID];
    
    if(!bundle)
    {
        reply(nil);
        return;
    }
    
    reply([[LDEApplicationObject alloc] initWithNSBundle:bundle]);
}

- (void)applicationContainerForBundleID:(NSString*)bundleID
                              withReply:(void (^)(NSURL*))reply
{
    reply([[LDEApplicationWorkspaceInternal shared] applicationContainerForBundleID:bundleID]);
}

- (void)allApplicationObjectsWithReply:(void (^)(LDEApplicationObjectArray *))reply {
    LDEApplicationWorkspaceInternal *workspace = [LDEApplicationWorkspaceInternal shared];
    NSMutableArray<LDEApplicationObject*> *objects = [NSMutableArray array];
    for (NSString *bundleID in workspace.bundles) {
        NSBundle *bundle = workspace.bundles[bundleID];
        if (bundle) {
            [objects addObject:[[LDEApplicationObject alloc] initWithNSBundle:bundle]];
        }
    }
    
    reply([[LDEApplicationObjectArray alloc] initWithApplicationObjects:[objects copy]]);
}

- (void)clearContainerForBundleID:(NSString *)bundleID
                        withReply:(void (^)(BOOL))reply
{
    reply([[LDEApplicationWorkspaceInternal shared] clearContainerForBundleID:bundleID]);
}

- (void)fastpathUtility:(FileObject*)object
              withReply:(void (^)(NSString*,BOOL))reply;
{
    // Write out
    NSURL *url = [NSURL fileURLWithPath:object.path];
    NSString *fastPath = [[[[LDEApplicationWorkspaceInternal shared] binaryURL] path] stringByAppendingPathComponent:[url lastPathComponent]];
    [object writeOut:[[[[LDEApplicationWorkspaceInternal shared] binaryURL] path] stringByAppendingPathComponent:[url lastPathComponent]]];
    bool isSigned = checkCodeSignature([fastPath UTF8String]);
    if(!isSigned)
    {
        environment_proxy_sign_macho(fastPath);
        isSigned = checkCodeSignature([fastPath UTF8String]);
        if(!isSigned)
        {
            [[NSFileManager defaultManager] removeItemAtPath:fastPath error:nil];
        }
    }
    reply(fastPath, isSigned);
}

- (void)applicationObjectForExecutablePath:(NSString*)executablePath
                                 withReply:(void (^)(LDEApplicationObject*))reply
{
    NSString *potentialBundlePath = [executablePath stringByDeletingLastPathComponent];
    NSBundle *bundle = [NSBundle bundleWithURL:[NSURL fileURLWithPath:potentialBundlePath]];
    if(bundle == nil)
    {
        reply(nil);
        return;
    }
    
    LDEApplicationObject *application = [[LDEApplicationObject alloc] initWithNSBundle:bundle];
    reply(application);
}

+ (NSString*)servcieIdentifier
{
    return @"com.cr4zy.installd";
}

+ (Protocol*)serviceProtocol
{
    return @protocol(LDEApplicationWorkspaceProxyProtocol);
}

+ (Protocol *)observerProtocol { 
    return @protocol(LDEApplicationWorkspaceProtocol);
}

- (void)clientDidConnectWithConnection:(NSXPCConnection*)client
{
    id<LDEApplicationWorkspaceProtocol> clientObject = client.remoteObjectProxy;
    LDEApplicationWorkspaceInternal *workspace = [LDEApplicationWorkspaceInternal shared];
    for(NSString *bundleID in workspace.bundles)
    {
        NSBundle *bundle = workspace.bundles[bundleID];
        if(bundle)
        {
            [clientObject applicationWasInstalled:[[LDEApplicationObject alloc] initWithNSBundle:bundle]];
        }
    }
}

@end
