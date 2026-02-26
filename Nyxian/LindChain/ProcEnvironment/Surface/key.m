//
//  key.m
//  Nyxian
//
//  Created by FridaDEV on 26.02.26.
//

#import <LindChain/ProcEnvironment/Surface/key.h>
#import <Security/Security.h>
#import <Foundation/Foundation.h>

#define KEY_SERVICE @"com.nyxian.kernel-key"
#define KEY_ACCOUNT @"static-kernel-key"
#define KEY_LEN 32

static uint8_t static_key[KEY_LEN];

int store_kernel_key(const uint8_t *key,
                     size_t key_len)
{
    NSDictionary *deleteQuery = @{
        (__bridge id)kSecClass: (__bridge id)kSecClassGenericPassword,
        (__bridge id)kSecAttrService: KEY_SERVICE,
        (__bridge id)kSecAttrAccount: KEY_ACCOUNT,
    };
    SecItemDelete((__bridge CFDictionaryRef)deleteQuery);

    NSData *keyData = [NSData dataWithBytes:key length:key_len];

    NSDictionary *addQuery = @{
        (__bridge id)kSecClass: (__bridge id)kSecClassGenericPassword,
        (__bridge id)kSecAttrService: KEY_SERVICE,
        (__bridge id)kSecAttrAccount: KEY_ACCOUNT,
        (__bridge id)kSecValueData: keyData,
        (__bridge id)kSecAttrAccessible: (__bridge id)kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
    };

    OSStatus status = SecItemAdd((__bridge CFDictionaryRef)addQuery, NULL);
    if(status != errSecSuccess)
    {
        NSError *err = [NSError errorWithDomain:NSOSStatusErrorDomain code:status userInfo:nil];
        NSLog(@"store_kernel_key: SecItemAdd failed: %@", err);
        return -1;
    }
    return 0;
}

const uint8_t *get_static_kernel_key(void)
{
    static dispatch_once_t once;

    dispatch_once(&once, ^{
        NSDictionary *query = @{
            (__bridge id)kSecClass: (__bridge id)kSecClassGenericPassword,
            (__bridge id)kSecAttrService: KEY_SERVICE,
            (__bridge id)kSecAttrAccount: KEY_ACCOUNT,
            (__bridge id)kSecReturnData: @YES,
            (__bridge id)kSecMatchLimit: (__bridge id)kSecMatchLimitOne,
        };

        CFDataRef result = NULL;
        OSStatus status = SecItemCopyMatching((__bridge CFDictionaryRef)query, (CFTypeRef *)&result);

        if(status == errSecItemNotFound)
        {
            arc4random_buf(static_key, KEY_LEN);
            if(store_kernel_key(static_key, KEY_LEN) != 0)
            {
                NSLog(@"get_static_kernel_key: failed to persist generated key");
            }
            return;
        }

        if(status != errSecSuccess || !result)
        {
            NSError *err = [NSError errorWithDomain:NSOSStatusErrorDomain code:status userInfo:nil];
            NSLog(@"get_static_kernel_key: SecItemCopyMatching failed: %@", err);
            return;
        }

        NSData *keyData = (__bridge_transfer NSData *)result;
        if(keyData.length == KEY_LEN)
        {
            memcpy(static_key, keyData.bytes, KEY_LEN);
        }
        else
        {
            NSLog(@"get_static_kernel_key: unexpected key length %lu", (unsigned long)keyData.length);
        }
    });

    return static_key;
}
