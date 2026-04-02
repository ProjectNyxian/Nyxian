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

#import <LindChain/Utils/Zip.h>

#ifndef MY_LIBARCHIVE_H
#define MY_LIBARCHIVE_H

#include <unistd.h>
#include <stddef.h>

typedef int64_t la_int64_t;
typedef struct archive archive;
typedef struct archive_entry archive_entry;

struct archive {};
struct archive_entry {};

// Flags
#define ARCHIVE_EXTRACT_TIME    1
#define ARCHIVE_EXTRACT_PERM    2
#define ARCHIVE_EXTRACT_ACL     4
#define ARCHIVE_EXTRACT_FFLAGS  8

#define ARCHIVE_OK 0

// Reader functions
archive* archive_read_new(void);
int archive_read_open_fd(struct archive *a, int fd, size_t block_size);
int archive_read_support_format_all(archive *a);
int archive_read_support_filter_all(archive *a);
int archive_read_open_filename(archive *a, const char *filename, size_t block_size);
int archive_read_next_header(archive *a, archive_entry **entry);
int archive_read_data_block(archive *a, const void **buff, size_t *size, long long *offset);
int archive_read_close(archive *a);
int archive_read_free(archive *a);

// Writer functions
archive* archive_write_disk_new(void);
int archive_write_open_filename(struct archive *a, const char *filename);
ssize_t archive_write_data(struct archive *a, const void *buff, size_t size);
int archive_write_disk_set_options(archive *a, int flags);
int archive_write_header(archive *a, archive_entry *entry);
int archive_write_data_block(archive *a, const void *buff, size_t size, long long offset);
int archive_write_close(archive *a);
int archive_write_free(archive *a);
archive* archive_write_new(void);
int archive_write_set_format_zip(struct archive *a);

// Entry functions
const char* archive_entry_pathname(archive_entry *entry);
void archive_entry_set_pathname(archive_entry *entry, const char *pathname);
void archive_entry_set_size(struct archive_entry *entry, la_int64_t size);
void archive_entry_set_filetype(struct archive_entry *entry, unsigned int filetype);
void archive_entry_set_perm(struct archive_entry *entry, int perm);
void archive_entry_free(struct archive_entry *entry);
struct archive_entry *archive_entry_new(void);

// Error functions
const char* archive_error_string(archive *a);

#ifndef AE_IFREG
#define AE_IFREG 0100000  // regular file
#endif
#ifndef AE_IFDIR
#define AE_IFDIR 0040000  // directory
#endif

#endif // MY_LIBARCHIVE_H

BOOL unzipArchiveAtPath(NSString *zipPath, NSString *destinationPath) {
    struct archive *a;
    struct archive *ext;
    struct archive_entry *entry;
    int r;

    a = archive_read_new();
    archive_read_support_format_all(a);
    archive_read_support_filter_all(a);

    ext = archive_write_disk_new();
    archive_write_disk_set_options(ext, ARCHIVE_EXTRACT_TIME | ARCHIVE_EXTRACT_ACL | ARCHIVE_EXTRACT_FFLAGS);

    if ((r = archive_read_open_filename(a, [zipPath fileSystemRepresentation], 10240))) {
        NSLog(@"archive_read_open_filename() failed: %s", archive_error_string(a));
        archive_read_free(a);
        archive_write_free(ext);
        return NO;
    }

    while ((r = archive_read_next_header(a, &entry)) == ARCHIVE_OK) {
        NSString *fullPath = [destinationPath stringByAppendingPathComponent:
                              [NSString stringWithUTF8String:archive_entry_pathname(entry)]];
        archive_entry_set_pathname(entry, [fullPath fileSystemRepresentation]);
        archive_entry_set_perm(entry, 0777);
        r = archive_write_header(ext, entry);
        if (r == ARCHIVE_OK) {
            const void *buff;
            size_t size;
            la_int64_t offset;
            while (archive_read_data_block(a, &buff, &size, &offset) == ARCHIVE_OK) {
                archive_write_data_block(ext, buff, size, offset);
            }
        }
    }

    archive_read_close(a);
    archive_read_free(a);
    archive_write_close(ext);
    archive_write_free(ext);
    return YES;
}

