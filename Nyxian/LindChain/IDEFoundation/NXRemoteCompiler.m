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

#import <LindChain/IDEFoundation/NXRemoteCompiler.h>
#import <LindChain/ProcEnvironment/PELaunchServiceManager.h>
#import <Nyxian-Swift.h>

@implementation NXRemoteDependencyScanner {
    NXRemoteCompiler *_remoteCompiler;
}

+ (instancetype)dependencyScannerWithRemoteCompiler:(NXRemoteCompiler*)compiler
{
    if(compiler == nil)
    {
        return nil;
    }
    
    NXRemoteDependencyScanner *scanner = [[self alloc] init];
    if(scanner)
    {
        scanner->_remoteCompiler = compiler;
    }
    return scanner;
}

- (NSArray<MDKFile*>*)headerFilesForFile:(MDKFile*)file
{
    return [_remoteCompiler headersForFile:file];
}

- (BOOL)dependenciesForFile:(MDKFile*)file
        withHeaderFilePaths:(NSArray<MDKFile*>**)headerFilePaths
           withDependencies:(NSArray<MDKDependency*>**)dependencies
{
    return [_remoteCompiler dependenciesForFile:file withHeaderFilePaths:headerFilePaths withDependencies:dependencies];
}

+ (Class)class
{
    return [MDKDependencyScanner class];
}

@end

@interface NXRemoteCompiler () <PEProcessObserver>

@end

@implementation NXRemoteCompiler {
    PELaunchServiceInstance *_instance;
    NSXPCConnection *_connection;
    os_unfair_lock _lock;
}

+ (BOOL)isAvailable
{
    return !NXApplicationState.extensionLessMode;
}

+ (instancetype)newRemoteCompiler
{
    if(![self isAvailable])
    {
        return nil;
    }
    
    NXRemoteCompiler *remoteCompiler = [[super alloc] init];
    if(remoteCompiler)
    {
        /* need new launch service instance */
        PELaunchService *service = [[PELaunchServiceManager shared] serviceForIdentifier:@"org.emexlabs.compilerd"];
        if(service == NULL)
        {
            return nil;
        }
        
        remoteCompiler->_instance = [service newInstance];
        if(remoteCompiler->_instance == NULL)
        {
            return nil;
        }
        
        NSXPCListenerEndpoint *endpoint = [remoteCompiler->_instance xpcEndpoint];
        if(endpoint == NULL)
        {
            [remoteCompiler->_instance terminate];
            return nil;
        }
        
        remoteCompiler->_connection = [[NSXPCConnection alloc] initWithListenerEndpoint:endpoint];
        if(remoteCompiler->_connection == NULL)
        {
            [remoteCompiler->_instance terminate];
            return nil;
        }
        
        __weak typeof(remoteCompiler) weakRemoteCompiler = remoteCompiler;
        remoteCompiler->_connection.remoteObjectInterface = [NSXPCInterface interfaceWithProtocol:@protocol(NXCompilationServiceProtocol)];
        remoteCompiler->_connection.invalidationHandler = ^{
            __strong typeof(remoteCompiler) strongRemoteCompiler = weakRemoteCompiler;
            if(strongRemoteCompiler)
            {
                [strongRemoteCompiler->_instance terminate];
            }
        };
        remoteCompiler->_connection.interruptionHandler = ^{
            __strong typeof(remoteCompiler) strongRemoteCompiler = weakRemoteCompiler;
            if(strongRemoteCompiler)
            {
                [strongRemoteCompiler->_instance terminate];
            }
        };
        NSXPCInterface *iface = [NSXPCInterface interfaceWithProtocol:@protocol(NXCompilationServiceProtocol)];
        NSSet *classes = [NSSet setWithObjects: [NSArray class], [MDKFile class], [MDKJob class], [MDKDiagnostic class], [MDKDependency class], [MDKFileSourceLocation class], [NSString class], [NSURL class], nil];
        [iface setClasses:classes forSelector:@selector(executeJob:withReply:) argumentIndex:0 ofReply:NO];
        [iface setClasses:classes forSelector:@selector(executeJob:withReply:) argumentIndex:1 ofReply:YES];
        [iface setClasses:classes forSelector:@selector(headersForFile:withReply:) argumentIndex:0 ofReply:NO];
        [iface setClasses:classes forSelector:@selector(headersForFile:withReply:) argumentIndex:0 ofReply:YES];
        [iface setClasses:classes forSelector:@selector(dependenciesForFile:withReply:) argumentIndex:0 ofReply:NO];
        [iface setClasses:classes forSelector:@selector(dependenciesForFile:withReply:) argumentIndex:1 ofReply:YES];
        [iface setClasses:classes forSelector:@selector(dependenciesForFile:withReply:) argumentIndex:2 ofReply:YES];
        remoteCompiler->_connection.remoteObjectInterface = iface;
        [remoteCompiler->_connection resume];
        
        remoteCompiler->_lock = OS_UNFAIR_LOCK_INIT;
        [remoteCompiler->_instance.process addObserver:remoteCompiler];
    }
    return remoteCompiler;
}

