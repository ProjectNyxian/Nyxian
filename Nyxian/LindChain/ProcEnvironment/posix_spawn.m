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

#import <LindChain/ProcEnvironment/environment.h>
#import <LindChain/ProcEnvironment/proxy.h>
#import <LindChain/ProcEnvironment/posix_spawn.h>
#import <LindChain/litehook/litehook.h>
#import <LindChain/LiveContainer/LCUtils.h>
#import <LindChain/LiveContainer/ZSign/zsigner.h>
#import <sys/sysctl.h>
#import <LindChain/LiveContainer/Tweaks/libproc.h>
#import <LindChain/ProcEnvironment/Object/MachOObject.h>
#import <LindChain/ProcEnvironment/syscall.h>

#pragma mark - posix_spawn helper

NSArray<NSObject<NSSecureCoding,NSCopying> *> *createNSArrayFromArgv(char *const argv[])
{
    /* sanity check */
    if(argv == NULL)
    {
        return @[];
    }
    
    int argc = 0;
    while(argv[argc] != NULL)
    {
        argc++;
    }
    
    /* creating mutable array with predefined argv lenght  */
    NSMutableArray<NSObject<NSSecureCoding,NSCopying> *> *array = [NSMutableArray arrayWithCapacity:argc];
    
    /*
     * itterating through each argument and stuff the mutable
     * array with each argument.
     */
    for(int i = 0; i < argc; i++)
    {
        NSObject<NSSecureCoding,NSCopying> *arg = nil;
        
        if(argv[i] != NULL)
        {
            /* converting C into NSString */
            arg = [NSString stringWithCString:argv[i] encoding:NSUTF8StringEncoding];
        }
        else
        {
            arg = [NSNull null];
        }
        
        /* sanity checking arg object */
        if(arg != NULL)
        {
            /* and obviously appending it */
            [array addObject:arg];
        }
    }
    
    /* return immutable array */
    return [array copy];
}

NSDictionary *EnvironmentDictionaryFromEnvp(char *const envp[])
{
    /* sanity check */
    if(envp == NULL)
    {
        return @{};
    }
    
    /* creating mutable dictionary */
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    
    /*
     * itterating through each environment variable
     * to convert it into ObjC.
     */
    for(char *const *p = envp; *p != NULL; p++)
    {
        /*
         * converting entire environment variable into
         * ObjC object.
         */
        NSString *entry = [NSString stringWithCString:*p encoding:NSUTF8StringEncoding];
        
        /* sanity check */
        if(entry == NULL)
        {
            continue;
        }
        
        /* getting range till equation */
        NSRange equalRange = [entry rangeOfString:@"="];
        
        if(equalRange.location == NSNotFound)
        {
            continue;
        }
        
        /* crafting other properties  */
        NSString *key = [entry substringToIndex:equalRange.location];
        NSString *value = [entry substringFromIndex:equalRange.location + 1];
            
        /* sanity check */
        if(key && value)
        {
            dict[key] = value;
        }
    }
    
    return [dict copy];
}

