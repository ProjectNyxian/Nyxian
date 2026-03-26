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

#import <LindChain/ProcEnvironment/Surface/sys/compat/getpk.h>

DEFINE_SYSCALL_HANDLER(getpk)
{
    userspace_pointer_t key_user_ptr = (userspace_pointer_t)args[0];
    userspace_pointer_t key_len_ptr = (userspace_pointer_t)args[1];
    
    size_t key_len = 0;
    if(!mach_syscall_copy_in(sys_task_, sizeof(size_t), &key_len, key_len_ptr))
    {
        sys_return_failure(EFAULT);
    }
    
    if(key_len < ksurface->pub_key_len)
    {
        sys_return_failure(E2BIG);
    }
    
    if(!mach_syscall_copy_out(sys_task_, ksurface->pub_key_len, ksurface->pub_key, key_user_ptr) ||
       !mach_syscall_copy_out(sys_task_, sizeof(size_t), &key_len, key_len_ptr))
    {
        sys_return_failure(EFAULT);
    }
    
    sys_return;
}
