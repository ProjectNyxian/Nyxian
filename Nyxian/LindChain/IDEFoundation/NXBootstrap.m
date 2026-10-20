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

#import <LindChain/IDEFoundation/NXBootstrap.h>
#import <LindChain/IDEFoundation/NXAlertDiagnosticPresenter.h>
#import <LindChain/Utils/Zip.h>
#import <LindChain/Downloader/fdownload.h>
#import <LindChain/ProcEnvironment/Surface/libkern/relax.h>
#import <MobileDevelopmentKit/MDKThreadPool.h>
#import <LindChain/ProcEnvironment/Surface/trust/keychain.h>
#import <UI/XCodeButton.h>
#import <Nyxian-Swift.h>

extern BOOL PEURLIsContainedIn(NSURL *candidate, NSURL *root);

@interface NXBootstrap ()

@property (readwrite) UInt64 version;

@end

@implementation NXBootstrap {
    NSURL *_rootURL;
    dispatch_once_t _gatherRootURLOnce;
}

- (instancetype)init
{
    self = [super init];
    return self;
}

+ (instancetype)shared
{
    static NXBootstrap *bootstrapSingleton = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        bootstrapSingleton = [[NXBootstrap alloc] init];
    });
    return bootstrapSingleton;
}

- (NSURL*)rootURL
{
    dispatch_once(&_gatherRootURLOnce, ^{
        _rootURL = [NSURL fileURLWithPath:[[@"/private" stringByAppendingPathComponent:NSHomeDirectory()] stringByAppendingPathComponent:@"Documents"]];
    });
    return _rootURL;
}

- (NSURL*)sdkURL
{
    return [self.rootURL URLByAppendingPathComponent:@"SDK/iPhoneOS27.0.sdk"];
}

- (NSURL*)includeURL
{
    return [self.rootURL URLByAppendingPathComponent:@"Include"];
}

- (NSURL*)projectsURL
{
    return [self.rootURL URLByAppendingPathComponent:@"Projects"];
}

- (NSURL*)cacheURL
{
    return [self.rootURL URLByAppendingPathComponent:@"Cache"];
}

- (NSURL*)bootstrapPlistURL
{
    return [self.rootURL URLByAppendingPathComponent:@"bootstrap.plist"];
}

- (NSURL*)swiftURL
{
    return [self.rootURL URLByAppendingPathComponent:@"swift"];
}

- (NSURL*)swiftModuleCacheURL
{
    return [self.rootURL URLByAppendingPathComponent:@"ModuleCache"];
}

- (NSURL*)rootfsURL
{
    return [self.rootURL URLByAppendingPathComponent:@"rootfs"];
}

- (UInt64)version
{
    NSDictionary *bootstrapPlist = [NSDictionary dictionaryWithContentsOfURL:self.bootstrapPlistURL];
    if(bootstrapPlist == nil)
    {
        /* plist doesn't exist or is malformed? */
        return 0;
    }
    
    NSNumber *versionNumber = bootstrapPlist[@"BootstrapVersion"];
    if(![versionNumber isKindOfClass:NSNumber.class])
    {
        /* illegal object */
        return 0;
    }
    
    return [versionNumber unsignedLongValue];
}

- (void)setVersion:(UInt64)version
{
    [XCButton updateProgressWithValue:NXBOOTSTRAP_CSTEP * version];
    [@{ @"BootstrapVersion":[NSNumber numberWithUnsignedLong:version] } writeToURL:self.bootstrapPlistURL error:nil];
}

- (BOOL)isInstalled
{
    return self.version > 0;
}