char *environment_which(const char *name)
{
    /* sanity check */
    if(name == NULL)
    {
        return NULL;
    }
    
    /*
     * checking weither slash exists
     * in the character buffer.
     */
    if(strchr(name, '/'))
    {
        if(access(name, X_OK) != 0)
        {
            return NULL;
        }
        return realpath(name, NULL);
    }
    
    /*
     * getting "PATH" environment variable,
     * because "PATH" contains all binary
     * search paths where binaries could
     * be located.
     */
    const char *path = getenv("PATH");
    
    /* sanity check */
    if(!path)
    {
        return NULL;
    }
    
    /* create modifable copy of path */
    char *copy = strdup(path);
    
    /* sanity checking copy */
    if(copy == NULL)
    {
        return NULL;
    }
    
    /* here we go */
    char *token = strtok(copy, ":");
    while(token)
    {
        char candidate[PATH_MAX];
        snprintf(candidate, sizeof(candidate), "%s/%s", token, name);
        if(access(candidate, X_OK) == 0)
        {
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
                            const posix_spawn_file_actions_t *fa,
                            const posix_spawnattr_t *spawn_attr,
                            char *const argv[],
                            char *const envp[])
{    
    /* resolving path of executable */
    char resolved[PATH_MAX];
    realpath(path, resolved);
    
    if(environment_is_role(EnvironmentRoleGuest))
    {
        /* checking code signature of resolved binary */
        if(!checkCodeSignature(resolved))
        {
            /* attempt signing */
            int ret = (int)environment_syscall(SYS_signexec, resolved);
            
            if(ret != 0)
            {
                return ret;
            }
            
            /* checking if kernel virt signed executable */
            if(!checkCodeSignature(resolved))
            {
                return -1;
            }
            
            /* for some reason we get a iOS panic otherwise */
            if(![FDObject forceVnodeReassignment:[NSString stringWithCString:resolved encoding:NSUTF8StringEncoding]])
            {
                return -1;
            }
        }
        
        /* create fd map object or take it */
        FDMapObject *mapObject = [FDMapObject currentMap];
        
        /* getting cwd */
        char cwd[PATH_MAX] = {};
        
        if(fa == NULL)
        {
            goto skip_fileactions;
        }
        
        /* interpretting file actions :3c */
        _posix_spawn_file_actions_t *faPtr = (_posix_spawn_file_actions_t*)fa;
        
        for(uint64_t i = 0; i < (*faPtr)->psfa_act_count; i++)
        {
            switch((*faPtr)->psfa_act_acts[i].psfaa_type)
            {
                case PSFA_OPEN:
                    [mapObject openWithFileDescriptor:(*faPtr)->psfa_act_acts[i].psfaa_filedes withPath:(*faPtr)->psfa_act_acts[i].psfaa_openargs.psfao_path withFlags:(*faPtr)->psfa_act_acts[i].psfaa_openargs.psfao_oflag withMode:(*faPtr)->psfa_act_acts[i].psfaa_openargs.psfao_mode];
                    break;
                case PSFA_CLOSE:
                    [mapObject closeWithFileDescriptor:(*faPtr)->psfa_act_acts[i].psfaa_filedes];
                    break;
                case PSFA_DUP2:
                    [mapObject dup2WithOldFileDescriptor:(*faPtr)->psfa_act_acts[i].psfaa_filedes withNewFileDescriptor:(*faPtr)->psfa_act_acts[i].psfaa_dup2args.psfad_newfiledes];
                    break;
                case PSFA_INHERIT:
                    [mapObject appendFileDescriptor:(*faPtr)->psfa_act_acts[i].psfaa_filedes];
                    break;
                case PSFA_FILEPORT_DUP2:
                    /* S0n */
                    break;
                case PSFA_CHDIR:
                    /* not available on iOS but shrug, add it anyways */
                    strlcpy(cwd, (*faPtr)->psfa_act_acts[i].psfaa_chdirargs.psfac_path, PATH_MAX);
                    break;
                case PSFA_FCHDIR:
                    /* S0n */
                    break;
            }
        }
        
    skip_fileactions:
        if(cwd[0] == '\0')
        {
            getcwd(cwd, PATH_MAX);
        }
        
        NSString *nsCwd = [NSString stringWithCString:cwd encoding:NSUTF8StringEncoding];
        
        /* trying to spawn process */
        int64_t pid = environment_proxy_spawn_process_at_path([NSString stringWithCString:resolved encoding:NSUTF8StringEncoding], createNSArrayFromArgv(argv), EnvironmentDictionaryFromEnvp(envp), mapObject, nsCwd);
        
        /* return (if its negative then its not a valid pid) */
        if(pid == -1)
        {
            return -1;
        }
        
        /* sanity check */
        if(process_identifier != NULL)
        {
            *process_identifier = (pid_t)pid;
        }
        
        /*
         * shitty soloution for now (to for now fix waitpid)
         * most delay was fixed by making sure it runs
         * synchronised but this doesnt run synchronised..
         * meaning SYS_gettask.
         */
        usleep(50000);
    }
    
    return 0;
}

int environment_posix_spawnp(pid_t *process_identifier,
                             const char *path,
                             const posix_spawn_file_actions_t *fa,
                             const posix_spawnattr_t *spawn_attr,
                             char *const argv[],
                             char *const envp[])
{
    /* calling the actual posix_spawn() fix but with environment_which(1) */
    return environment_posix_spawn(process_identifier, environment_which(path), fa, spawn_attr, argv, envp);
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
    }
}
