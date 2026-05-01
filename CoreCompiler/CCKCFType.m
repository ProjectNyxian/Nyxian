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

#import <CoreCompiler/CCKCFType.h>
#import <CoreCompiler/CFRuntime.h>
#import <objc/runtime.h>

@implementation CCKCFType

+ (void)load
{
    /*
     * needed since the class is not existing at
     * link time it seems like and only exists
     * at runtime and DYLD can't resolve it
     * so we do it using the ObjC runtime.
     */
    Class nscfType = NSClassFromString(@"NSCFType");
    if(!nscfType)
    {
        return;
    }
    
    Class self_class = [self class];
    Class self_meta = object_getClass(self_class);
    
    /* instance methods */
    unsigned int count = 0;
    Method *methods = class_copyMethodList(nscfType, &count);
    for(unsigned int i = 0; i < count; i++)
    {
        class_addMethod(self_class, method_getName(methods[i]), method_getImplementation(methods[i]), method_getTypeEncoding(methods[i]));
    }
    free(methods);
    
    /* class methods */
    Method *classMethods = class_copyMethodList(object_getClass(nscfType), &count);
    for(unsigned int i = 0; i < count; i++)
    {
        class_addMethod(self_meta, method_getName(classMethods[i]), method_getImplementation(classMethods[i]), method_getTypeEncoding(classMethods[i]));
    }
    free(classMethods);
}

@end
