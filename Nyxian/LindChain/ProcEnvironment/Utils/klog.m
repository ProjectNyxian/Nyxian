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

/* not the kfd exploit dummy >:3 */
static int kfd = -1;

#endif /* HOST_ENV */
#endif /* KLOG_ENABLED */

#if KLOG_ENABLED
#ifdef HOST_ENV

/* maximum lines klog can take */
static const NSUInteger KLOG_MAX_LINES = 500;

static void klog_truncate_if_needed(void)
{
    /* checking if kfd is valid */
    if(kfd == -1)
    {
        return;
    }
    
    /* synchronizing kfd */
    fsync(kfd);

    /* getting filesize */
    off_t size = lseek(kfd, 0, SEEK_END);
    
    /* checking validity of that file size */
    if(size <= 0)
    {
        return;
    }
    
    /* allocate buffer for file contents */
    char *buffer = malloc(size + 1);
    
    /* null pointer check */
    if(buffer == NULL)
    {
        return;
    }
    
    /* going to the start of the file */
    lseek(kfd, 0, SEEK_SET);
    
    /* reading the file */
    ssize_t n = read(kfd, buffer, size);
    
    /* how much did we read BSD huh?? >:3 */
    if(n <= 0)
    {
        /* ouww nooo :c */
        /* freeing buffer */
        free(buffer);
        return;
    }
    
    /* null terminating string */
    buffer[n] = '\0';
    
    /* getting content NSString */
    NSString *content = [[NSString alloc] initWithUTF8String:buffer];
    
    /* freeing buffer */
    free(buffer);

    /* split content into lines */
    NSArray<NSString *> *lines = [content componentsSeparatedByString:@"\n"];
    
    /* checking if maximum line count was reached */
    if(lines.count <= KLOG_MAX_LINES + 1)
    {
        /* apperently nothing to truncate */
        lseek(kfd, 0, SEEK_END);
        return;
    }

    /* getting new start */
    NSUInteger start = lines.count - 1 - KLOG_MAX_LINES;
    
    /* getting new last */
    NSArray *lastLines = [lines subarrayWithRange:NSMakeRange(start, KLOG_MAX_LINES)];

    /* rewrite new log with maximum amount of lines */
    NSString *rewritten = [[lastLines componentsJoinedByString:@"\n"] stringByAppendingString:@"\n"];
    const char *utf8 = [rewritten UTF8String];

    /* initially rewriting file */
    ftruncate(kfd, 0);
    lseek(kfd, 0, SEEK_SET);
    write(kfd, utf8, strlen(utf8));
    fsync(kfd);

    /* restoring position */
    lseek(kfd, 0, SEEK_END);
}

#endif /* HOST_ENV */
#endif /* KLOG_ENABLED */


void klog_log_internal(NSString *system, NSString *format, ...)
{
#if KLOG_ENABLED
#ifdef HOST_ENV
    
    /* only open klog once */
    static NSDateFormatter *df = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        /* opening ^^ */
        NSString *kfd_path = [NSString stringWithFormat:@"%@/Documents/klog.txt", NSHomeDirectory()];
        kfd = open([kfd_path UTF8String], O_RDWR | O_CREAT | O_TRUNC, 0777);
        
        df = [[NSDateFormatter alloc] init];
        df.locale = [NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];
        df.dateFormat = @"yyyy-MM-dd HH:mm:ss.SSS";
    });

    /* checking kfd */
    if(kfd == -1)
    {
        return;
    }
    
    /* starting variadic parse */
    va_list args;
    va_start(args, format);
    
    /* handing all the parsing work to apple */
    NSString *msg = [[NSString alloc] initWithFormat:format arguments:args];
    
    /* ending parse */
    va_end(args);

    /* now we need the date ^^ */
    NSString *ts = [df stringFromDate:[NSDate date]];

    /* final log string */
    NSString *final = [NSString stringWithFormat:@"[%@] [%@] %@\n", ts, system ?: @"(null)", msg ?: @"(null)"];

    /* getting constent c version of that string */
    const char *utf8 = [final UTF8String];
    size_t len = strlen(utf8);

    /* writing */
    ssize_t written = write(kfd, utf8, len);

    /* truncation if applicable */
    if(written == len)
    {
        klog_truncate_if_needed();
    }
    else
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
    
    /* checking kfd */
    if(kfd == -1)
    {
        return @"";
    }
    
    /* synchronizing kfd */
    fsync(kfd);

    /* seeking the end lol */
    off_t size = lseek(kfd, 0, SEEK_END);
    if(size <= 0)
    {
        /* fuck my life.. concrete string crash shit (mhm apple, I look at you) */
        lseek(kfd, 0, SEEK_SET);
        return @"";
    }

    /* allocating new buffer with the size we got */
    char *buffer = malloc(size + 1);
    if(!buffer)
    {
        /* fuck my life.. concrete string crash shit (mhm apple, I look at you) */
        lseek(kfd, 0, SEEK_SET);
        return @"";
    }

    /* going back to the beginning */
    lseek(kfd, 0, SEEK_SET);
    
    /* reading from file */
    ssize_t n = read(kfd, buffer, size);
    
    /* read check */
    if(n < 0)
    {
        /* fuck my life.. concrete string crash shit (mhm apple, I look at you) */
        free(buffer);
        return @"";
    }
    
    /* null terminating buffer */
    buffer[n] = '\0';

    /* final result */
    NSString *result = [[NSString alloc] initWithUTF8String:buffer];

    /* releasing buffer and return */
    free(buffer);
    return result;
#else
    return nil;
#endif /* HOST_ENV */
#else
    return nil;
#endif /* KLOG_ENABLED */
}
