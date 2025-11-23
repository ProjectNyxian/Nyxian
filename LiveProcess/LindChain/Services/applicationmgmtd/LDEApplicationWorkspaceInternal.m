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
#import <LindChain/Services/Service.h>

bool checkCodeSignature(const char* path);

/*
 Internal class
 */
@interface LDEApplicationWorkspaceInternal ()

@property (nonatomic,strong) NSURL *applicationsURL;
@property (nonatomic,strong) NSURL *containersURL;
@property (nonatomic,strong) NSURL *binaryURL;

@end

@implementation LDEApplicationWorkspaceInternal

/*
 Init
 */
- (instancetype)init
{
    self = [super init];
    
    // Setting up paths
    NSString *documentsDir = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject];
    self.applicationsURL = [NSURL fileURLWithPath:[documentsDir stringByAppendingPathComponent:@"Bundle/Application"]];
    self.containersURL   = [NSURL fileURLWithPath:[documentsDir stringByAppendingPathComponent:@"Data/Application"]];
    self.binaryURL   = [NSURL fileURLWithPath:[documentsDir stringByAppendingPathComponent:@"usr/bin"]];
    
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
    
    // Enumerating all app bundles
    NSArray<NSURL*> *uuidURLs = [fileManager contentsOfDirectoryAtURL:self.applicationsURL includingPropertiesForKeys:nil options:0 error:nil];
    self.bundles = [[NSMutableDictionary alloc] init];
    for(NSURL *uuidURL in uuidURLs)
    {
        MIExecutableBundle *bundle = [[PrivClass(MIExecutableBundle) alloc] initWithBundleInDirectory:uuidURL withExtension:@"app" error:nil];
        if(bundle)
            [self.bundles setObject:bundle forKey:bundle.identifier];
        else
            [[NSFileManager defaultManager] removeItemAtURL:uuidURL error:nil];
    }
    
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
- (BOOL)doWeTrustThatBundle:(MIExecutableBundle*)bundle
{
    if(!bundle) return NO;
    else if(![bundle validateBundleMetadataWithError:nil]) return NO;
    else if(![bundle isAppTypeBundle]) return NO;
    else if(![bundle validateAppMetadataWithError:nil]) return NO;
    else if(![bundle isApplicableToCurrentOSVersionWithError:nil]) return NO;
    else if(![bundle isApplicableToCurrentDeviceFamilyWithError:nil]) return NO;
    else if(![bundle isApplicableToCurrentDeviceCapabilitiesWithError:nil]) return NO;
    
    // MARK: Validate certificate using LC`s CS Check
    if(!checkCodeSignature([[bundle.executableURL path] UTF8String])) return NO;
    
    return YES;
}

- (BOOL)installApplicationWithPayloadPath:(NSString*)payloadPath
{
    // Creating MIBundle of payload
    MIExecutableBundle *bundle = [[PrivClass(MIExecutableBundle) alloc] initWithBundleInDirectory:payloadPath withExtension:@"app" error:nil];
    
    // Check if bundle is valid for LDEApplicationWorkspace
    if(!bundle) return NO;
    else if(![self doWeTrustThatBundle:bundle]) return NO;
    
    // File manager
    NSFileManager *fileManager = [NSFileManager defaultManager];
    
    // Now generate installPath
    NSURL *installURL = nil;
    MIBundle *previousApplication = [self applicationBundleForBundleID:[bundle identifier]];
    if(previousApplication) {
        // It existed before, using old path
        installURL = previousApplication.bundleURL;
        [fileManager removeItemAtURL:installURL error:nil];
        previousApplication = nil;
    } else {
        // It didnt existed before, using new path
        installURL = [[self.applicationsURL URLByAppendingPathComponent:[[NSUUID UUID] UUIDString]] URLByAppendingPathComponent:[bundle relativePath]];
    }
    
    // Now installing at install location
    if(![fileManager createDirectoryAtURL:[installURL URLByDeletingLastPathComponent] withIntermediateDirectories:YES attributes:nil error:nil]) return NO;
    if(![fileManager moveItemAtURL:bundle.bundleURL toURL:installURL error:nil]) return NO;
    
    // If existed we add object
    [self.bundles setObject:[PrivClass(MIExecutableBundle) bundleForURL:installURL error:nil] forKey:bundle.identifier];
    
    return YES;
}

