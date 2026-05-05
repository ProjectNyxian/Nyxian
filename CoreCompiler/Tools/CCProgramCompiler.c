/*
 * MIT License
 *
 * Copyright (c) 2024 light-tech
 * Copyright (c) 2026 cr4zyengineer
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

#include <CoreCompiler/CCProgramCompiler.h>
#include <CoreCompiler/CCDriver.h>

Boolean CCProgramCompilerExecuteWithArguments(CFArrayRef arguments,
                                              CFArrayRef *outDiagnostic)
{
    assert(arguments != nil);

    /* allocating outDiagnostic sub array if applicable */
    if(outDiagnostic != nil)
    {
        *outDiagnostic = CFArrayCreateMutable(kCFAllocatorSystemDefault, 1, &kCFTypeArrayCallBacks);
    }

    /* preparing for execution */
    /* TODO: somehow add swift support */
    CCDriverRef driver = CCDriverCreate(kCFAllocatorSystemDefault, arguments, CCDriverTypeClang);
    if(driver == nil)
    {
        return false;
    }

    CFArrayRef jobs = CCDriverCreateJobs(driver);
    CFRelease(driver);
    if(jobs == nil)
    {
        return false;
    }

    /* getting those jobs lol */
    CFIndex count = CFArrayGetCount(jobs);
    for(CFIndex i = 0; i < count; i ++)
    {
        CCJobRef job = (CCJobRef)CFArrayGetValueAtIndex(jobs, i);
        if(job == nil)
        {
            continue;
        }

        /* executing the job */
        CFArrayRef jobDiagnostic = nil;
        Boolean success = CCJobExecuteJob(job, &jobDiagnostic, nil);

        /* checking for diagnostics to copy over */
        if(jobDiagnostic != nil)
        {
            if(outDiagnostic != nil &&
               *outDiagnostic != nil)
            {
               CFIndex count = CFArrayGetCount(jobDiagnostic);
               for(CFIndex i = 0; i < count; i++)
               {
                   CCDiagnosticRef diagnostic = (CCDiagnosticRef)CFArrayGetValueAtIndex(jobDiagnostic, i);
                   if(diagnostic == nil)
                   {
                       continue;
                   }

                   CFArrayAppendValue((CFMutableArrayRef)*outDiagnostic, diagnostic);
               }
            }

            CFRelease(jobDiagnostic);
        }

        if(!success)
        {
            CFRelease(jobs);
            return false;
        }
    }

    CFRelease(jobs);
    return true;
}
