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

#import <LindChain/ProcEnvironment/environment.h>
#import <ServiceKit/ServiceKit.h>
#import <LindChain/Services/trustd/LDETrustProxy.h>
#import <LindChain/Services/trustd/LDETrustProtocol.h>
#import <CommonCrypto/CommonCrypto.h>
#import <mach-o/loader.h>
#import <mach-o/fat.h>

bool checkCodeSignature(const char* path);

#define CSMAGIC_EMBEDDED_SIGNATURE 0xfade0cc0
#define CSMAGIC_CODEDIRECTORY      0xfade0c02
#define CSSLOT_CODEDIRECTORY       0

typedef struct __BlobIndex {
    uint32_t type;
    uint32_t offset;
} CS_BlobIndex;

typedef struct __SuperBlob {
    uint32_t magic;
    uint32_t length;
    uint32_t count;
    CS_BlobIndex index[];
} CS_SuperBlob;

typedef struct __CodeDirectory {
    uint32_t magic;
    uint32_t length;
    uint32_t version;
    uint32_t flags;
    uint32_t hashOffset;
    uint32_t identOffset;
    uint32_t nSpecialSlots;
    uint32_t nCodeSlots;
    uint32_t codeLimit;
    uint8_t  hashSize;
    uint8_t  hashType;
    uint8_t  platform;
    uint8_t  pageSize;
    uint32_t spare2;
    // v0x20200+
    uint32_t scatterOffset;
    uint32_t teamOffset;
    // v0x20300+
    uint32_t spare3;
    uint64_t codeLimit64;
    // v0x20400+
    uint64_t execSegBase;
    uint64_t execSegLimit;
    uint64_t execSegFlags;
} CS_CodeDirectory;

NSString *cdHashOfExecutableAtPath(NSString *path)
{
    NSData *data = [NSData dataWithContentsOfFile:path options:NSDataReadingMappedIfSafe error:nil];
    if(!data)
    {
        return nil;
    }
    
    const uint8_t *base = data.bytes;
    const uint8_t *machHeader = base;
    
    uint32_t magic = *(uint32_t *)base;
    if(magic == FAT_CIGAM ||
       magic == FAT_MAGIC ||
       magic == FAT_CIGAM_64 ||
       magic == FAT_MAGIC_64)
    {
        struct fat_header *fatHeader = (struct fat_header *)base;
        uint32_t nArches = OSSwapBigToHostInt32(fatHeader->nfat_arch);
        struct fat_arch *archs = (struct fat_arch *)(base + sizeof(struct fat_header));
        for(uint32_t i = 0; i < nArches; i++)
        {
            cpu_type_t cputype = OSSwapBigToHostInt32(archs[i].cputype);
            if(cputype == CPU_TYPE_ARM64)
            {
                machHeader = base + OSSwapBigToHostInt32(archs[i].offset);
                break;
            }
        }
    }
    
    BOOL is64 = (*(uint32_t *)machHeader == MH_MAGIC_64);
    uint32_t ncmds = is64 ? ((struct mach_header_64 *)machHeader)->ncmds : ((struct mach_header *)machHeader)->ncmds;
    
    const uint8_t *cmd = machHeader + (is64 ? sizeof(struct mach_header_64) : sizeof(struct mach_header));
    
    for(uint32_t i = 0; i < ncmds; i++)
    {
        struct load_command *lc = (struct load_command *)cmd;
        
        if(lc->cmd == LC_CODE_SIGNATURE)
        {
            struct linkedit_data_command *sigCmd = (struct linkedit_data_command *)cmd;
            
            CS_SuperBlob *superBlob = (CS_SuperBlob *)(machHeader + sigCmd->dataoff);
            if(OSSwapBigToHostInt32(superBlob->magic) != CSMAGIC_EMBEDDED_SIGNATURE)
            {
                return nil;
            }
            
            uint32_t count = OSSwapBigToHostInt32(superBlob->count);
            for(uint32_t j = 0; j < count; j++)
            {
                uint32_t type = OSSwapBigToHostInt32(superBlob->index[j].type);
                uint32_t offset = OSSwapBigToHostInt32(superBlob->index[j].offset);
                
                if(type == CSSLOT_CODEDIRECTORY)
                {
                    CS_CodeDirectory *cd = (CS_CodeDirectory *)((uint8_t *)superBlob + offset);
                    if(OSSwapBigToHostInt32(cd->magic) != CSMAGIC_CODEDIRECTORY)
                    {
                        return nil;
                    }
                    
                    uint32_t cdLength = OSSwapBigToHostInt32(cd->length);
                    uint8_t hashType = cd->hashType;
                    
                    // Hash the CodeDirectory itself → CDHash
                    unsigned char digest[CC_SHA256_DIGEST_LENGTH];
                    if(hashType == 2)
                    { // SHA256
                        CC_SHA256(cd, cdLength, digest);
                    }
                    else
                    { // SHA1 (legacy, hashType == 1)
                        CC_SHA1(cd, cdLength, digest);
                        // Only 20 bytes for SHA1
                        NSMutableString *hash = [NSMutableString stringWithCapacity:40];
                        for(int k = 0; k < CC_SHA1_DIGEST_LENGTH; k++)
                        {
                            [hash appendFormat:@"%02x", digest[k]];
                        }
                        return [hash copy];
                    }
                    
                    NSMutableString *hash = [NSMutableString stringWithCapacity:64];
                    for(int k = 0; k < CC_SHA256_DIGEST_LENGTH; k++)
                    {
                        [hash appendFormat:@"%02x", digest[k]];
                    }
                    return [hash copy];
                }
            }
        }
        cmd += lc->cmdsize;
    }
    return nil;
}

@implementation LDETrustProxy

- (void)getHashOfExecutableAtPath:(NSString*)path
                        withReply:(void (^)(NSString*))reply
{
    reply(cdHashOfExecutableAtPath(path));
}

- (void)executableAllowedToExecutedAtPath:(NSString*)path
                                withReply:(void (^)(BOOL))reply
{
    reply(checkCodeSignature([path UTF8String]));
}

+ (NSString *)servcieIdentifier {
    return @"com.cr4zy.trustd";
}

+ (Protocol*)serviceProtocol
{
    return @protocol(LDETrustProtocol);
}

+ (Protocol*)observerProtocol
{
    return nil;
}

- (void)clientDidConnectWithConnection:(NSXPCConnection*)client
{
    return;
}

@end
