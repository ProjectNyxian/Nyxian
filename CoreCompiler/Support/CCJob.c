/*
 * MIT License
 *
 * Copyright (c) 2026 mach-port-t
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in all
 * copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 * SOFTWARE.
 */

#include <CoreCompiler/CCJob.h>
#include <CoreCompiler/CCDriver.h>
#include <CoreCompiler/CCCompiler.h>
#include <CoreCompiler/CCSwiftCompiler.h>
#include <CoreCompiler/CCLinker.h>

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
    "CCJob",                        /* class name */
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

CC_EXPORT Boolean CCJobExecuteJob(CCJobRef job,
                                  CFArrayRef *outDiagnostic,
                                  CFStringRef *outMainSource)
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
            
            CCFileRef file = CCASTUnitGetFile(ASTUnit);
            if(file != nil)
            {
                CFStringRef mainSource = CFURLCopyFileSystemPath(CCFileGetFileURL(file), kCFURLPOSIXPathStyle);
                if(mainSource != nil && outMainSource != nil)
                {
                    *outMainSource = mainSource;
                }
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
        case CCJobTypeSwiftCompiler:
        {
            return CCSwiftCompilerJobExecute(job, outDiagnostic, outMainSource);
        }
        case CCJobTypeLinker:
        {
            if(outMainSource != nil)
            {
                *outMainSource = CFSTR("linker");
            }
            return CCLinkerJobExecute(job, outDiagnostic);
        }
        case CCJobTypeUnknown:
            /* fallthrough */
        default:
            return false;
    }
}
