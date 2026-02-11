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

#ifndef KLOG_H
#define KLOG_H

#import <Foundation/Foundation.h>

#define KLOG_ENABLED 0

#if KLOG_ENABLED && !JAILBREAK_ENV

#define klog_log(system, format, ...) \
    klog_log_internal((system), (format), ##__VA_ARGS__)

#else

// When disabled: nothing is evaluated, nothing is called, arguments not touched.
#define klog_log(system, format, ...)

#endif

void klog_log_internal(NSString *system, NSString *format, ...);
NSString *klog_dump(void);

#endif /* KLOG_H */
