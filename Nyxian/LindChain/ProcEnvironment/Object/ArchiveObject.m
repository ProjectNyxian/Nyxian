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

#import <LindChain/ProcEnvironment/Object/ArchiveObject.h>
#import <LindChain/Utils/Zip.h>

@implementation ArchiveObject

+ (instancetype)objectForDirectoryAtPath:(NSString*)path
{
    NSString *temporaryZipArchivePath = [NSTemporaryDirectory() stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.zip", [[NSUUID UUID] UUIDString]]];
    
    if(!zipDirectoryAtPath(path, temporaryZipArchivePath, YES))
    {
        return nil;
    }
    
    ArchiveObject *archiveObject = [self objectForFileAtPath:temporaryZipArchivePath];
    
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

- (void)deinit
{
    [super deinit];
    if(_temporaryZipArchivePath)
    {
        [[NSFileManager defaultManager] removeItemAtPath:_temporaryZipArchivePath error:nil];
    }
}

@end