BOOL unzipArchiveFromFileDescriptor(int fd, NSString *destinationPath) {
    struct archive *a;
    struct archive *ext;
    struct archive_entry *entry;
    int r;

    a = archive_read_new();
    archive_read_support_format_all(a);
    archive_read_support_filter_all(a);

    ext = archive_write_disk_new();
    archive_write_disk_set_options(ext, ARCHIVE_EXTRACT_TIME | ARCHIVE_EXTRACT_ACL | ARCHIVE_EXTRACT_FFLAGS);

    // Open archive from file descriptor
    if ((r = archive_read_open_fd(a, fd, 10240))) { // block size = 10240
        NSLog(@"archive_read_open_fd() failed: %s", archive_error_string(a));
        archive_read_free(a);
        archive_write_free(ext);
        return NO;
    }

    while ((r = archive_read_next_header(a, &entry)) == ARCHIVE_OK) {
        NSString *fullPath = [destinationPath stringByAppendingPathComponent:
                              [NSString stringWithUTF8String:archive_entry_pathname(entry)]];
        archive_entry_set_pathname(entry, [fullPath fileSystemRepresentation]);
        archive_entry_set_perm(entry, 0777);
        r = archive_write_header(ext, entry);
        if (r == ARCHIVE_OK) {
            const void *buff;
            size_t size;
            la_int64_t offset;
            while (archive_read_data_block(a, &buff, &size, &offset) == ARCHIVE_OK) {
                archive_write_data_block(ext, buff, size, offset);
            }
        }
    }

    archive_read_close(a);
    archive_read_free(a);
    archive_write_close(ext);
    archive_write_free(ext);
    return YES;
}

BOOL unzipArchiveFromFileHandle(NSFileHandle *zipFileHandle, NSString *destinationPath) {
    return unzipArchiveFromFileDescriptor(zipFileHandle.fileDescriptor, destinationPath);
}

BOOL zipDirectoryAtPath(NSString *directoryPath, NSString *zipPath, BOOL keepParent) {
    struct archive *a;
    struct archive_entry *entry;
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSDirectoryEnumerator *enumerator;
    NSString *filePath;

    // Determine base path for archive entries
    NSString *basePath = keepParent ? [directoryPath stringByDeletingLastPathComponent] : directoryPath;

    // Create new archive for writing
    a = archive_write_new();
    archive_write_set_format_zip(a); // Set format to ZIP

    // Open archive for writing to filename
    if (archive_write_open_filename(a, [zipPath fileSystemRepresentation]) != ARCHIVE_OK) {
        NSLog(@"Failed to create archive: %s", archive_error_string(a));
        archive_write_free(a);
        return NO;
    }

    // Enumerate all files
    enumerator = [fileManager enumeratorAtPath:directoryPath];
    while ((filePath = [enumerator nextObject])) {
        NSString *fullPath = [directoryPath stringByAppendingPathComponent:filePath];
        BOOL isDir;
        if ([fileManager fileExistsAtPath:fullPath isDirectory:&isDir]) {
            entry = archive_entry_new();

            // Determine the path inside the archive
            NSString *relativePath = [fullPath stringByReplacingOccurrencesOfString:basePath
                                                                       withString:@""];
            // Remove leading slash if any
            if ([relativePath hasPrefix:@"/"] || [relativePath hasPrefix:@"."]) {
                relativePath = [relativePath substringFromIndex:1];
            }

            archive_entry_set_pathname(entry, [relativePath UTF8String]);

            NSDictionary *attributes = [fileManager attributesOfItemAtPath:fullPath error:nil];
            archive_entry_set_size(entry, isDir ? 0 : [attributes[NSFileSize] longLongValue]);
            archive_entry_set_filetype(entry, isDir ? AE_IFDIR : AE_IFREG);
            archive_entry_set_perm(entry, [attributes[NSFilePosixPermissions] intValue]);

            // Write header
            if (archive_write_header(a, entry) == ARCHIVE_OK && !isDir) {
                NSData *data = [NSData dataWithContentsOfFile:fullPath];
                archive_write_data(a, [data bytes], [data length]);
            }

            archive_entry_free(entry);
        }
    }

    archive_write_close(a);
    archive_write_free(a);
    return YES;
}
