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

#include <stdlib.h>
#include <stdarg.h>
#include <LindChain/ProcEnvironment/panic.h>
#import <Foundation/Foundation.h>
#import <LindChain/ProcEnvironment/Utils/klog.h>

void environment_panic_internal(const char *reason,
                                const char *file,
                                int line,
                                ...)
{
#if DEBUG
    /* starting variadic parse */
    va_list args;
    va_start(args, line);
    
    /* handing all the parsing work to apple */
    NSString *msg = [[NSString alloc] initWithFormat:[NSString stringWithCString:reason encoding:NSUTF8StringEncoding] arguments:args];
    
    /* ending parse */
    va_end(args);
    
    klog_log("ksurface:panic", "\npanic string: %s\nfile: %s\nline: %d", [msg UTF8String], file, line);
#endif /* DEBUG */
    
    /* trap the system */
    __builtin_trap();
}
