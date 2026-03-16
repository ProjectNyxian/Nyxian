/*
 SPDX-License-Identifier: AGPL-3.0-or-later

 Copyright (C) 2023 - 2026 LiveContainer
 Copyright (C) 2026 cr4zyengineer

 This file is part of LiveContainer.

 LiveContainer is free software: you can redistribute it and/or modify
 it under the terms of the GNU Affero General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.

 LiveContainer is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 GNU Affero General Public License for more details.

 You should have received a copy of the GNU Affero General Public License
 along with Nyxian. If not, see <https://www.gnu.org/licenses/>.
*/

#import <LindChain/Private/FoundationPrivate.h>
#import <LindChain/LiveContainer/LCMachOUtils.h>
#import <LindChain/LiveContainer/utils.h>

#include <mach/mach.h>
#include <mach-o/dyld.h>
#include <mach-o/dyld_images.h>
#include <objc/runtime.h>

#include <dlfcn.h>
#include <execinfo.h>
#include <signal.h>
#include <sys/mman.h>
#include <stdlib.h>
#import <LindChain/litehook/litehook.h>
#import <LindChain/LiveContainer/Tweaks/Tweaks.h>
#include <mach-o/ldsyms.h>
#import <LindChain/Services/applicationmgmtd/LDEApplicationObject.h>
#import <LindChain/ProcEnvironment/Surface/surface.h>
#import <LindChain/ProcEnvironment/Object/MachOObject.h>
#import <LindChain/LiveContainer/LCBootstrap.h>
#import <malloc/malloc.h>
#import <LindChain/Utils/CFTools.h>

int hook__NSGetExecutablePath_overwriteExecPath(char*** dyldApiInstancePtr, char* newPath, uint32_t* bufsize)
{
    assert(dyldApiInstancePtr != 0);
    char** dyldConfig = dyldApiInstancePtr[1];
    assert(dyldConfig != 0);
    
    char** mainExecutablePathPtr = 0;
    // mainExecutablePath is at 0x10 for iOS 15~18.3.2, 0x20 for iOS 18.4+
    if(dyldConfig[2] != 0 && dyldConfig[2][0] == '/') {
        mainExecutablePathPtr = dyldConfig + 2;
    } else if (dyldConfig[4] != 0 && dyldConfig[4][0] == '/') {
        mainExecutablePathPtr = dyldConfig + 4;
    } else {
        assert(mainExecutablePathPtr != 0);
    }

    kern_return_t ret = builtin_vm_protect(mach_task_self(), (mach_vm_address_t)mainExecutablePathPtr, sizeof(mainExecutablePathPtr), false, PROT_READ | PROT_WRITE);
    if(ret != KERN_SUCCESS) {
        assert(os_tpro_is_supported());
        os_thread_self_restrict_tpro_to_rw();
    }
    /* MARK: setting a copy of the path as the new pointer (required cuz objc NSString UTF8String pointers are not safe and can become stale) */
    *mainExecutablePathPtr = strdup(newPath);
    if(ret != KERN_SUCCESS) {
        os_thread_self_restrict_tpro_to_ro();
    }

    return 0;
}

