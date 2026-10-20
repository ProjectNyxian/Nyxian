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

#ifndef LIBKERN_KLOG_H
#define LIBKERN_KLOG_H

#if __OBJC__
#import <Foundation/Foundation.h>
#endif /* __OBJC__ */
#include <stdbool.h>

extern struct timespec g_process_start_time;
extern struct timespec g_process_start_time_sysctl;;

#if HOST_ENV

#define klog_log(system, format, ...) \
    klog_log_internal((system), (format), ##__VA_ARGS__)

#else

#define klog_log(system, format, ...)

#endif

bool klog_set_obfuscation(bool enabled);

void klog_log_internal(const char *system, const char *format, ...);

#if __OBJC__
NSString *klog_dump(void);
#endif /* __OBJC__ */

#endif /* LIBKERN_KLOG_H */