- (BOOL)executeJob:(MDKJob*)job
   withDiagnostics:(NSArray<MDKDiagnostic*>**)diagnostics
    withMainSource:(NSString**)mainSource
{
    os_unfair_lock_lock(&_lock);
    if(_instance == nil)
    {
        if(mainSource)
        {
            *mainSource = job.inputFileURLs[0].path;
        }
        if(diagnostics)
        {
            *diagnostics = @[[MDKDiagnostic diagnosticWithType:MDKDiagnosticTypeInternal level:MDKDiagnosticLevelFatal mainSource:job.inputFileURLs[0].path fileSourceLocation:nil message:@"Couldn't get remote compilation daemon instance."]];
        }
        os_unfair_lock_unlock(&_lock);
        return NO;
    }
    os_unfair_lock_unlock(&_lock);
    
    __block BOOL failed = NO;
    dispatch_semaphore_t sema = dispatch_semaphore_create(0);
    __block BOOL result = NO;
    __block NSArray<MDKDiagnostic*> *resultDiagnostic;
    __block NSString *resultMainSource;
    
    id proxy = [_connection remoteObjectProxyWithErrorHandler:^(NSError *error) {
        /* semaphores remember the signal, it doesnt have to catch them in time */
        failed = YES;
        dispatch_semaphore_signal(sema);
    }];
    
    if(proxy == NULL)
    {
        /* semaphores remember the signal, it doesnt have to catch them in time */
        failed = YES;
        dispatch_semaphore_signal(sema);
    }
    else
    {
        [proxy executeJob:job withReply:^(BOOL successRet, NSArray<MDKDiagnostic*> *diagnosticsRet, NSString *mainSourceRet){
            result = successRet;
            resultDiagnostic = diagnosticsRet;
            resultMainSource = mainSourceRet;
            dispatch_semaphore_signal(sema);
        }];
    }
    
    dispatch_semaphore_wait(sema, DISPATCH_TIME_FOREVER);
    if(failed)
    {
        if(mainSource)
        {
            *mainSource = job.inputFileURLs[0].path;
        }
        if(diagnostics)
        {
            *diagnostics = @[[MDKDiagnostic diagnosticWithType:MDKDiagnosticTypeInternal level:MDKDiagnosticLevelFatal mainSource:job.inputFileURLs[0].path fileSourceLocation:nil message:@"Couldn't keep connection with remote compilation service instance."]];
        }
        os_unfair_lock_lock(&_lock);
        [_instance terminate];
        os_unfair_lock_unlock(&_lock);
        return NO;
    }
    
    if(diagnostics)
    {
        *diagnostics = resultDiagnostic;
    }
    if(mainSource)
    {
        *mainSource = resultMainSource;
    }
    
    return result;
}

- (BOOL)setupDependencyScannerWithArguments:(NSArray<NSString*>*)arguments
{
    os_unfair_lock_lock(&_lock);
    if(_instance == nil)
    {
        os_unfair_lock_unlock(&_lock);
        return NO;
    }
    os_unfair_lock_unlock(&_lock);
    
    __block BOOL failed = NO;
    dispatch_semaphore_t sema = dispatch_semaphore_create(0);
    __block BOOL result = NO;
    
    id proxy = [_connection remoteObjectProxyWithErrorHandler:^(NSError *error) {
        /* semaphores remember the signal, it doesnt have to catch them in time */
        failed = YES;
        dispatch_semaphore_signal(sema);
    }];
    
    if(proxy == NULL)
    {
        /* semaphores remember the signal, it doesnt have to catch them in time */
        failed = YES;
        dispatch_semaphore_signal(sema);
    }
    else
    {
        [proxy setupDependencyScannerWithArguments:arguments withReply:^(BOOL success){
            result = success;
            dispatch_semaphore_signal(sema);
        }];
    }
    
    dispatch_semaphore_wait(sema, DISPATCH_TIME_FOREVER);
    if(failed)
    {
        os_unfair_lock_lock(&_lock);
        [_instance terminate];
        os_unfair_lock_unlock(&_lock);
        return NO;
    }
    
    return result;
}