- (void)bootstrap
{
    NSLog(@"checking upon nyxian bootstrap :3");
    
    MDKPthreadDispatch(^{
        NSError *error = nil;
        
        goto skip_error_report;
        
    report_error:
        {
            NSLog(@"bootstrapping sadly failed :c");
            
            [NXAlertDiagnosticPresenter notifyUserWithLevel:NXAlertDiagnosticPresenterLevelError withMessage:[NSString stringWithFormat:@"Bootstrapping failed: %@", error.localizedDescription] withDelay:1.0];
            self.version = 0;
            [self clearURL:self.rootURL];
            return;
        }
        
    skip_error_report:
        
        /*
         * checking weither we have to create the
         * bootstraps root path.
         */
        if(![[NSFileManager defaultManager] fileExistsAtPath:self.rootURL.path])
        {
            [[NSFileManager defaultManager] createDirectoryAtURL:self.rootURL withIntermediateDirectories:YES attributes:nil error:&error];
            if(error != nil)
            {
                abort();
            }
        }
        
        NSLog(@"install status: %d", self.isInstalled);
        NSLog(@"version: %llu", self.version);
        
        if(!self.isInstalled || self.version != NXBOOTSTRAP_NEWEST_VERSION)
        {
            /*
             * need to clear the entire path if its not installed
             * otherwise garbage might be in the container.
             * we also have to clear it in case a newer version
             * of the bootstrap is installed.
             */
            if(!self.isInstalled || self.version > NXBOOTSTRAP_NEWEST_VERSION)
            {
                NSLog(@"bootstrap might be too new or not installed, clearing");
                [self clearURL:self.rootURL];
            }
            
            /*
             * now installing or upgrading the bootstrap, this is the part
             * that has to work although nobody is going to use Nyxian today
             * lol.
             */
            if(self.version < 9)
            {
                /*
                 * creating bootstrap base structure
                 * all base folders n such, you name it.
                 */
                NSLog(@"bootstrapping directory structure");
                
                [[NSFileManager defaultManager] createDirectoryAtURL:self.projectsURL withIntermediateDirectories:NO attributes:nil error:&error];
                
                if(![[NSFileManager defaultManager] createDirectoryAtURL:self.cacheURL withIntermediateDirectories:NO attributes:nil error:&error])
                {
                    goto report_error;
                }
                
                self.version = 9;
            }
            
            if(self.version < 10)
            {
                /*
                 * this step is for the rt static library
                 * which is needed for availability checks
                 * using @available in objc for example.
                 */
                NSLog(@"bootstrapping libraries");
                [[NSFileManager defaultManager] removeItemAtURL:[self.rootURL URLByAppendingPathComponent:@"lib"] error:nil];
                
                if(!unzipArchiveAtPath([NSBundle.mainBundle.bundleURL URLByAppendingPathComponent:@"Shared/lib.zip"].path, self.rootURL.path))
                {
                    error = [NSError errorWithDomain:@"" code:0 userInfo:@{ NSLocalizedDescriptionKey: @"extracting \"lib.zip\" failed" }];
                    goto report_error;
                }
                
                self.version = 10;
            }
            
            if(self.version < 15)
            {
                /*
                 * there was a DOS vulnerability in a prior
                 * version of Nyxian where a zip could of caused
                 * DOS in project import functionality. so we
                 * have to fixup paths in case they were affected.
                 * as patching the DOS entry it self does not
                 * prevent it to still cause DOS as damage
                 * might already happened.
                 */
                NSURL *tmpUrl = [NSURL fileURLWithPath:NSTemporaryDirectory()];
                NSDirectoryEnumerator *enumerator = [[NSFileManager defaultManager] enumeratorAtURL:tmpUrl includingPropertiesForKeys:nil options:0 errorHandler:nil];
                if(enumerator == nil)
                {
                    error = [NSError errorWithDomain:@"" code:0 userInfo:@{ NSLocalizedDescriptionKey: @"failed to create enumerator" }];
                    goto report_error;
                }
                
                if(![[NSFileManager defaultManager] setAttributes:@{ NSFilePosixPermissions: @(0755) } ofItemAtPath:tmpUrl.path error:&error])
                {
                    goto report_error;
                }
                
                for(NSURL *fileURL in enumerator)
                {
                    BOOL isDirectory = NO;
                    if(![[NSFileManager defaultManager] fileExistsAtPath:fileURL.path isDirectory:&isDirectory])
                    {
                        continue;
                    }
                    
                    if(![[NSFileManager defaultManager] setAttributes:@{ NSFilePosixPermissions: isDirectory ? @(0755) : @(0644)} ofItemAtPath:fileURL.path error:&error])
                    {
                        goto report_error;
                    }
                }
                
                self.version = 15;
            }
            
            if(self.version < 23)
            {
                /*
                 * this is necessary so simd and normal
                 * c code work perfectly.
                 */
                NSLog(@"bootstrapping clang include and swift resources");
                [[NSFileManager defaultManager] removeItemAtURL:self.includeURL error:nil];
                [[NSFileManager defaultManager] removeItemAtURL:self.swiftURL error:nil];
                
                if(!unzipArchiveAtPath([NSBundle.mainBundle.bundleURL URLByAppendingPathComponent:@"Shared/include.zip"].path, [self.rootURL URLByAppendingPathComponent:@"Include"].path))
                {
                    error = [NSError errorWithDomain:@"" code:0 userInfo:@{ NSLocalizedDescriptionKey: @"extracting \"include.zip\" failed" }];
                    goto report_error;
                }
                
                /*
                 * this is necessary so swift works
                 */
                if(!unzipArchiveAtPath([NSBundle.mainBundle.bundleURL URLByAppendingPathComponent:@"Shared/swift.zip"].path, self.rootURL.path))
                {
                    error = [NSError errorWithDomain:@"" code:0 userInfo:@{ NSLocalizedDescriptionKey: @"extracting \"swift.zip\" failed" }];
                    goto report_error;
                }
                
                self.version = 23;
            }
            
            if(self.version < 28)
            {
                NSLog(@"bootstrapping rootca folder");
                
                [[NSFileManager defaultManager] createDirectoryAtURL:[self.rootURL URLByAppendingPathComponent:@"RootCAs"] withIntermediateDirectories:true attributes:nil error:nil];
                
                if(!fdownload(@"https://nyxian.app/bootstrap/org.emexlabs.rootca.v1.pub.nxt2c", @"org.emexlabs.rootca.v1.pub.nxt2c"))
                {
                    error = [NSError errorWithDomain:@"" code:0 userInfo:@{ NSLocalizedDescriptionKey: @"downloading \"https://nyxian.app/bootstrap/org.emexlabs.rootca.v1.pub.nxt2c\" failed" }];
                    goto report_error;
                }
                
                if(![[NSFileManager defaultManager] moveItemAtPath:[NSTemporaryDirectory() stringByAppendingPathComponent:@"org.emexlabs.rootca.v1.pub.nxt2c"] toPath:[[self.rootURL URLByAppendingPathComponent:@"RootCAs/org.emexlabs.rootca.v1.pub.nxt2c"] path] error:nil])
                {
                    error = [NSError errorWithDomain:@"" code:0 userInfo:@{ NSLocalizedDescriptionKey: @"failed to move emexlabs public rootca key" }];
                    goto report_error;
                }
                
                if(!NXApplicationState.extensionLessMode)
                {
                    ksurface_keychain_update();
                }
                
                self.version = 28;
            }
            
            if(self.version < 29)
            {
                /*
                 * the SDK is very important to use iOS API which
                 * is very cool.
                 */
                NSLog(@"bootstrapping SDK");
                [[NSFileManager defaultManager] removeItemAtURL:[self.rootURL URLByAppendingPathComponent:@"SDK"] error:nil];
                [[NSFileManager defaultManager] removeItemAtURL:self.swiftModuleCacheURL error:nil];    /* clearing module cache */
                
                if(!fdownload(@"https://nyxian.app/bootstrap/iPhoneOS27.0.sdk.zip", @"sdk.zip"))
                {
                    error = [NSError errorWithDomain:@"" code:0 userInfo:@{ NSLocalizedDescriptionKey: @"downloading \"https://nyxian.app/bootstrap/iPhoneOS27.0.sdk.zip\" failed" }];
                    goto report_error;
                }
                
                if(!unzipArchiveAtPath([NSTemporaryDirectory() stringByAppendingPathComponent:@"sdk.zip"], [self.rootURL URLByAppendingPathComponent:@"SDK"].path))
                {
                    error = [NSError errorWithDomain:@"" code:0 userInfo:@{ NSLocalizedDescriptionKey: @"extracting \"sdk.zip\" failed" }];
                    goto report_error;
                }
                
                NSArray<NSURL*> *symlinkSDKs = @[
                    [self.rootURL URLByAppendingPathComponent:@"/SDK/iPhoneOS26.2.sdk"],
                    [self.rootURL URLByAppendingPathComponent:@"/SDK/iPhoneOS26.4.1.sdk"],
                    [self.rootURL URLByAppendingPathComponent:@"/SDK/iPhoneOS26.4.sdk"],
                    [self.rootURL URLByAppendingPathComponent:@"/SDK/iPhoneOS26.5.sdk"],
                ];
                
                for(NSURL *symlink in symlinkSDKs)
                {
                    if(![[NSFileManager defaultManager] createSymbolicLinkAtPath:symlink.path withDestinationPath:self.sdkURL.lastPathComponent error:&error])
                    {
                        goto report_error;
                    }
                }
                
                self.version = 29;
            }
        }
        
        [[NSFileManager defaultManager] createDirectoryAtURL:self.swiftModuleCacheURL withIntermediateDirectories:NO attributes:nil error:nil];
        
        NSLog(@"done");
    });
}

