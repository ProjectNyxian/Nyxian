/*
 SPDX-License-Identifier: AGPL-3.0-or-later

 Copyright (C) 2023 - 2026 LiveContainer
 Copyright (C) 2026 cr4zyengineer

 This file is part of LiveContainer.

 LiveContainer is free software: you can redistribute it and/or modify
 it under the terms of the GNU Affero General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.

 LiveContainer is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 GNU Affero General Public License for more details.

 You should have received a copy of the GNU Affero General Public License
 along with Nyxian. If not, see <https://www.gnu.org/licenses/>.
*/

#import <LindChain/LiveContainer/LCUtils.h>
#import <LindChain/LiveContainer/LCMachOUtils.h>
#import <LindChain/LiveContainer/ZSign/zsigner.h>
#import <LindChain/Private/FoundationPrivate.h>
#import <Security/Security.h>
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>
#import <dlfcn.h>

// make SFSafariView happy and open data: URLs
@implementation NSURL(hack)
- (BOOL)safari_isHTTPFamilyURL {
    // Screw it, Apple
    return YES;
}
@end

@implementation LCUtils

#pragma mark Certificate & password

+ (NSData *)certificateData
{
    return [NSUserDefaults.standardUserDefaults objectForKey:@"LCCertificateData"];
}

+ (NSString *)certificatePassword
{
    return [NSUserDefaults.standardUserDefaults objectForKey:@"LCCertificatePassword"];
}

#pragma mark Code signing

+ (NSProgress *)signAppBundleWithZSign:(NSURL *)path
                     completionHandler:(void (^)(BOOL success, NSError *error))completionHandler
{
    __block NSError *error = nil;
    
    /* trying to make a new NSBundle for the bundle at path */
    NSBundle *bundle = [NSBundle bundleWithURL:path];
    
    if(bundle == nil)
    {
        /* TODO: craft a error */
        completionHandler(NO, error);
    }
    
    /* patching executable slice if necessary */
    NSString *errorStr = LCParseMachO(bundle.executablePath.UTF8String, false, ^(const char *path, struct mach_header_64 *header, int fd, void* filePtr){
        if(header->cputype != CPU_TYPE_ARM64 ||
           LCPatchExecSlice(path, header, YES) != 0)
        {
            error = [NSError errorWithDomain:@"com.nyxian.lcutils" code:0 userInfo:@{ NSLocalizedDescriptionKey: @"unsupported executable format" } ];
        }
    });
    
    if(errorStr)
    {
        error = [NSError errorWithDomain:@"com.nyxian.lcutils" code:0 userInfo:@{ NSLocalizedDescriptionKey: @"unsupported executable format" } ];
    }
    
    if(error)
    {
        completionHandler(NO, error);
        return nil;
    }
    
    /* patching arm64e things */
    LCPatchAppBundleFixupARM64eSlice(path);
    
    /* use zsign as our signer~ (yeah daddy tim, were using zsigner as our signer, am i a bad girl now ;3) */
    NSURL *profilePath = [NSBundle.mainBundle URLForResource:@"embedded" withExtension:@"mobileprovision"];
    NSData *profileData = [NSData dataWithContentsOfURL:profilePath];
    /* load libraries from Documents, yeah~ */
    
    return [NSClassFromString(@"ZSigner") signWithAppPath:[path path] prov:profileData key: self.certificateData pass:self.certificatePassword completionHandler:completionHandler];
}

+ (BOOL)signMachOAtURL:(NSURL *)url
{
    __block NSError *error = nil;
    
    /* patching executable slice if necessary */
    NSString *errorStr = LCParseMachO(url.path.UTF8String, false, ^(const char *path, struct mach_header_64 *header, int fd, void* filePtr){
        if(header->cputype != CPU_TYPE_ARM64 ||
           LCPatchExecSlice(path, header, YES) != 0)
        {
            error = [NSError errorWithDomain:@"com.nyxian.lcutils" code:0 userInfo:@{ NSLocalizedDescriptionKey: @"unsupported executable format" } ];
        }
    });
    
    if(errorStr)
    {
        error = [NSError errorWithDomain:@"com.nyxian.lcutils" code:0 userInfo:@{ NSLocalizedDescriptionKey: @"unsupported executable format" } ];
    }
    
    if(error)
    {
        return NO;
    }
    
    /* use zsign as our signer~ (yeah daddy tim, were using zsigner as our signer, am i a bad girl now ;3) */
    NSURL *profilePath = [NSBundle.mainBundle URLForResource:@"embedded" withExtension:@"mobileprovision"];
    NSData *profileData = [NSData dataWithContentsOfURL:profilePath];
    /* load libraries from Documents, yeah~ */
    
    return [ZSigner signMachOAtPath:url.path prov:profileData key:self.certificateData pass:self.certificatePassword];
}

+ (int)validateCertificateWithCompletionHandler:(void(^)(int status, NSDate *expirationDate, NSString *error))completionHandler
{
    NSError *error;
    NSURL *profilePath = [NSBundle.mainBundle URLForResource:@"embedded" withExtension:@"mobileprovision"];
    NSData *profileData = [NSData dataWithContentsOfURL:profilePath];
    NSData *certData = [LCUtils certificateData];
    if (error) {
        return -6;
    }
    int ans = [NSClassFromString(@"ZSigner") checkCertWithProv:profileData key:certData pass:[LCUtils certificatePassword] completionHandler:completionHandler];
    return ans;
}

@end