void LCOverwriteExecutablePath(NSString *executablePath)
{
    /* first overwriting bundle */
    CFBundleRef guestMainCFBundle = CFBundleCreate(NULL, (__bridge CFURLRef)([[NSURL fileURLWithPath:executablePath] URLByDeletingLastPathComponent]));
    assert(guestMainCFBundle != nil);
    
    /*
     * overwrites CF object, means all our pointers become
     * unsafe, it also takes a reference of passed Bundle
     * so we can safely release our bundle... after that
     * we shouldnt touch our bundle ever again, because
     * remember its now owned by the main bundle's prior
     * object.
     */
    CFOverwrite((__bridge CFBundleRef)NSBundle.mainBundle._cfBundle, guestMainCFBundle);
    CFRelease(guestMainCFBundle);
    
    /*
     * dyld4 stores executable path in a different place (iOS 15.0 +)
     * https://github.com/apple-oss-distributions/dyld/blob/ce1cc2088ef390df1c48a1648075bbd51c5bbc6a/dyld/DyldAPIs.cpp#L802
     */
    int (*orig__NSGetExecutablePath)(void* dyldPtr, char* buf, uint32_t* bufsize);
    performHookDyldApi("_NSGetExecutablePath", 2, (void**)&orig__NSGetExecutablePath, hook__NSGetExecutablePath_overwriteExecPath);
    _NSGetExecutablePath((char*)[executablePath UTF8String], NULL);
    /* put the original function back */
    performHookDyldApi("_NSGetExecutablePath", 2, (void**)&orig__NSGetExecutablePath, orig__NSGetExecutablePath);
    
    /* overwriting remaining upper systems */
    NSString *procName = [executablePath lastPathComponent];
    NSProcessInfo.processInfo.processName = procName;
    *_CFGetProgname() = strdup(procName.UTF8String);
    *_CFGetProcessPath() = strdup(executablePath.UTF8String);
    Class swiftNSProcessInfo = NSClassFromString(@"_NSSwiftProcessInfo");
    if(swiftNSProcessInfo)
    {
        /* swizzle the arguments method to return the ObjC arguments */
        SEL selector = @selector(arguments);
        method_setImplementation(class_getInstanceMethod(swiftNSProcessInfo, selector), class_getMethodImplementation(NSProcessInfo.class, selector));
    }
}

static void *getAppEntryPoint(void *handle)
{
    const struct mach_header_64 *header = (const struct mach_header_64 *)getGuestAppHeader();
    const struct load_command *cmd = (const struct load_command *) ((uintptr_t)header + sizeof(struct mach_header_64));

    for(uint32_t i = 0; i < header->ncmds; i++)
    {
        if(__builtin_expect(cmd->cmd == LC_MAIN, 0))
        {
            const struct entry_point_command *ec = (const struct entry_point_command *)cmd;
            assert(ec->entryoff > 0);
            return (void *)((uintptr_t)header + ec->entryoff);
        }
        cmd = (const struct load_command *)((uintptr_t)cmd + cmd->cmdsize);
    }

    __builtin_unreachable();
}

void InsertLibrariesIfNeeded(void)
{
    const char *librariesToInsert = getenv("DYLD_INSERT_LIBRARIES");
    
    if(librariesToInsert == NULL)
    {
        return;
    }
    
    NSString *nsLibrariesToInsert = [NSString stringWithCString:librariesToInsert encoding:NSUTF8StringEncoding];
    NSArray<NSString*> *librariesToInsertArray = [nsLibrariesToInsert componentsSeparatedByString:@":"];
    
    for(NSString *library in librariesToInsertArray)
    {
        void *handle = dlopen([library UTF8String], RTLD_GLOBAL | RTLD_NOW);
        
        if(handle == NULL)
        {
            const char *error = dlerror();
            fprintf(stderr, "%s\n", error);
            exit(1);
        }
    }
}

int LCBootstrapMain(NSString *executablePath,
                    int argc,
                    char *argv[])
{
    if(executablePath == nil)
    {
        return 1;
    }
    
    /* Preload executable to bypass RT_NOLOAD */
    appMainImageIndex = _dyld_image_count();
    void *appHandle = dlopenBypassingLock(executablePath.fileSystemRepresentation, RTLD_LAZY|RTLD_GLOBAL|RTLD_FIRST);
    appExecutableHandle = appHandle;
    const char *dlerr = dlerror();
    
    if(!appHandle || (uint64_t)appHandle > 0xf00000000000 || dlerr)
    {
        return 1;
    }
    
    /* find main */
    int (*appMain)(int, char**) = getAppEntryPoint(appHandle);
    if(!appMain)
    {
        return 1;
    }
    
    /* perform other hooks */
    NUDGuestHooksInit();
    SecItemGuestHooksInit();
    NSFMGuestHooksInit();
    UIKitGuestHooksInit();
    initDead10ccFix();
    DyldHooksInit();
    InsertLibrariesIfNeeded();
    
    return appMain(argc, argv);
}
