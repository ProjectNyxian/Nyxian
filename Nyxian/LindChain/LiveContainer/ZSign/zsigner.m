//
//  zsigner.m
//  LiveContainer
//
//  Created by s s on 2024/11/10.
//

#import "zsigner.h"
#import "zsign.hpp"

NSProgress* currentZSignProgress;

@implementation ZSigner
+ (NSProgress*)signWithAppPath:(NSString *)appPath prov:(NSData *)prov key:(NSData *)key pass:(NSString *)pass
             completionHandler:(void (^)(BOOL success, NSError *error))completionHandler {
    NSProgress* ans = [NSProgress progressWithTotalUnitCount:1000];
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            zsign(appPath, prov, key, pass, ans, completionHandler);
        });
    return ans;
}

+ (BOOL)adhocSignMachOAtPath:(NSString *)path bundleId:(NSString*)bundleId entitlementData:(NSData *)entitlementData {
    return adhocSignMachO(path, bundleId, entitlementData);
}

+ (BOOL)signMachOAtPath:(NSString *)path prov:(NSData *)prov key:(NSData *)key pass:(NSString *)pass
{
    return zsignMachO(path, prov, key, pass);
}

// this method is used to get teamId for ADP/Enterprise certs ,don't use it in normal jitless
+ (NSString*)getTeamIdWithProv:(NSData *)prov key:(NSData *)key pass:(NSString *)pass {
    return getTeamId(prov, key, pass);
}

+ (int)checkCertWithProv:(NSData *)prov key:(NSData *)key pass:(NSString *)pass completionHandler:(void(^)(int status, NSDate* expirationDate, NSString *error))completionHandler {
    return checkCert(prov, key, pass, completionHandler);
}
@end

const char *getExecutablePath(void)
{
    return [[[NSBundle mainBundle] executablePath] UTF8String];
}

const char *getBundleIdentifier(void)
{
    return [[[NSBundle mainBundle] bundleIdentifier] UTF8String];
}
