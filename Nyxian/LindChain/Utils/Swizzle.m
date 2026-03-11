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

#import <LindChain/Utils/Swizzle.h>

static unsigned char swizzle_objc_method_type(Class class,
                                              SEL action,
                                              Method *method,
                                              unsigned char *type)
{
    // First safety check
    if(method == nil ||
       type == NULL)
    {
        return SWIZZLE_RETURN_ARGUMENTS;
    }

    // Get method
    *method = class_getClassMethod(class, action);
    *type = SWIZZLE_METHOD_TYPE_CLASS;
    
    // If method is nil it has to be done again but with instance method approach
    if(*method == nil)
    {
        // Yep we do
        *method = class_getInstanceMethod(class, action);
        *type = SWIZZLE_METHOD_TYPE_INSTANCE;
    }
    
    return SWIZZLE_RETURN_SUCCESS;
}

unsigned char swizzle_objc_method(SEL originalAction,
                                  Class originalClass,
                                  SEL replacementAction,
                                  Class replacementClass)
{
    // First safety check
    if(originalAction == nil ||
       originalClass == nil  ||
       replacementAction == nil)
    {
        return SWIZZLE_RETURN_ARGUMENTS;
    }
    
    // Get the type of those methods
    Method originalMethod;
    Method replacementMethod;
    
    unsigned char originalType;
    unsigned char replacementType;
    
    swizzle_objc_method_type(originalClass, originalAction, &originalMethod, &originalType);
    
    if(replacementClass)
    {
        swizzle_objc_method_type(replacementClass, replacementAction, &replacementMethod, &replacementType);
    }
    else
    {
        swizzle_objc_method_type(originalClass, replacementAction, &replacementMethod, &replacementType);
    }
    
    // Now both types have to match
    // MARK: Not necessarily but lack of knowledge
    if(originalType != replacementType)
    {
        return SWIZZLE_RETURN_METHOD_TYPE;
    }
    else if(originalMethod == nil ||
            replacementMethod == nil)
    {
        return SWIZZLE_RETURN_ARGUMENTS;
    }
    
    // Now we gonna get their implementations
    if(replacementClass)
    {
        // Add the method so its available in the class
        class_addMethod(originalClass, replacementAction, method_getImplementation(replacementMethod), method_getTypeEncoding(replacementMethod));
        swizzle_objc_method_type(originalClass, replacementAction, &replacementMethod, &replacementType);
        if(replacementMethod == nil)
        {
            return SWIZZLE_RETURN_ARGUMENTS;
        }
    }
    method_exchangeImplementations(originalMethod, replacementMethod);
    
    return SWIZZLE_RETURN_SUCCESS;
}
