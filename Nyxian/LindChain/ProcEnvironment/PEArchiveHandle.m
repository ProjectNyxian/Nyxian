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

#import <LindChain/ProcEnvironment/PEArchiveHandle.h>
#import <LindChain/Utils/Zip.h>

@implementation PEArchiveHandle

+ (instancetype)objectForDirectoryAtPath:(NSString*)path
{
    NSString *temporaryZipArchivePath = [NSTemporaryDirectory() stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.zip", [[NSUUID UUID] UUIDString]]];
    
    if(!zipDirectoryAtPath(path, temporaryZipArchivePath, YES))
    {
        return nil;
    }
    
    PEArchiveHandle *archiveObject = [self handleForFileAtPath:temporaryZipArchivePath];
    if(archiveObject == nil)
    {
        [[NSFileManager defaultManager] removeItemAtPath:temporaryZipArchivePath error:nil];
        return nil;
    }
    
    archiveObject.temporaryZipArchivePath = temporaryZipArchivePath;
    
    return archiveObject;
}

- (NSString*)extractArchive
{
    int tmpfd = xpc_fd_dup(self.fd);
    if(tmpfd < 0)
    {
        return nil;
    }
    
    NSString *destinationPath = [NSTemporaryDirectory() stringByAppendingPathComponent:[NSString stringWithFormat:@"%@", [[NSUUID UUID] UUIDString]]];
    
    unzipArchiveFromFileDescriptor(tmpfd, destinationPath);
    
    close(tmpfd);
    
    return destinationPath;
}

- (void)dealloc
{
    if(_temporaryZipArchivePath)
    {
        [[NSFileManager defaultManager] removeItemAtPath:_temporaryZipArchivePath error:nil];
    }
}

@end
