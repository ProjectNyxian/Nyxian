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

#import <LindChain/Compiler/LDECFType.h>
#import <LindChain/Private/CoreFoundation/CFRuntime.h>
#import <libkern/OSAtomic.h>
#include <objc/runtime.h>

@implementation LDECFType

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
