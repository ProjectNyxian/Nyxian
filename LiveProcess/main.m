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

+ (NSExtensionContext *)extensionContext
{
    return extensionContext;
}

+ (NSDictionary *)retrievedAppInfo
{
    return retrievedAppInfo;
}

- (void)beginRequestWithExtensionContext:(NSExtensionContext *)context
{
    extensionContext = context;
    retrievedAppInfo = [context.inputItems.firstObject userInfo];
    /* returns control back to LiveContainerMain */
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
    if(enviroDict)
    {
        clear_environment();
        
        for (NSString *key in enviroDict)
        {
            NSString *value = enviroDict[key];
            setenv([key UTF8String], [value UTF8String], 0);
        }
    }
}

void overwriteArguments(NSArray<NSObject<NSSecureCoding,NSCopying>*> *arguments,
                        int *argc,
                        char ***argv)
{
    assert(argc != NULL && argv != NULL);
    
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wundeclared-selector"
    [NSProcessInfo.processInfo performSelector:@selector(setArguments:) withObject:arguments ? arguments : @[]];
#pragma clang diagnostic pop
    
    if(!arguments || arguments.count < 1)
    {
        *argc = 0;
        return;
    }
    
    NSInteger count = arguments.count;
    *argc = (int)count;
    
    *argv = malloc(sizeof(char *) * (count + 1));
    for(NSInteger i = 0; i < count; i++)
    {
        NSObject<NSSecureCoding,NSCopying> *arg = arguments[i];
        
        if([arg isKindOfClass:[NSString class]])
        {
            (*argv)[i] = strdup(((NSString*)arg).UTF8String);
        }
    }
    (*argv)[count] = NULL;
}

int LiveProcessMain(int argc, char *argv[])
{
    /* let NSExtensionContext initialize, once it's done it will call CFRunLoopStop */
    CFRunLoopRun();
    NSDictionary *appInfo = LiveProcessHandler.retrievedAppInfo;
    
    NSXPCListenerEndpoint* endpoint = appInfo[@"PEEndpoint"];
    NSString* executablePath = appInfo[@"PEExecutablePath"];
    NSString *service = appInfo[@"PEIntegratedServiceClass"];
    NSDictionary *environmentDictionary = appInfo[@"PEEnvironment"];
    NSArray *argumentDictionary = appInfo[@"PEArguments"];
    FDMapObject *mapObject = appInfo[@"PEMapObject"];
    MachPortObject *syscallPort = appInfo[@"PESyscallPort"];
    NSString *workingDirectory = appInfo[@"PEWorkingDirectory"];
    
    assert(endpoint != nil && executablePath != nil && syscallPort != nil);
    
    /* setting working directory correctly */
    if(workingDirectory != nil &&
       [workingDirectory isKindOfClass:[NSString class]])
    {
        /* was passed, setting to destination */
        chdir([workingDirectory UTF8String]);
    }
    else
    {
        /* wasnt passed, setting to root */
        chdir([[NSHomeDirectory() stringByAppendingPathComponent:@"/Documents"] UTF8String]);
    }
    
    if(mapObject != nil &&
       [mapObject isKindOfClass:[FDMapObject class]])
    {
        /* apply file descriptor map passed from host environment */
        [mapObject apply_fd_map];
        setvbuf(stdout, NULL, _IONBF, 0);
        setvbuf(stderr, NULL, _IONBF, 0);
    }
    
    /*
     * connecting to the host environment which serves
     * the guest environment.
     */
    environment_client_connect_to_host(endpoint);
    environment_client_connect_to_syscall_proxy(syscallPort);
    
    /* overwriting environment and arguments */
    overwriteEnvironmentProperties(environmentDictionary);
    overwriteArguments(argumentDictionary, &argc, &argv);
    
    if(service != nil)
    {
        /*
         * custom execution, because daemons arent dylibified
         * executables yet but its a TODO already to dylibify
         * them and separate them more from Nyxians main
         * codebase.
         */
        environment_init(EnvironmentExecCustom, executablePath, argc, argv);

        /*
         * first ever step is to elevate their permitives as
         * they are usually platformized, but they shall also
         * gain higher permitives.
         */
        if(environment_syscall(SYS_setuid, [appInfo[@"PEUserIdentifier"] unsignedIntValue]) != 0 ||
           environment_syscall(SYS_setgid, [appInfo[@"PEGroupIdentifier"] unsignedIntValue]) != 0)
        {
            return 1;
        }
        
        /*
         * we get the class of the daemon, internal Nyxian
         * daemons name their class within their launch
         * service file.
         */
        Class ServiceClass = NSClassFromString(service);
        
        if(ServiceClass == nil)
        {
            return 1;
        }
        
        return PEServiceMain(argc, argv, ServiceClass);
    }
    else
    {
        /*
         * path for normal spawns (they go through LC, thanks to
         * Duy Tran and his research <3), anyways this goes through
         * LC and when the main symbol returns then we get its return
         * value which we redirect to the env.
         */
        return environment_init(EnvironmentExecLiveContainer, executablePath, argc, argv);
    }
    
    return 1;
}

/* this is our fake UIApplicationMain called from _xpc_objc_uimain (xpc_main) */
__attribute__((visibility("default")))
int UIApplicationMain(int argc, char * argv[], NSString * principalClassName, NSString * delegateClassName)
{
    /* executes the target and exits */
    int retval = LiveProcessMain(argc, argv);
    
    /* redirecting exit status to ksurface and XNU */
    environment_syscall(SYS_exit, retval);
    exit(retval);   /* fatal */
}

/* NSExtensionMain will load UIKit and call UIApplicationMain, so we need to redirect it to our fake one */
DEFINE_HOOK(dlopen, void*, (void* dyldApiInstancePtr, const char* path, int mode))
{
    if(path && !strcmp(path, "/System/Library/Frameworks/UIKit.framework/UIKit"))
    {
        /* switch back to original dlopen */
        performHookDyldApi("dlopen", 2, (void**)&orig_dlopen, orig_dlopen);
        /* FIXME: may be incompatible with jailbreak tweaks? */
        return RTLD_MAIN_ONLY;
    }
    else
    {
        __attribute__((musttail)) return orig_dlopen(dyldApiInstancePtr, path, mode);
    }
}

/* Extension entry point */
int NSExtensionMain(int argc, char * argv[])
{
    /* resecure decoder, instead of bluntly removing validation entirely */
    ResecureDecoder();
    
    /*
     * hook dlopen to catch UIKit framework load and trick it
     * into thinking that our UIApplicationMain is the real
     * legitimate one
     */
    performHookDyldApi("dlopen", 2, (void**)&orig_dlopen, hook_dlopen);
    
    /*
     * call the real NSExtensionMain, which calls
     * then our UIApplicationMain.
     */
    int (*orig_NSExtensionMain)(int argc, char * argv[]) = dlsym(RTLD_NEXT, "NSExtensionMain");
    return orig_NSExtensionMain(argc, argv);
}
