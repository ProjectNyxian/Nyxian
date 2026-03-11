#import "LCUtils.h"
#import <LindChain/LiveContainer/LCMachOUtils.h>
#import "ZSign/zsigner.h"
#import "FoundationPrivate.h"
#import <Security/Security.h>
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>
#import <dlfcn.h>

extern NSUserDefaults *lcUserDefaults;

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

