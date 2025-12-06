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

#import <LindChain/ProcEnvironment/Syscall/mach_syscall_client.h>
#import <LindChain/ProcEnvironment/syscall.h>
#import <LindChain/ProcEnvironment/proxy.h>
#import <errno.h>
#import <stdarg.h>

int64_t environment_syscall(uint32_t syscall_num,
                            void *in_payload,
                            uint32_t in_len,
                            void *out_payload,
                            uint32_t *out_len,
                            ...)
{
    /* starting variadic argument parse */
    va_list args;
    va_start(args, out_len);
    
    /* parsing arguments */
    int64_t a1 = va_arg(args, int64_t);
    int64_t a2 = va_arg(args, int64_t);
    int64_t a3 = va_arg(args, int64_t);
    int64_t a4 = va_arg(args, int64_t);
    int64_t a5 = va_arg(args, int64_t);
    int64_t a6 = va_arg(args, int64_t);
    
    /* ending parse */
    va_end(args);
    
    /* building argument buffer */
    int64_t sys_args[6] = { a1, a2, a3, a4, a5, a6 };
    
    /* invoking syscall */
    return syscall_invoke(syscallProxy, syscall_num, sys_args, in_payload, in_len, out_payload, out_len);
}
