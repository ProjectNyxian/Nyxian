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

#include <LindChain/CoreCompiler/CCJob.h>

static CFTypeID gCCJobTypeID = _kCFRuntimeNotATypeID;

struct opaque_ccjob {
    CFRuntimeBase _base;
    CCJobType type;
    CFArrayRef arguments;
};

static CFTypeRef CCJobCopy(CFAllocatorRef allocator,
                           CFTypeRef cf)
{
    return CFRetain(cf);
}

static void CCJobFinalize(CFTypeRef cf)
{
    CCJobRef jobRef = (CCJobRef)cf;
    CFRelease(jobRef->arguments);
}

static CFStringRef CCJobCopyFormattingDesc(CFTypeRef cf,
                                           CFDictionaryRef options)
{
    CCJobRef jobRef = (CCJobRef)cf;
    return CFStringCreateWithFormat(kCFAllocatorDefault, NULL, CFSTR("%@"), jobRef->arguments);
}

static CFStringRef CCJobCopyDebugDesc(CFTypeRef cf)
{
    CCJobRef jobRef = (CCJobRef)cf;
    return CFStringCreateWithFormat(kCFAllocatorDefault, NULL, CFSTR("<CCFile %p: type=%d arguments=%@>"), cf, jobRef->type, jobRef->arguments);
}

static const CFRuntimeClass gCCJobClass = {
    0,                              /* version */
    "LDEJob",                       /* class name (later for OBJC type) */
    NULL,                           /* init */
    CCJobCopy,                      /* copy */
    CCJobFinalize,                  /* finalize */
    NULL,                           /* equal */
    NULL,                           /* hash */
    CCJobCopyFormattingDesc,        /* copyFormattingDesc */
    CCJobCopyDebugDesc,             /* copyDebugDesc */
    NULL,
    NULL,
    0
};

CFTypeID CCJobGetTypeID(void)
{
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        gCCJobTypeID = _CFRuntimeRegisterClass(&gCCJobClass);
    });
    return gCCJobTypeID;
}

CCJobRef CCJobCreate(CFAllocatorRef allocator,
                     CCJobType type,
                     CFArrayRef args)
{
    assert(args != nil);
    
    CCJobRef jobRef = (CCJobRef)_CFRuntimeCreateInstance(allocator, CCJobGetTypeID(), sizeof(struct opaque_ccjob) - sizeof(CFRuntimeBase), NULL);
    if(jobRef == nil)
    {
        return nil;
    }
    
    jobRef->arguments = CFRetain(args);
    
    return jobRef;
}

CCJobType CCJobGetType(CCJobRef job)
{
    return job->type;
}

CFArrayRef CCJobGetArguments(CCJobRef job)
{
    return job->arguments;
}
