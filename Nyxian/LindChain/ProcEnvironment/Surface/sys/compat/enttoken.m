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

#import <LindChain/ProcEnvironment/Surface/sys/compat/enttoken.h>

DEFINE_SYSCALL_HANDLER(enttoken)
{
    sys_name("SYS_enttoken");
    
    /* prepare arguments */
    PEEntitlement entitlement = (PEEntitlement)args[0];
    int flag = (int)args[1];
    userspace_pointer_t token_ptr = (userspace_pointer_t)args[2];
    
    /* now switch */
    ksurface_ent_token_t token;
    
    switch(flag)
    {
        case ET_CREATE:
        {
            ksurface_return_t ksr = entitlement_token_generate_for_entitlement(sys_proc_copy_->proc, entitlement, &token);
            
            if(ksr != SURFACE_SUCCESS)
            {
                sys_return_failure(EPERM);
            }
            
            if(!mach_syscall_copy_out(task, sizeof(ksurface_ent_token_t), &token, token_ptr))
            {
                sys_return_failure(EFAULT);
            }
            
            break;
        }
        case ET_CONSUME:
        {
            ksurface_ent_token_t token;
            
            if(!mach_syscall_copy_in(task, sizeof(ksurface_ent_token_t), &token, token_ptr))
            {
                sys_return_failure(EFAULT);
            }
            
            ksurface_return_t ksr = entitlement_token_consume(sys_proc_copy_->proc, &token);
            
            if(ksr != SURFACE_SUCCESS)
            {
                sys_return_failure(EPERM);
            }
            
            break;
        }
        default:
            break;
    }
    
    sys_return;
}
