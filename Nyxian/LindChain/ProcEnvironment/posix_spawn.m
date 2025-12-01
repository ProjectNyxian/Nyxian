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

#import <LindChain/ProcEnvironment/environment.h>
#import <LindChain/ProcEnvironment/proxy.h>
#import <LindChain/ProcEnvironment/posix_spawn.h>
#import <LindChain/litehook/src/litehook.h>
#import <LindChain/LiveContainer/LCUtils.h>
#import <LindChain/LiveContainer/LCAppInfo.h>
#import <LindChain/LiveContainer/ZSign/zsigner.h>
#import <sys/sysctl.h>
#import <LindChain/LiveContainer/Tweaks/libproc.h>
#import <LindChain/ProcEnvironment/Object/MachOObject.h>

#pragma mark - posix_spawn helper

NSArray<NSString *> *createNSArrayFromArgv(int argc, char *const argv[])
{
    if(argc <= 0 || argv == NULL)
    {
        return @[];
    }

    NSMutableArray<NSString *> *array = [NSMutableArray arrayWithCapacity:argc];
    for (int i = 0; i < argc; i++)
    {
        if(argv[i])
        {
            NSString *arg = [NSString stringWithUTF8String:argv[i]];
            if(arg)
            {
                [array addObject:arg];
            }
        }
    }
    return [array copy];
}

NSDictionary *EnvironmentDictionaryFromEnvp(char *const envp[]) {
    if (envp == NULL) {
        return @{};
    }
    
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    
    for (char *const *p = envp; *p != NULL; p++) {
        NSString *entry = [NSString stringWithUTF8String:*p];
        NSRange equalRange = [entry rangeOfString:@"="];
        
        if (equalRange.location != NSNotFound) {
            NSString *key = [entry substringToIndex:equalRange.location];
            NSString *value = [entry substringFromIndex:equalRange.location + 1];
            if (key && value) {
                dict[key] = value;
            }
        }
    }
    
    return [dict copy];
}

char *environment_which(const char *name)
{
    if(!name) return NULL;
    if(strchr(name, '/'))
    {
        if (access(name, X_OK) == 0)
            return realpath(name, NULL);
        return NULL;
    }
    
    char *path = getenv("PATH");
    if (!path) return NULL;
    
    char *copy = strdup(path);
    char *token = strtok(copy, ":");
    while(token)
    {
        char candidate[PATH_MAX];
        snprintf(candidate, sizeof(candidate), "%s/%s", token, name);
        if (access(candidate, X_OK) == 0) {
            free(copy);
            return realpath(candidate, NULL);
        }
        token = strtok(NULL, ":");
    }
    free(copy);
    return NULL;
}

#pragma mark - posix_spawn implementation

int environment_posix_spawn(pid_t *process_identifier,
                            const char *path,
                            const environment_posix_spawn_file_actions_t **fa,
                            const posix_spawnattr_t *spawn_attr,
                            char *const argv[],
                            char *const envp[])
{
    // Getting entitlement list and checking it
    PEEntitlement entitlement = environment_proxy_getprocinfo(ProcessInfoEntitlements);
    if(!(entitlement_got_entitlement(entitlement, PEEntitlementProcessSpawn) |
         entitlement_got_entitlement(entitlement, PEEntitlementProcessSpawnSignedOnly)))
    {
        return -1;
    }
    
    // Fixing executing binaries at relative paths
    char resolved[PATH_MAX];
    realpath(path, resolved);
    path = resolved;
    
    if(environment_is_role(EnvironmentRoleGuest))
    {
        // MARK: GUEST Implementation
        
        // Check code signature
        if(!path) return 1;
        if(!checkCodeSignature(path))
        {
            // Is not valid, sign it by asking the host to sign it
            environment_proxy_sign_macho([NSString stringWithCString:path encoding:NSUTF8StringEncoding]);
            if(!checkCodeSignature(path)) return -1;
        }
        
        // Is argv safe?
        if(argv == NULL) return 1;
        
        // Count argc
        int count = 0;
        while(argv[count] != NULL)
        {
            count++;
        }
        
        // Create fd map object or take it
        FDMapObject *mapObject = fa ? (*fa)->mapObject : [FDMapObject currentMap];
        
        // Now since we have executable path we execute
        pid_t pid = environment_proxy_spawn_process_at_path([NSString stringWithCString:path encoding:NSUTF8StringEncoding],
                                                            createNSArrayFromArgv(count, argv),
                                                            EnvironmentDictionaryFromEnvp(envp),
                                                            mapObject);
        
        if(process_identifier)
        {
            *process_identifier = pid;
        }
    }
    
    return 0;
}

int environment_posix_spawnp(pid_t *process_identifier,
                             const char *path,
                             const environment_posix_spawn_file_actions_t **file_actions,
                             const posix_spawnattr_t *spawn_attr,
                             char *const argv[],
                             char *const envp[])
{
    // Itterates through PATH variable
    // Essentially for dash which uses PATH
    return environment_posix_spawn(process_identifier, environment_which(path), file_actions, spawn_attr, argv, envp);
}

#pragma mark - posix file actions

// MARK: Creation and destruction
int environment_posix_spawn_file_actions_init(environment_posix_spawn_file_actions_t **fa)
{
    // Allocate structure and return
    *fa = malloc(sizeof(environment_posix_spawn_file_actions_t));
    (*fa)->mapObject = [[FDMapObject alloc] init];
    [(*fa)->mapObject copy_fd_map];
    
    return 0;
}

int environment_posix_spawn_file_actions_destroy(environment_posix_spawn_file_actions_t **fa)
{
    // Destroy hidden mapObject
    (*fa)->mapObject = nil;
    free(*fa);
    return 0;
}

// MARK: Management
int environment_posix_spawn_file_actions_adddup2(environment_posix_spawn_file_actions_t **fa,
                                                 int host_fd,
                                                 int child_fd)
{
    return [(*fa)->mapObject dup2WithOldFileDescriptor:host_fd withNewFileDescriptor:child_fd];;
}

int environment_posix_spawn_file_actions_addclose(environment_posix_spawn_file_actions_t **fa,
                                                  int child_fd)
{
    return [(*fa)->mapObject closeWithFileDescriptor:child_fd];
}

#pragma mark - Initilizer

void environment_posix_spawn_init(void)
{
    if(environment_is_role(EnvironmentRoleGuest))
    {
        // MARK: GUEST Init
        
        // MARK: Fixing spawning of child processes
        litehook_rebind_symbol(LITEHOOK_REBIND_GLOBAL, posix_spawn, environment_posix_spawn, nil);
        litehook_rebind_symbol(LITEHOOK_REBIND_GLOBAL, posix_spawnp, environment_posix_spawnp, nil);
        
        // MARK: Fixing file actions, so developers can redirect file descriptors
        litehook_rebind_symbol(LITEHOOK_REBIND_GLOBAL, posix_spawn_file_actions_init, environment_posix_spawn_file_actions_init, nil);
        litehook_rebind_symbol(LITEHOOK_REBIND_GLOBAL, posix_spawn_file_actions_destroy, environment_posix_spawn_file_actions_destroy, nil);
        litehook_rebind_symbol(LITEHOOK_REBIND_GLOBAL, posix_spawn_file_actions_adddup2, environment_posix_spawn_file_actions_adddup2, nil);
        litehook_rebind_symbol(LITEHOOK_REBIND_GLOBAL, posix_spawn_file_actions_addclose, environment_posix_spawn_file_actions_addclose, nil);
    }
}
