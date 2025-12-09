/*
 Copyright (C) 2025 cr4zyengineer

 This file is part of Nyxian.

 Nyxian is free software: you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.

 Nyxian is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 GNU General Public License for more details.

 You should have received a copy of the GNU General Public License
 along with Nyxian. If not, see <https://www.gnu.org/licenses/>.
*/

#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import <ResecureDecoder.h>
#import <LindChain/ProcEnvironment/Object/ArchiveObject.h>
#import <LindChain/ProcEnvironment/Object/FDMapObject.h>
#import <LindChain/ProcEnvironment/Object/FileObject.h>
#import <LindChain/ProcEnvironment/Object/MachPortObject.h>
#import <LindChain/ProcEnvironment/Object/MappingPortObject.h>
#import <LindChain/ProcEnvironment/Object/TaskPortObject.h>

void ResecureDecoder(void)
{
    /* getting nsxpcdecoder class */
    Class decoderClass = NSClassFromString(@"NSXPCDecoder");
    
    /* get the selector and method ready */
    SEL validateSel = NSSelectorFromString(@"_validateAllowedClass:forKey:allowingInvocations:");
    Method validateMethod = class_getInstanceMethod(decoderClass, validateSel);
    if(!validateMethod)
    {
        return;
    }
    
    /* get the implementation pointer */
    static IMP orig_validate = NULL;
    orig_validate = method_getImplementation(validateMethod);
    
    /* create a hooking block */
    IMP new_validate = imp_implementationWithBlock(^BOOL(id self, Class cls, NSString *key, BOOL allowInvocations) {
        static NSSet *allowedClasses = nil;
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            allowedClasses = [NSSet setWithObjects:
                              [ArchiveObject class],
                              [FDMapObject class],
                              [FileObject class],
                              [MachPortObject class],
                              [MappingPortObject class],
                              [TaskPortObject class],
                              [NSXPCListenerEndpoint class],
                              nil];
        });
        
        if([allowedClasses containsObject:cls])
        {
            return YES;
        }
        
        return ((BOOL(*)(id, SEL, Class, NSString*, BOOL))orig_validate)(self, validateSel, cls, key, allowInvocations);
    });
    
    /* hook! */
    method_setImplementation(validateMethod, new_validate);
}
