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

enum kESysType {
    kESysTypeInLen = 0,
    kESysTypeOutLen = 1,
    kESysTypeIn = 2,
    kESysTypeOut = 3,
    kESysTypeNum = 4
};

typedef struct {
    uint32_t syscall_num;
    enum kESysType type[6];
} env_sys_entry_t;

env_sys_entry_t sys_env_entries[3] = {
    { .syscall_num = SYS_PROCTB, .type = { kESysTypeOut, kESysTypeOutLen, kESysTypeNum, kESysTypeNum, kESysTypeNum, kESysTypeNum }},
    { .syscall_num = SYS_GETHOSTNAME, .type = { kESysTypeOut, kESysTypeOutLen, kESysTypeNum, kESysTypeNum, kESysTypeNum, kESysTypeNum }},
    { .syscall_num = SYS_SETHOSTNAME, .type = { kESysTypeIn, kESysTypeInLen, kESysTypeNum, kESysTypeNum, kESysTypeNum, kESysTypeNum }}
};

int64_t environment_syscall(uint32_t syscall_num, ...)
{
    /* starting variadic argument parse */
    va_list args;
    va_start(args, syscall_num);
    
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
    
    /* variables for syscall invocation */
    void *in_payload = NULL;    /* input data */
    uint32_t in_len = 0;        /* input length */
    void *out_payload = NULL;   /* out data */
    uint32_t *out_len = NULL;   /* out length */
    
    /* decoding payloads if applicable */
    for(uint8_t i = 0; i < 3; i++)
    {
        /* no copy pointer access */
        env_sys_entry_t *entry = &(sys_env_entries[i]);
        
        /* matching entry */
        if(entry->syscall_num == syscall_num)
        {
            /* decoding!! */
            for(uint8_t a = 0; a < 6; a++)
            {
                switch(entry->type[a])
                {
                    case kESysTypeInLen:
                        in_len = (uint32_t)sys_args[a];
                        break;
                    case kESysTypeOutLen:
                        out_len = (void*)sys_args[a];
                        break;
                    case kESysTypeIn:
                        in_payload = (void*)sys_args[a];
                        break;
                    case kESysTypeOut:
                        out_payload = (void*)sys_args[a];
                        break;
                    default:
                        break;
                }
            }
            
            /* breaking */
            break;
        }
    }
    
    /* invoking syscall */
    return syscall_invoke(syscallProxy, syscall_num, sys_args, in_payload, in_len, out_payload, out_len);
}
