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

#import <LindChain/ProcEnvironment/Surface/sys/compat/sendtask.h>
#import <LindChain/ProcEnvironment/tfp.h>
#import <LindChain/ProcEnvironment/tpod.h>

DEFINE_SYSCALL_HANDLER(sendtask)
{
    /* null pointer and n check */
    if(in_ports == NULL ||
       in_ports_cnt != 1)
    {
        printf("in port arr empty\n");
        *err = EINVAL;
        return -1;
    }
    
    /* check if tpo is supported */
    if(!environment_supports_tfp())
    {
        *err = EPERM;
        return -1;
    }
    
    printf("port: %d\n", in_ports[0]);
    
    /* adding to tpo if it not already exist */
    add_tpo([[TaskPortObject alloc] initWithPort:in_ports[0]]);
    
    /* return with succession */
    return 0;
}
