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
#import <LindChain/Private/mach/fileport.h>
#import <errno.h>
#import <stdarg.h>

enum kESysType {
    kESysTypeInLen = 0,
    kESysTypeOutLen = 1,
    kESysTypeIn = 2,
    kESysTypeOut = 3,
    kESysTypeNum = 4,
    kESysTypePortIn = 5,
    kESysTypePortOut = 6,
    kESysTypeFDIn = 7,
};

typedef struct {
    uint32_t syscall_num;
    enum kESysType type[6];
} env_sys_entry_t;

/* macro to make our lives easier */
#define SYS_ENTRY(num, t0, t1, t2, t3, t4, t5) { .syscall_num = (num), .type = { (t0), (t1), (t2), (t3), (t4), (t5) } }

/* internal definitions of kESysType */
#define T_NUM   kESysTypeNum
#define T_IN    kESysTypeIn
#define T_INLEN kESysTypeInLen
#define T_OUT   kESysTypeOut
#define T_OLEN  kESysTypeOutLen
#define T_PIN   kESysTypePortIn
#define T_POUT  kESysTypePortOut
#define T_FIN   kESysTypeFDIn

env_sys_entry_t sys_env_entries[] = {
    SYS_ENTRY(SYS_proctb,      T_OUT,  T_OLEN, T_NUM,  T_NUM, T_NUM, T_NUM),
    SYS_ENTRY(SYS_gethostname, T_OUT,  T_OLEN, T_NUM,  T_NUM, T_NUM, T_NUM),
    SYS_ENTRY(SYS_sethostname, T_IN,   T_INLEN,T_NUM,  T_NUM, T_NUM, T_NUM),
    SYS_ENTRY(SYS_gettask,     T_NUM,  T_NUM,  T_POUT, T_NUM, T_NUM, T_NUM),
    SYS_ENTRY(SYS_sendtask,    T_PIN,  T_NUM,  T_NUM,  T_NUM, T_NUM, T_NUM),
    SYS_ENTRY(SYS_signexec,    T_FIN,  T_NUM,  T_NUM,  T_NUM, T_NUM, T_NUM),
    SYS_ENTRY(SYS_procpath,    T_NUM,  T_OUT,  T_OLEN, T_NUM, T_NUM, T_NUM),
    SYS_ENTRY(SYS_procbsd,     T_NUM,  T_OUT,  T_OLEN, T_NUM, T_NUM, T_NUM),
    SYS_ENTRY(SYS_handoffep,   T_PIN,  T_NUM,  T_NUM,  T_NUM, T_NUM, T_NUM)
};

/* also making our lives easier */
#define SYS_ENV_ENTRIES_N (sizeof(sys_env_entries) / sizeof(sys_env_entries[0]))

static const env_sys_entry_t *find_syscall_entry(uint32_t syscall_num)
{
    /* iterating through all syscall environment entries */
    for(size_t i = 0; i < SYS_ENV_ENTRIES_N; i++)
    {
        /* matching it */
        if(sys_env_entries[i].syscall_num == syscall_num)
        {
            /* returning it lol ^^*/
            return &sys_env_entries[i];
        }
    }
    return NULL;
}

int64_t environment_syscall(uint32_t syscall_num, ...)
{
    /* starting variadic argument parse */
    va_list args;
    va_start(args, syscall_num);
    
    /* parsing arguments */
    int64_t sys_args[6];
    for(uint8_t i = 0; i < 6; i++)
    {
        sys_args[i] = va_arg(args, int64_t);
    }
    
    /* ending parse */
    va_end(args);
    
    /* building argument buffer */
    
    /* port shit */
    mach_port_t in_ports[6] = {};
    mach_port_t *out_ports[6] = {};
    uint32_t in_ports_cnt = 0;
    uint32_t out_ports_cnt = 0;
    
    /* payload shit */
    void *in_payload = NULL;
    uint32_t in_len = 0;
    void *out_payload = NULL;
    uint32_t *out_len = NULL;
    
    /* decoding payloads if applicable */
    const env_sys_entry_t *entry = find_syscall_entry(syscall_num);
    
    /* null pointer check */
    if(entry != NULL)
    {
        /* iterating through systypes */
        for(int a = 0; a < 6; a++)
        {
            int64_t val = sys_args[a];
            
            /* decoding type for type */
            switch(entry->type[a])
            {
                case kESysTypeInLen:
                    in_len = (uint32_t)val;
                    break;
                case kESysTypeOutLen:
                    out_len = (uint32_t *)val;
                    break;
                case kESysTypeIn:
                    in_payload = (void *)val;
                    break;
                case kESysTypeOut:
                    out_payload = (void *)val;
                    break;
                case kESysTypePortIn:
                    in_ports[in_ports_cnt++] = (mach_port_t)val;
                    break;
                case kESysTypePortOut:
                    out_ports[out_ports_cnt++] = (mach_port_t *)val;
                    break;
                case kESysTypeFDIn:
                {
                    fileport_t fileport = MACH_PORT_NULL;
                    kern_return_t kr = fileport_makeport((int)val, &fileport);
                    if(kr == KERN_SUCCESS)
                    {
                        in_ports[in_ports_cnt++] = fileport;
                    }
                    break;
                }
                default:
                    break;
            }
        }
    }
    
    /* invoking syscall */
    return syscall_invoke(syscallProxy, syscall_num, sys_args, in_payload, in_len, out_payload, out_len, in_ports, in_ports_cnt, out_ports, out_ports_cnt);
}