- (NSString*)relativeToBootstrapWithAbsolutePath:(NSString*)path
{
    NSURL *absolutURL = [NSURL fileURLWithPath:path];
    if(![absolutURL.path hasPrefix:[self.rootURL.path stringByAppendingString:@"/"]] &&
       ![absolutURL.path isEqualToString:self.rootURL.path])
    {
        return nil;
    }
    return [absolutURL.path stringByReplacingOccurrencesOfString:[self.rootURL.path stringByAppendingString:@"/"] withString:@""];
}

- (void)clearURL:(NSURL*)url
{
    NSArray<NSURL*> *entries = [[NSFileManager defaultManager] contentsOfDirectoryAtURL:url includingPropertiesForKeys:nil options:0 error:nil];
    if(entries == nil)
    {
        return;
    }
    
    for(NSURL *entry in entries)
    {
        if(!(url == self.rootURL && ([entry.lastPathComponent isEqualToString:@"Projects"] ||
                                     [entry.lastPathComponent isEqualToString:@"rootfs"] ||
                                     [entry.lastPathComponent isEqualToString:@"mntfs"] ||
                                     [entry.lastPathComponent isEqualToString:@"kmsg.txt"] ||
                                     [entry.lastPathComponent isEqualToString:@"kmsg_old.txt"])))
        {
            [[NSFileManager defaultManager] removeItemAtURL:entry error:nil];
        }
    }
}

- (void)waitTillDone
{
    if(self.version == NXBOOTSTRAP_NEWEST_VERSION)
    {
        return;
    }
    
    [XCButton switchImageWithSystemName:@"archivebox.fill" animated:YES];
    [XCButton updateProgressWithValue:0.1];
    
    while(self.version != NXBOOTSTRAP_NEWEST_VERSION)
    {
        relax();
    }
    
    [XCButton switchImageWithSystemName:@"hammer.fill" animated:YES];
}

- (void)waitTillDoneNoButton
{
    if(self.version == NXBOOTSTRAP_NEWEST_VERSION)
    {
        return;
    }
    
    [XCButton switchImageWithSystemName:@"archivebox.fill" animated:YES];
    [XCButton updateProgressWithValue:0.1];
    
    while(self.version != NXBOOTSTRAP_NEWEST_VERSION)
    {
        relax();
    }
    
    [XCButton switchImageWithSystemName:@"hammer.fill" animated:YES];
}

- (BOOL)isNewest
{
    return self.version == NXBOOTSTRAP_NEWEST_VERSION;
}

@end
