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

#include <CoreCompiler/CCPhase.h>

static CFTypeID gCCPhaseTypeID = _kCFRuntimeNotATypeID;

struct opaque_ccphase {
    CFRuntimeBase _base;
    CCJobType type;
    CFArrayRef jobs;
    Boolean multithreadingSupport;
};

static CFTypeRef CCPhaseCopy(CFAllocatorRef allocator,
                             CFTypeRef cf)
{
    return CFRetain(cf);
}

static void CCPhaseFinalize(CFTypeRef cf)
{
    CCPhaseRef phaseRef = (CCPhaseRef)cf;
    CFRelease(phaseRef->jobs);
}

static const CFRuntimeClass gCCPhaseClass = {
    0,                              /* version */
    "CCKPhase",                     /* class name (later for OBJC type) */
    NULL,                           /* init */
    CCPhaseCopy,                    /* copy */
    CCPhaseFinalize,                /* finalize */
    NULL,                           /* equal */
    NULL,                           /* hash */
    NULL,                           /* copyFormattingDesc */
    NULL,                           /* copyDebugDesc */
    NULL,
    NULL,
    0
};

CFTypeID CCPhaseGetTypeID(void)
{
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        gCCPhaseTypeID = _CFRuntimeRegisterClass(&gCCPhaseClass);
    });
    return gCCPhaseTypeID;
}

CCPhaseRef CCPhaseCreate(CFAllocatorRef allocator,
                         CCJobType type,
                         CFArrayRef jobs,
                         Boolean multithreadingSupport)
{
    assert(jobs != nil);
    
    CCPhaseRef phase = (CCPhaseRef)_CFRuntimeCreateInstance(allocator, CCPhaseGetTypeID(), sizeof(struct opaque_ccphase) - sizeof(CFRuntimeBase), NULL);
    if(phase == nil)
    {
        return nil;
    }
    
    phase->type = type;
    phase->jobs = CFRetain(jobs);
    phase->multithreadingSupport = multithreadingSupport;
    
    return phase;
}

CCJobType CCPhaseGetType(CCPhaseRef phase)
{
    return phase->type;
}

CFArrayRef CCPhaseGetJobs(CCPhaseRef phase)
{
    return phase->jobs;
}

Boolean CCPhaseMultithreadingSupported(CCPhaseRef phase)
{
    return phase->multithreadingSupport;
}
