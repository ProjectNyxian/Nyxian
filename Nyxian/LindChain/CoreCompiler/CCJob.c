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
#include <LindChain/CoreCompiler/CCDriver.h>
#include <LindChain/CoreCompiler/CCCompiler.h>
#include <LindChain/CoreCompiler/CCLinker.h>

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
    if(jobRef->arguments != nil)
    {
        CFRelease(jobRef->arguments);
    }
}

static const CFRuntimeClass gCCJobClass = {
    0,                              /* version */
    "LDEJob",                       /* class name (later for OBJC type) */
    NULL,                           /* init */
    CCJobCopy,                      /* copy */
    CCJobFinalize,                  /* finalize */
    NULL,                           /* equal */
    NULL,                           /* hash */
    NULL,                           /* copyFormattingDesc */
    NULL,                           /* copyDebugDesc */
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
                     CFArrayRef CC1Arguments)
{
    assert(CC1Arguments != nil);
    
    CCJobRef jobRef = (CCJobRef)_CFRuntimeCreateInstance(allocator, CCJobGetTypeID(), sizeof(struct opaque_ccjob) - sizeof(CFRuntimeBase), NULL);
    if(jobRef == nil)
    {
        return nil;
    }
    
    jobRef->type = type;
    jobRef->arguments = CFRetain(CC1Arguments);
    
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

Boolean CCJobExecuteJob(CCJobRef job,
                        CFArrayRef *outDiagnostic)
{
    switch(job->type)
    {
        case CCJobTypeCompiler:
        {
            CCASTUnitRef ASTUnit = CCCompilerJobExecute(job);
            if(ASTUnit == nil)
            {
                return false;
            }
            
            CFArrayRef diagnostics = CCASTUnitCopyDiagnostics(ASTUnit);
            if(diagnostics)
            {
                *outDiagnostic = diagnostics;
            }
            
            Boolean didErrorOccur = CCASTUnitErrorOccured(ASTUnit);
            
            CFRelease(ASTUnit);
            
            return !didErrorOccur;
        }
        case CCJobTypeLinker:
        {
            return CCLinkerJobExecute(job, outDiagnostic);
        }
        case CCJobTypeUnknown:
            /* fallthrough */
        default:
            return false;
    }
}
