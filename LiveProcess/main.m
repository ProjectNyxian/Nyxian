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

#import <dlfcn.h>
#import <UIKit/UIKit.h>
#import <mach-o/dyld.h>
#import <objc/runtime.h>
#import <LindChain/litehook/litehook.h>
#import <LindChain/ProcEnvironment/environment.h>
#import <LindChain/ProcEnvironment/proxy.h>
#import <LindChain/ProcEnvironment/posix_spawn.h>
#import <LindChain/ProcEnvironment/Surface/surface.h>
#import <LindChain/ProcEnvironment/Object/FDMapObject.h>

#import <ServiceKit/ServiceKit.h>
#import <LindChain/Services/trustd/LDETrustProxy.h>
#import <LindChain/Services/applicationmgmtd/LDEApplicationWorkspaceInternal.h>

#import <ResecureDecoder.h>

#import <LindChain/ProcEnvironment/Syscall/mach_syscall_client.h>
#import <LindChain/ProcEnvironment/syscall.h>

bool performHookDyldApi(const char* functionName, uint32_t adrpOffset, void** origFunction, void* hookFunction);

@interface LiveProcessHandler : NSObject<NSExtensionRequestHandling>
@end
@implementation LiveProcessHandler
static NSExtensionContext *extensionContext;
static NSDictionary *retrievedAppInfo;
+ (NSExtensionContext *)extensionContext {
    return extensionContext;
}

+ (NSDictionary *)retrievedAppInfo {
    return retrievedAppInfo;
}

- (void)beginRequestWithExtensionContext:(NSExtensionContext *)context {
    extensionContext = context;
    retrievedAppInfo = [context.inputItems.firstObject userInfo];
    // Return control to LiveContainerMain
    CFRunLoopStop(CFRunLoopGetMain());
}
@end

extern char **environ;
void clear_environment(void)
{
    while(environ[0] != NULL)
    {
        char *eq = strchr(environ[0], '=');
        if(eq)
        {
            size_t len = eq - environ[0];
            char key[len + 1];
            strncpy(key, environ[0], len);
            key[len] = '\0';
            
            if(unsetenv(key) != 0)
            {
                environ++;
            }
        }
        else
        {
            environ++;
        }
    }
}

void overwriteEnvironmentProperties(NSDictionary *enviroDict)
{
    clear_environment();
    if(enviroDict)
    {
        for (NSString *key in enviroDict)
        {
            NSString *value = enviroDict[key];
            setenv([key UTF8String], [value UTF8String], 0);
        }
    }
}

void createArgv(NSArray<NSString *> *arguments,
                int *argc,
                char ***argv) {
    if (!arguments) {
        *argc = 0;
        return;
    }
    
    NSInteger count = arguments.count;
    *argc = (int)count;
    
    *argv = malloc(sizeof(char *) * (count + 1));
    for (NSInteger i = 0; i < count; i++) {
        (*argv)[i] = strdup(arguments[i].UTF8String);
    }
    (*argv)[count] = NULL;
}

extern NSString *LCHomePath;

int LiveProcessMain(int argc, char *argv[]) {
    // Let NSExtensionContext initialize, once it's done it will call CFRunLoopStop
    CFRunLoopRun();
    NSDictionary *appInfo = LiveProcessHandler.retrievedAppInfo;
    
    // MARK: New API that will overtake the previous one
    NSXPCListenerEndpoint* endpoint = appInfo[@"LSEndpoint"];
    NSString* executablePath = appInfo[@"LSExecutablePath"];
    NSString *mode = appInfo[@"LSServiceMode"];
    NSString *service = appInfo[@"LSIntegratedServiceName"];
    NSDictionary *environmentDictionary = appInfo[@"LSEnvironment"];
    NSArray *argumentDictionary = appInfo[@"LSArguments"];
    FDMapObject *mapObject = appInfo[@"LSMapObject"];
    
    // Setup fd map
    if(mapObject) [mapObject apply_fd_map];
    setvbuf(stdout, NULL, _IONBF, 0);
    setvbuf(stderr, NULL, _IONBF, 0);
    
    // Setting up environment
    environment_client_connect_to_host(endpoint);
    
    MachPortObject *syscallPort = appInfo[@"LSSyscallPort"];
    if(syscallPort != NULL)
    {
        environment_client_connect_to_syscall_proxy(syscallPort);
    }
    
    LCHomePath = NSHomeDirectory();
    if(environmentDictionary) overwriteEnvironmentProperties(environmentDictionary);
    if(argumentDictionary) createArgv(argumentDictionary, &argc, &argv);
    
    if([mode isEqualToString:@"management"])
    {
        environment_init(EnvironmentRoleGuest, EnvironmentExecCustom, nil, 0, nil);

        if(environment_syscall(SYS_SETUID, [appInfo[@"LSUserIdentifier"] unsignedIntValue]) != 0 ||
           environment_syscall(SYS_SETGID, [appInfo[@"LSGroupIdentifier"] unsignedIntValue]) != 0)
        {
            exit(1);
        }
        
        if([service isEqualToString:@"installd"])
        {
            exit(LDEServiceMain(argc, argv, [LDEApplicationWorkspaceProxy class]));
        } else if([service isEqualToString:@"trustd"])
        {
            exit(LDEServiceMain(argc, argv, [LDETrustProxy class]));
        }
    }
    else if([mode isEqualToString:@"spawn"])
    {
        // posix_spawn and similar implementation
        environment_init(EnvironmentRoleGuest, EnvironmentExecLiveContainer, [executablePath UTF8String], argc, argv);
    }
    
    exit(0);
}

// this is our fake UIApplicationMain called from _xpc_objc_uimain (xpc_main)
__attribute__((visibility("default")))
int UIApplicationMain(int argc, char * argv[], NSString * principalClassName, NSString * delegateClassName) {
    return LiveProcessMain(argc, argv);
}

// NSExtensionMain will load UIKit and call UIApplicationMain, so we need to redirect it to our fake one
DEFINE_HOOK(dlopen, void*, (void* dyldApiInstancePtr, const char* path, int mode)) {
    if(path && !strcmp(path, "/System/Library/Frameworks/UIKit.framework/UIKit")) {
        // switch back to original dlopen
        performHookDyldApi("dlopen", 2, (void**)&orig_dlopen, orig_dlopen);
        // FIXME: may be incompatible with jailbreak tweaks?
        return RTLD_MAIN_ONLY;
    } else {
        __attribute__((musttail)) return orig_dlopen(dyldApiInstancePtr, path, mode);
    }
}

void hook_do_nothing(void) {}

// Extension entry point
int NSExtensionMain(int argc, char * argv[]) {
    /* resecure decoder, instead of bluntly removing validation entirely */
    ResecureDecoder();
    
    // hook dlopen UIKit
    performHookDyldApi("dlopen", 2, (void**)&orig_dlopen, hook_dlopen);
    // call the real one
    int (*orig_NSExtensionMain)(int argc, char * argv[]) = dlsym(RTLD_NEXT, "NSExtensionMain");
    return orig_NSExtensionMain(argc, argv);
}
