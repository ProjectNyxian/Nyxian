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

#import <LindChain/Utils/Swizzle.h>

typedef struct {
    Method method;
    SwizzleMethodType type;
} SwizzleMethod;

static SwizzleMethod SwizzleGetMethod(Class class,
                                      SEL selector,
                                      SwizzleMethodType swizzleMethodType)
{
    SwizzleMethod swizzleMethod = { .method = nil, .type = swizzleMethodType };
    if(selector == nil)
    {
        return swizzleMethod;
    }
    
    switch(swizzleMethodType)
    {
        case kSwizzleMethodTypeClass:
            swizzleMethod.method = class_getClassMethod(class, selector);
            break;
        case kSwizzleMethodTypeInstance:
            swizzleMethod.method = class_getInstanceMethod(class, selector);
            break;
        default:
            break;
            
    }
    
    if(swizzleMethod.method == nil)
    {
        swizzleMethod.type = kSwizzleMethodTypeUnknown;
    }
    
    return swizzleMethod;
}

SwizzleReturn SwizzleObjCMethod(SEL originalAction,
                                Class originalClass,
                                SEL replacementAction,
                                Class replacementClass,
                                SwizzleMethodType swizzleMethodType)
{
    if(originalAction == nil || originalClass == nil  || replacementAction == nil)
    {
        return kSwizzleReturnArguments;
    }
    
    SwizzleMethod originalMethod = SwizzleGetMethod(originalClass, originalAction, swizzleMethodType);
    SwizzleMethod replacementMethod = SwizzleGetMethod(replacementClass ?: originalClass, replacementAction, swizzleMethodType);
    if(originalMethod.method == nil || replacementMethod.method == nil)
    {
        return kSwizzleReturnArguments;
    }
    
    Class targetClass = (swizzleMethodType == kSwizzleMethodTypeClass) ? object_getClass((id)originalClass) : originalClass;
    
    if(replacementClass)
    {
        class_addMethod(targetClass, replacementAction, method_getImplementation(replacementMethod.method), method_getTypeEncoding(replacementMethod.method));
        replacementMethod = SwizzleGetMethod(originalClass, replacementAction, swizzleMethodType);
        if(replacementMethod.method == nil)
        {
            return kSwizzleReturnArguments;
        }
    }
    method_exchangeImplementations(originalMethod.method, replacementMethod.method);
    
    return kSwizzleReturnSuccess;
}
