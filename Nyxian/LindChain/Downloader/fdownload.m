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

#import <LindChain/Downloader/fdownload.h>

/**
 * @brief This function is for downloading files online
 *
 */
BOOL fdownload(NSString *urlString,
               NSString *destinationPath)
{
    // Prepare to download
    NSURL *url = [NSURL URLWithString:urlString];
    NSURLSession *session = [NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration] delegate:nil delegateQueue:nil];
    
    // The part where we download a file lol
    __block BOOL didDownload = NO;
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
    NSURLSessionDownloadTask *downloadTask = [session downloadTaskWithURL:url completionHandler:^(NSURL *location, NSURLResponse *response, NSError *error) {
        // Check if download was successful and if not we signal and we exit
        if(error)
        {
            dispatch_semaphore_signal(semaphore);
            return;
        }

        // Determine the destination path
        NSString *finalDestinationPath = destinationPath;
        if (![finalDestinationPath isAbsolutePath])
            finalDestinationPath = [NSTemporaryDirectory() stringByAppendingPathComponent:destinationPath];

        // Check if destination file already exists and remove it if it does
        if ([[NSFileManager defaultManager] fileExistsAtPath:finalDestinationPath])
            [[NSFileManager defaultManager] removeItemAtPath:finalDestinationPath error:NULL];
        
        // Move it to its destination in case it suceeds means that the file was sucessfully downloaded
        didDownload = [[NSFileManager defaultManager] moveItemAtURL:location toURL:[NSURL fileURLWithPath:finalDestinationPath] error:NULL];

        dispatch_semaphore_signal(semaphore);
    }];
    [downloadTask resume];

    // We wait till the download is done!
    dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
    
    return didDownload;
}
