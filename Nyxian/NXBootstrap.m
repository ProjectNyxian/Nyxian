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

#import <NXBootstrap.h>
#import <UI/XCodeButton.h>
#import <LindChain/Utils/LDEThreadController.h>
#import <LindChain/Utils/Zip.h>
#import <LindChain/Downloader/fdownload.h>
#import <LindChain/ProcEnvironment/Surface/extra/relax.h>
#import <Nyxian-Swift.h>

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
#if !JAILBREAK_ENV
        _rootURL = [NSURL fileURLWithPath:[[@"/private" stringByAppendingPathComponent:NSHomeDirectory()] stringByAppendingPathComponent:@"/Documents"]];
#else
        _rootURL = [NSURL fileURLWithPath:[[@"/private" stringByAppendingPathComponent:NSHomeDirectory()] stringByAppendingPathComponent:@"/Documents/com.cr4zy.nyxian.root"]];
#endif /* !JAILBREAK_ENV */
    });
    return _rootURL;
}

- (NSURL*)sdkURL
{
    return [self.rootURL URLByAppendingPathComponent:@"/SDK/iPhoneOS26.4.sdk"];
}

- (NSURL*)includeURL
{
    return [self.rootURL URLByAppendingPathComponent:@"/Include"];
}

- (NSURL*)projectsURL
{
    return [self.rootURL URLByAppendingPathComponent:@"/Projects"];
}

- (NSURL*)cacheURL
{
    return [self.rootURL URLByAppendingPathComponent:@"/Cache"];
}

- (NSURL*)bootstrapPlistURL
{
    return [self.rootURL URLByAppendingPathComponent:@"/bootstrap.plist"];
}

- (NSURL*)swiftURL
{
    return [self.rootURL URLByAppendingPathComponent:@"/swift"];
}

- (NSURL*)swiftModuleCacheURL
{
    return [self.rootURL URLByAppendingPathComponent:@"/ModuleCache"];
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
    
    LDEPthreadDispatch(^{
        NSError *error = nil;
        
        goto skip_error_report;
        
    report_error:
        {
            NSLog(@"bootstrapping sadly failed :c");
            [NotificationServer NotifyUserWithLevel:NotifLevelError notification:[NSString stringWithFormat:@"Bootstrapping failed: %@", error.localizedDescription] delay:1.0];
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
                
                if(!unzipArchiveAtPath([NSBundle.mainBundle.bundleURL URLByAppendingPathComponent:@"/Shared/lib.zip"].path, self.rootURL.path))
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
            
            if(self.version < 21)
            {
                /*
                 * the SDK is very important to use iOS API which
                 * is very cool.
                 */
                NSLog(@"bootstrapping SDK");
                [[NSFileManager defaultManager] removeItemAtURL:[self.rootURL URLByAppendingPathComponent:@"SDK"] error:nil];
                [[NSFileManager defaultManager] removeItemAtURL:self.swiftModuleCacheURL error:nil];    /* clearing module cache */
                
                if(!fdownload(@"https://nyxian.app/bootstrap/iPhoneOS26.4.sdk.zip", @"sdk.zip"))
                {
                    error = [NSError errorWithDomain:@"" code:0 userInfo:@{ NSLocalizedDescriptionKey: @"downloading \"https://nyxian.app/bootstrap/iPhoneOS26.4.sdk.zip\" failed" }];
                    goto report_error;
                }
                
                if(!unzipArchiveAtPath([NSTemporaryDirectory() stringByAppendingPathComponent:@"sdk.zip"], [self.rootURL URLByAppendingPathComponent:@"SDK"].path))
                {
                    error = [NSError errorWithDomain:@"" code:0 userInfo:@{ NSLocalizedDescriptionKey: @"extracting \"sdl.zip\" failed" }];
                    goto report_error;
                }
                
                NSArray<NSURL*> *symlinkSDKs = @[
                    [self.rootURL URLByAppendingPathComponent:@"/SDK/iPhoneOS26.2.sdk"],
                    [self.rootURL URLByAppendingPathComponent:@"/SDK/iPhoneOS26.4.1.sdk"]
                ];
                
                for(NSURL *symlink in symlinkSDKs)
                {
                    if(![[NSFileManager defaultManager] createSymbolicLinkAtURL:symlink withDestinationURL:self.sdkURL error:&error])
                    {
                        goto report_error;
                    }
                }
                
                self.version = 21;
            }
            
            if(self.version < 22)
            {
                /*
                 * this is necessary so simd and normal
                 * c code work perfectly.
                 */
                NSLog(@"bootstrapping clang include and swift resources");
                [[NSFileManager defaultManager] removeItemAtURL:self.includeURL error:nil];
                [[NSFileManager defaultManager] removeItemAtURL:self.swiftURL error:nil];
                
                if(!unzipArchiveAtPath([NSBundle.mainBundle.bundleURL URLByAppendingPathComponent:@"/Shared/include.zip"].path, [self.rootURL URLByAppendingPathComponent:@"Include"].path))
                {
                    error = [NSError errorWithDomain:@"" code:0 userInfo:@{ NSLocalizedDescriptionKey: @"extracting \"include.zip\" failed" }];
                    goto report_error;
                }
                
                /*
                 * this is necessary so swift works
                 */
                if(!unzipArchiveAtPath([NSBundle.mainBundle.bundleURL URLByAppendingPathComponent:@"/Shared/swift.zip"].path, self.rootURL.path))
                {
                    error = [NSError errorWithDomain:@"" code:0 userInfo:@{ NSLocalizedDescriptionKey: @"extracting \"swift.zip\" failed" }];
                    goto report_error;
                }
                
                self.version = 22;
            }
        }
        
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
        if(!(url == self.rootURL && [entry.lastPathComponent isEqualToString:@"Projects"]))
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

- (BOOL)isNewest
{
    return self.version == NXBOOTSTRAP_NEWEST_VERSION;
}

@end
