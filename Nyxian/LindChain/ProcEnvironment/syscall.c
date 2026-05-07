/*
 SPDX-License-Identifier: AGPL-3.0-or-later

 Copyright (C) 2025 - 2026 mach-port-t

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

#import <LindChain/ProcEnvironment/Syscall/mach_syscall_client.h>
#import <LindChain/ProcEnvironment/syscall.h>
#import <LindChain/Private/mach/fileport.h>
#import <errno.h>
#import <stdarg.h>

extern syscall_client_t *syscallProxy;

enum kESysType {
    kESysTypeNum = 0,
    kESysTypePortIn = 1,
    kESysTypePortOut = 2,
    kESysTypeRecvPortIn = 3,
    kESysTypeFDIn = 4,
    kESysTypeFileIn = 5,
};

typedef struct {
    uint32_t syscall_num;
    enum kESysType type[6];
} env_sys_entry_t;

/* macro to make our lives easier */
#define SYS_ENTRY(num, t0, t1, t2, t3, t4, t5) { .syscall_num = (num), .type = { (t0), (t1), (t2), (t3), (t4), (t5) } }

/* internal definitions of kESysType */
#define T_NUM       kESysTypeNum
#define T_PIN       kESysTypePortIn
#define T_POUT      kESysTypePortOut
#define T_RPIN      kESysTypeRecvPortIn
#define T_FIN       kESysTypeFDIn
#define T_FILEIN    kESysTypeFileIn

env_sys_entry_t sys_env_entries[] = {
    SYS_ENTRY(SYS_gettask,     T_NUM,       T_NUM,  T_POUT, T_NUM, T_NUM,  T_NUM),
    SYS_ENTRY(SYS_handoffep,   T_RPIN,      T_NUM,  T_NUM,  T_NUM, T_NUM,  T_NUM),
    SYS_ENTRY(SYS_ioctl,       T_FIN,       T_NUM,  T_NUM,  T_NUM, T_NUM,  T_NUM),
    SYS_ENTRY(SYS_pectl,       T_NUM,       T_NUM,  T_PIN,  T_POUT, T_NUM, T_NUM)
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
    
    /* port shit */
    mach_port_t in_ports[6] = {};
    mach_port_t *out_ports[6] = {};
    uint32_t in_ports_cnt = 0;
    uint32_t out_ports_cnt = 0;
    mach_msg_type_name_t type = MACH_MSG_TYPE_COPY_SEND;
    
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
                case kESysTypePortIn:
                    in_ports[in_ports_cnt++] = (mach_port_t)val;
                    break;
                case kESysTypePortOut:
                    out_ports[out_ports_cnt++] = (mach_port_t *)val;
                    break;
                case kESysTypeRecvPortIn:
                    in_ports[in_ports_cnt++] = (mach_port_t)val;
                    type = MACH_MSG_TYPE_MOVE_RECEIVE;
                    break;
                case kESysTypeFDIn:
                {
                    fileport_t fileport = MACH_PORT_NULL;
                    if(fileport_makeport((int)val, &fileport) == 0)
                    {
                        in_ports[in_ports_cnt++] = fileport;
                    }
                    else
                    {
                        errno = EBADF;
                        return -1;
                    }
                    break;
                }
                case kESysTypeFileIn:
                {
                    const char *path = (char*)val;
                    
                    int fd = open(path, O_RDWR);
                    
                    if(fd < 0)
                    {
                        errno = EINVAL;
                        return -1;
                    }
                    
                    fileport_t fileport = MACH_PORT_NULL;
                    if(fileport_makeport(fd, &fileport) == 0)
                    {
                        in_ports[in_ports_cnt++] = fileport;
                    }
                    else
                    {
                        close(fd);
                        errno = EBADF;
                        return -1;
                    }
                    
                    close(fd);
                    break;
                }
                default:
                    break;
            }
        }
    }
    
    /* invoking syscall */
    return syscall_invoke(syscallProxy, syscall_num, sys_args, in_ports, in_ports_cnt, type, out_ports, out_ports_cnt);
}
