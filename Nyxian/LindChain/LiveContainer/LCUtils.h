#import <Foundation/Foundation.h>
#import "LCMachOUtils.h"

void refreshFile(NSString* execPath);
int dyld_get_program_sdk_version(void);

@interface LCUtils : NSObject

+ (NSData *)certificateData;
+ (NSString *)certificatePassword;

+ (NSProgress *)signAppBundleWithZSign:(NSURL *)path completionHandler:(void (^)(BOOL success, NSError *error))completionHandler;
+ (NSString*)getCertTeamIdWithKeyData:(NSData*)keyData password:(NSString*)password;
+ (int)validateCertificateWithCompletionHandler:(void(^)(int status, NSDate *expirationDate, NSString *error))completionHandler;

+ (NSString *)teamIdentifier;
+ (NSString *)appGroupID;

@end
