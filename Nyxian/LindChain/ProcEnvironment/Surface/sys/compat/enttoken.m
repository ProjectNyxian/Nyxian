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
    /* prepare arguments */
    PEEntitlement entitlement = (PEEntitlement)args[0];
    int flag = (int)args[1];
    userspace_pointer_t token_ptr = (userspace_pointer_t)args[2];
    
    /* copy token/mach in if applicable */
    ksurface_ent_mach_t mach;
    
    if(flag != ET_CREATE)
    {
        bool succeed = false;
        
        switch(flag)
        {
            case ET_VERIFY_MACH:
                succeed = mach_syscall_copy_in(sys_task_, sizeof(ksurface_ent_mach_t), &mach, token_ptr);
                break;
            default:
                succeed = mach_syscall_copy_in(sys_task_, sizeof(ksurface_ent_token_t), &(mach.token), token_ptr);
        }
        
        if(!succeed)
        {
            sys_return_failure(EFAULT);
        }
    }
    
    /* switching */
    switch(flag)
    {
        case ET_CREATE:
        {
            ksurface_return_t ksr = entitlement_token_generate_for_entitlement(sys_proc_, entitlement, &(mach.token));
            
            if(ksr != SURFACE_SUCCESS)
            {
                sys_return_failure(EPERM);
            }
            
            if(!mach_syscall_copy_out(sys_task_, sizeof(ksurface_ent_token_t), &(mach.token), token_ptr))
            {
                sys_return_failure(EFAULT);
            }
            
            break;
        }
        case ET_CONSUME:
        {
            ksurface_return_t ksr = entitlement_token_consume(sys_proc_, &(mach.token));
            
            if(ksr != SURFACE_SUCCESS)
            {
                sys_return_failure(EPERM);
            }
            
            break;
        }
        case ET_VERIFY:
        {
            ksurface_return_t ksr = entitlement_token_verify(&(mach.token));
            
            if(ksr != SURFACE_SUCCESS)
            {
                sys_return_failure(EPERM);
            }
            
            break;
        }
        case ET_VERIFY_MACH:
        {            
            ksurface_return_t ksr = entitlement_mach_verify(&mach);
            
            if(ksr != SURFACE_SUCCESS)
            {
                sys_return_failure(EPERM);
            }
            
            break;
        }
        default:
            sys_return_failure(EINVAL);
            break;
    }
    
    sys_return;
}
