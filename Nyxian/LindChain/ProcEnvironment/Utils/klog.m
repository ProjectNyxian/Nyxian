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

#import <LindChain/ProcEnvironment/Utils/klog.h>

#if KLOG_ENABLED
#ifdef HOST_ENV
static int kfd = -1;
#endif /* HOST_ENV */
#endif /* KLOG_ENABLED */

void klog_log_internal(NSString *system, NSString *format, ...)
{
#if KLOG_ENABLED
#ifdef HOST_ENV
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSString *kfd_path = [NSString stringWithFormat:@"%@/Documents/klog.txt", NSHomeDirectory()];
        kfd = open([kfd_path UTF8String], O_RDWR | O_CREAT | O_TRUNC, 0777);
    });
    
    if(kfd == -1)
    {
        return;
    }
    
    va_list args;
    va_start(args, format);
    NSString *msg = [[NSString alloc] initWithFormat:format arguments:args];
    va_end(args);
    NSDateFormatter *df = [[NSDateFormatter alloc] init];
    df.locale = [NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];
    df.dateFormat = @"yyyy-MM-dd HH:mm:ss.SSS";
    NSString *ts = [df stringFromDate:[NSDate date]];
    NSString *final = [NSString stringWithFormat:@"[%@] [%@] %@\n", ts, system ?: @"(null)", msg ?: @"(null)"];
    
    const char *utf8 = [final UTF8String];
    size_t len = strlen(utf8);
    
    ssize_t written = write(kfd, utf8, len);
    if(written != len)
    {
        fsync(kfd);
    }
#endif /* HOST_ENV */
#endif /* KLOG_ENABLED */
}

NSString *klog_dump(void)
{
#if KLOG_ENABLED
#ifdef HOST_ENV
    if(kfd == -1)
    {
        return @"";
    }
    
    fsync(kfd);
    
    off_t size = lseek(kfd, 0, SEEK_END);
    if(size <= 0)
    {
        lseek(kfd, 0, SEEK_SET);
        return @"";
    }
    
    char *buffer = malloc(size + 1);
    if(!buffer)
    {
        lseek(kfd, 0, SEEK_SET);
        return @"";
    }
    
    lseek(kfd, 0, SEEK_SET);
    ssize_t n = read(kfd, buffer, size);
    if(n < 0)
    {
        free(buffer);
        return @"";
    }
    buffer[n] = '\0';
    
    NSString *result = [[NSString alloc] initWithUTF8String:buffer];
    
    free(buffer);
    return result;
#else
    return nil;
#endif /* HOST_ENV */
#else
    return nil;
#endif /* KLOG_ENABLED */
}