- (NSArray<MDKFile*>*)headersForFile:(MDKFile*)file
{
    os_unfair_lock_lock(&_lock);
    if(_instance == nil)
    {
        os_unfair_lock_unlock(&_lock);
        return nil;
    }
    os_unfair_lock_unlock(&_lock);
    
    __block BOOL failed = NO;
    dispatch_semaphore_t sema = dispatch_semaphore_create(0);
    __block NSArray<MDKFile*> *result = nil;
    
    id proxy = [_connection remoteObjectProxyWithErrorHandler:^(NSError *error) {
        /* semaphores remember the signal, it doesnt have to catch them in time */
        failed = YES;
        dispatch_semaphore_signal(sema);
    }];
    
    if(proxy == NULL)
    {
        /* semaphores remember the signal, it doesnt have to catch them in time */
        failed = YES;
        dispatch_semaphore_signal(sema);
    }
    else
    {
        [proxy headersForFile:file withReply:^(NSArray<MDKFile*> *files){
            result = files;
            dispatch_semaphore_signal(sema);
        }];
    }
    
    dispatch_semaphore_wait(sema, DISPATCH_TIME_FOREVER);
    if(failed)
    {
        os_unfair_lock_lock(&_lock);
        [_instance terminate];
        os_unfair_lock_unlock(&_lock);
        return nil;
    }
    
    return result;
}

- (BOOL)dependenciesForFile:(MDKFile*)file
        withHeaderFilePaths:(NSArray<MDKFile*>**)headerFilePaths
           withDependencies:(NSArray<MDKDependency*>**)dependencies
{
    os_unfair_lock_lock(&_lock);
    if(_instance == nil)
    {
        os_unfair_lock_unlock(&_lock);
        return nil;
    }
    os_unfair_lock_unlock(&_lock);
    
    __block BOOL failed = NO;
    dispatch_semaphore_t sema = dispatch_semaphore_create(0);
    __block BOOL result = false;
    __block NSArray<MDKFile*> *outHeaders;
    __block NSArray<MDKDependency*> *outDependencies;
    
    id proxy = [_connection remoteObjectProxyWithErrorHandler:^(NSError *error) {
        /* semaphores remember the signal, it doesnt have to catch them in time */
        failed = YES;
        dispatch_semaphore_signal(sema);
    }];
    
    if(proxy == NULL)
    {
        /* semaphores remember the signal, it doesnt have to catch them in time */
        failed = YES;
        dispatch_semaphore_signal(sema);
    }
    else
    {
        [proxy dependenciesForFile:file withReply:^(BOOL success, NSArray<MDKFile*> *hdrs, NSArray<MDKDependency*> *deps){
            result = success;
            outHeaders = hdrs;
            outDependencies = deps;
            dispatch_semaphore_signal(sema);
        }];
    }
    
    dispatch_semaphore_wait(sema, DISPATCH_TIME_FOREVER);
    if(failed)
    {
        os_unfair_lock_lock(&_lock);
        [_instance terminate];
        os_unfair_lock_unlock(&_lock);
        return nil;
    }
    
    if(headerFilePaths != nil)
    {
        *headerFilePaths = outHeaders;
    }
    if(dependencies != nil)
    {
        *dependencies = outDependencies;
    }
    
    return result;
}

- (MDKDependencyScanner*)dependencyScanner
{
    return (MDKDependencyScanner*)[NXRemoteDependencyScanner dependencyScannerWithRemoteCompiler:self];
}

- (void)process:(PEProcess *)process didExitWithWait4Code:(int)code
{
    os_unfair_lock_lock(&_lock);
    _instance = NULL;
    os_unfair_lock_unlock(&_lock);
}

- (void)dealloc
{
    os_unfair_lock_lock(&_lock);
    [_instance.process removeObserver:self];
    [_instance terminate];
    os_unfair_lock_unlock(&_lock);
}

@end
