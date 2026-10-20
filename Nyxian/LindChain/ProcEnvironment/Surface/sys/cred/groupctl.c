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

#include <LindChain/ProcEnvironment/Surface/sys/cred/groupctl.h>
#include <LindChain/ProcEnvironment/Surface/sys/cred/setuid.h>
#include <LindChain/ProcEnvironment/Surface/proc/def.h>
#include <ksurface_abi.h>
#include <errno.h>
#include <string.h>

DEFINE_SYSCALL_HANDLER(groupctl)
{
    PEGroupCTLAction action = (PEGroupCTLAction)args[0];
    size_t index = (size_t)args[1];
    
    switch(action)
    {
        case kPEGroupCTLGetCount:
        {
            return sys_proc_snapshot_->nyx.supplementary_group_count;
        }
        case kPEGroupCTLGetAt:
        {
            if(index >= sys_proc_snapshot_->nyx.supplementary_group_count)
            {
                sys_return_failure_with_errno(EINVAL);
            }
            return sys_proc_snapshot_->nyx.supplementary_groups[index];
        }
        case kPEGroupCTLSetAt:
        {
            if(!proc_is_privileged(sys_proc_))
            {
                sys_return_failure_with_errno(EPERM);
            }
            if(index >= PE_SUPPLEMENTARY_GROUPS_MAX)
            {
                sys_return_failure_with_errno(EINVAL);
            }
            kvo_wrlock(sys_proc_);
            sys_proc_->nyx.supplementary_groups[index] = (gid_t)args[2];
            kvo_unlock(sys_proc_);
            sys_return;
        }
        case kPEGroupCTLCommit:
        {
            if(!proc_is_privileged(sys_proc_))
            {
                sys_return_failure_with_errno(EPERM);
            }
            size_t count = (size_t)args[1];
            if(count > PE_SUPPLEMENTARY_GROUPS_MAX)
            {
                sys_return_failure_with_errno(EINVAL);
            }
            kvo_wrlock(sys_proc_);
            sys_proc_->nyx.supplementary_group_count = (uint16_t)count;
            kvo_unlock(sys_proc_);
            sys_return;
        }
        case kPEGroupCTLClear:
        {
            if(!proc_is_privileged(sys_proc_))
            {
                sys_return_failure_with_errno(EPERM);
            }
            kvo_wrlock(sys_proc_);
            memset(sys_proc_->nyx.supplementary_groups, 0, sizeof(sys_proc_->nyx.supplementary_groups));
            sys_proc_->nyx.supplementary_group_count = 0;
            kvo_unlock(sys_proc_);
            sys_return;
        }
    }
    
    sys_return_failure_with_errno(EINVAL);
}
