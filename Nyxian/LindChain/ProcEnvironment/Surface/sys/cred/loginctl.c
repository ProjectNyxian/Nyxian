/*
 SPDX-License-Identifier: LicenseRef-EPSL-1.1

 Copyright (C) 2025 - 2026 emexlab

 This file is part of Nyxian.

 Licensed under the emexLabs Public Source License, version 1.1
 (EPSL 1.1).

 Private use and modification are permitted under the license.
 Redistribution of source or binaries, modified or unmodified,
 requires prior written permission from emexLabs.

 External deployment is subject to the source-availability
 requirements and other conditions of the license.

 Provided "AS IS", without warranty, to the extent permitted by law.

 See LICENSE for the full license terms.
*/

#include <LindChain/ProcEnvironment/Surface/sys/cred/loginctl.h>
#include <LindChain/ProcEnvironment/Surface/sys/cred/setuid.h>
#include <LindChain/ProcEnvironment/Surface/proc/def.h>
#include <ksurface_abi.h>
#include <errno.h>
#include <string.h>

DEFINE_SYSCALL_HANDLER(loginctl)
{
    PELoginCTLAction action = (PELoginCTLAction)args[0];
    size_t index = (size_t)args[1];
    
    switch(action)
    {
        case kPELoginCTLGetLength:
        {
            return sys_proc_snapshot_->nyx.login_name_len;
        }
            
        case kPELoginCTLGetWord:
        {
            size_t offset = index * sizeof(uint64_t);
            if(offset >= sizeof(sys_proc_snapshot_->nyx.login_name))
            {
                sys_return_failure_with_errno(EINVAL);
            }
            uint64_t word = 0;
            if(offset < sys_proc_snapshot_->nyx.login_name_len)
            {
                size_t count = sys_proc_snapshot_->nyx.login_name_len - offset;
                if(count > sizeof(word)) count = sizeof(word);
                memcpy(&word, sys_proc_snapshot_->nyx.login_name + offset, count);
            }
            return (int64_t)word;
        }
        case kPELoginCTLSetWord:
        {
            if(!proc_is_privileged(sys_proc_))
            {
                sys_return_failure_with_errno(EPERM);
            }
            size_t offset = index * sizeof(uint64_t);
            if(offset >= sizeof(sys_proc_->nyx.login_name))
            {
                sys_return_failure_with_errno(EINVAL);
            }
            uint64_t word = (uint64_t)args[2];
            size_t count = sizeof(word);
            if(offset + count > sizeof(sys_proc_->nyx.login_name))
            {
                count = sizeof(sys_proc_->nyx.login_name) - offset;
            }
            kvo_wrlock(sys_proc_);
            memcpy(sys_proc_->nyx.login_name + offset, &word, count);
            kvo_unlock(sys_proc_);
            sys_return;
        }
        case kPELoginCTLCommit:
        {
            if(!proc_is_privileged(sys_proc_))
            {
                sys_return_failure_with_errno(EPERM);
            }
            size_t len = (size_t)args[1];
            if(len >= sizeof(sys_proc_->nyx.login_name))
            {
                sys_return_failure_with_errno(EINVAL);
            }
            kvo_wrlock(sys_proc_);
            sys_proc_->nyx.login_name[len] = '\0';
            sys_proc_->nyx.login_name_len = (uint16_t)len;
            kvo_unlock(sys_proc_);
            sys_return;
        }

        case kPELoginCTLClear:
            if(!proc_is_privileged(sys_proc_))
            {
                sys_return_failure_with_errno(EPERM);
            }
            kvo_wrlock(sys_proc_);
            memset(sys_proc_->nyx.login_name, 0, sizeof(sys_proc_->nyx.login_name));
            sys_proc_->nyx.login_name_len = 0;
            kvo_unlock(sys_proc_);
            sys_return;
    }
    
    sys_return_failure_with_errno(EINVAL);
}