- (BOOL)deleteApplicationWithBundleID:(NSString *)bundleID
{
    MIBundle *previousApplication = [self applicationBundleForBundleID:bundleID];
    if(previousApplication)
    {
        NSURL *container = [self applicationContainerForBundleID:bundleID];
        [[NSFileManager defaultManager] removeItemAtURL:[[previousApplication bundleURL] URLByDeletingLastPathComponent] error:nil];
        [[NSFileManager defaultManager] removeItemAtURL:container error:nil];
        [self.bundles removeObjectForKey:bundleID];
        return YES;
    }
    return NO;
}

- (BOOL)applicationInstalledWithBundleID:(NSString*)bundleID
{
    return [self.bundles objectForKey:bundleID] ? YES : NO;
}

- (MIBundle*)applicationBundleForBundleID:(NSString *)bundleID
{
    return [self.bundles objectForKey:bundleID];
}

- (NSURL*)applicationContainerForBundleID:(NSString *)bundleID
{
    MIBundle *bundle = [self applicationBundleForBundleID:bundleID];
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

- (void)applicationInstalledWithBundleID:(NSString *)bundleID withReply:(void (^)(BOOL))reply {
    reply([[LDEApplicationWorkspaceInternal shared] applicationInstalledWithBundleID:bundleID]);
}

- (void)deleteApplicationWithBundleID:(NSString *)bundleID withReply:(void (^)(BOOL))reply {
    reply([[LDEApplicationWorkspaceInternal shared] deleteApplicationWithBundleID:bundleID]);
}

- (void)installApplicationWithArchiveObject:(ArchiveObject*)archiveObject withReply:(void (^)(BOOL))reply {
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSString *tempBundle = [archiveObject extractArchive];
    BOOL didInstall = [[LDEApplicationWorkspaceInternal shared] installApplicationWithPayloadPath:tempBundle];
    [fileManager removeItemAtPath:tempBundle error:nil];
    reply(didInstall);
}

- (void)applicationObjectForBundleID:(NSString *)bundleID withReply:(void (^)(LDEApplicationObject *))reply
{
    MIBundle *bundle = [[LDEApplicationWorkspaceInternal shared] applicationBundleForBundleID:bundleID];
    
    if(!bundle)
    {
        reply(nil);
        return;
    }
    
    reply([[LDEApplicationObject alloc] initWithBundle:bundle]);
}

- (void)applicationContainerForBundleID:(NSString*)bundleID withReply:(void (^)(NSURL*))reply
{
    reply([[LDEApplicationWorkspaceInternal shared] applicationContainerForBundleID:bundleID]);
}

- (void)allApplicationObjectsWithReply:(void (^)(LDEApplicationObjectArray *))reply {
    LDEApplicationWorkspaceInternal *workspace = [LDEApplicationWorkspaceInternal shared];
    NSMutableArray<LDEApplicationObject*> *objects = [NSMutableArray array];
    for (NSString *bundleID in workspace.bundles) {
        MIBundle *bundle = workspace.bundles[bundleID];
        if (bundle) {
            [objects addObject:[[LDEApplicationObject alloc] initWithBundle:bundle]];
        }
    }
    
    reply([[LDEApplicationObjectArray alloc] initWithApplicationObjects:[objects copy]]);
}

- (void)clearContainerForBundleID:(NSString *)bundleID withReply:(void (^)(BOOL))reply
{
    reply([[LDEApplicationWorkspaceInternal shared] clearContainerForBundleID:bundleID]);
}

- (void)fastpathUtility:(FileObject*)object withReply:(void (^)(NSString*,BOOL))reply;
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

@end

void ApplicationManagementDaemonEntry(void)
{
    ServiceServer *serviceServer = [[ServiceServer alloc] initWithClass:[LDEApplicationWorkspaceProxy class] withProtocol:@protocol(LDEApplicationWorkspaceProxyProtocol)];
    environment_proxy_set_endpoint_for_service_identifier([serviceServer getEndpointForConnection], @"com.cr4zy.installd");
    CFRunLoopRun();
}
