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

#import <Foundation/Foundation.h>
#import <LindChain/ProcEnvironment/Object/FDMapObject.h>
#import <LindChain/ProcEnvironment/environment.h>
#import <LindChain/ProcEnvironment/proxy.h>
#import <LindChain/ProcEnvironment/posix_spawn.h>
#import <LindChain/litehook/litehook.h>
#import <LindChain/LiveContainer/LCUtils.h>
#import <LindChain/LiveContainer/ZSign/zsigner.h>
#import <LindChain/LiveContainer/Tweaks/libproc.h>
#import <LindChain/ProcEnvironment/Object/MachOObject.h>
#import <LindChain/ProcEnvironment/syscall.h>
#import <fcntl.h>

#pragma mark - posix_spawn helper

// copy, remove and rename back the file to prevent crash due to kernel signature cache
// see https://developer.apple.com/documentation/security/updating-mac-software
void refreshFile(const char* path)
{
    NSString* objcPath = @(path);
    if(![NSFileManager.defaultManager fileExistsAtPath:objcPath]) {
        return;
    }
    NSString* newPath = [NSString stringWithFormat:@"%s.tmp", path];
    NSError* error;
    [NSFileManager.defaultManager copyItemAtPath:objcPath toPath:newPath error:&error];
    [NSFileManager.defaultManager removeItemAtPath:objcPath error:&error];
    [NSFileManager.defaultManager moveItemAtPath:newPath toPath:objcPath error:&error];
}

NSArray<NSString*> *NSArrayFromCArray(char *const argv[])
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
        
        /* converting C into NSString */
        arg = [NSString stringWithCString:argv[i] encoding:NSUTF8StringEncoding];
        
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

NSDictionary<NSString*,NSString*> *NSDictionaryFromCDictionary(char *const envp[])
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
        if(key &&
           value)
        {
            dict[key] = value;
        }
    }
    
    return [dict copy];
}

#pragma mark - posix_spawn implementation

int environment_posix_spawn(pid_t *process_identifier,
                            const char *path,
                            const posix_spawn_file_actions_t *fa,
                            const posix_spawnattr_t *spawn_attr,
                            char *const argv[],
                            char *const envp[])
{    
    /*
     * resolving realpath of the executable, to prevent
     * weird file bugs to happen, this is standard
     * apple validity. I got no idea tbh.
     */
    char *resolved = realpath(path, NULL);
    
    if(resolved == NULL)
    {
        /* errno comes from realpath */
        return errno;
    }
    
    /*
     * checking code signature of resolved binary,
     * otherwise it wont be able to run.
     */
    if(!checkCodeSignature(resolved))
    {
        /* attempt signing */
        int ret = (int)environment_syscall(SYS_pectl, PECTL_CS_SIGN_PATH, resolved, MACH_PORT_NULL);
        
        if(ret != 0)
        {
            /* errno comes from the syscall in this case */
            goto out_free_resolved;
        }
        
        /* for some reason we get a iOS kernel panic otherwise */
        refreshFile([NSString stringWithCString:resolved encoding:NSUTF8StringEncoding].fileSystemRepresentation);
        
        /*
         * checking if kernel virt actually signed
         * executable.
         */
        if(!checkCodeSignature(resolved))
        {
            errno = ENOEXEC;
        out_free_resolved:
            free(resolved);
            return errno;
        }
    }
    
    /*
     * create new map object of all current file descriptors,
     * because they are by default inherited by the new child
     * process which is expected behaviour. the file actions
     * can alter that stabily.
     */
    FDMapObject *mapObject = [FDMapObject currentMap];
    
    /*
     * nullified cwd buffer, because of the case where a posix
     * file actions sets the buffer via PSFA_CHDIR, if not we
     * retrieve the cwd and use it instead
     * as the cwd of the child process, which is expected posix
     * behaviour.
     */
    char cwd[PATH_MAX] = {};
    
    if(fa == NULL)
    {
        /* preventing a NULL ptr deref. */
        goto skip_fileactions;
    }
    
    /* interpretting file actions :3c */
    _posix_spawn_file_actions_t *faPtr = (_posix_spawn_file_actions_t*)fa;
    
    for(uint64_t i = 0; i < (*faPtr)->psfa_act_count; i++)
    {
        _psfa_action_t *action = &((*faPtr)->psfa_act_acts[i]);
        
        /* TODO: handle failure */
        switch((*faPtr)->psfa_act_acts[i].psfaa_type)
        {
            case PSFA_OPEN:
                [mapObject openWithFileDescriptor:action->psfaa_filedes withPath:action->psfaa_openargs.psfao_path withFlags:action->psfaa_openargs.psfao_oflag withMode:action->psfaa_openargs.psfao_mode];
                break;
            case PSFA_CLOSE:
                [mapObject closeWithFileDescriptor:action->psfaa_filedes];
                break;
            case PSFA_DUP2:
                [mapObject dup2WithOldFileDescriptor:action->psfaa_filedes withNewFileDescriptor:action->psfaa_dup2args.psfad_newfiledes];
                break;
            case PSFA_INHERIT:
                [mapObject appendFileDescriptor:action->psfaa_filedes];
                break;
            case PSFA_FILEPORT_DUP2:
                [mapObject appendFilePort:action->psfaa_fileport withMappingToLoc:action->psfaa_dup2args.psfad_newfiledes];
                break;
            case PSFA_CHDIR:
                /* not available on iOS but shrug, add it anyways */
                strlcpy(cwd, action->psfaa_chdirargs.psfac_path, PATH_MAX);
                break;
            case PSFA_FCHDIR:
            {
                /* not available on iOS but shrug, add it anyways */
                char path[PATH_MAX];
                if(fcntl(action->psfaa_filedes, F_GETPATH, path) != -1)
                {
                    strlcpy(cwd, path, PATH_MAX);
                }
                break;
            }
            default:
                break;
        }
    }
    
skip_fileactions:
    
    if(cwd[0] == '\0')
    {
        getcwd(cwd, PATH_MAX);
    }
    
    /* the old ServerSession api requires paths as NSString */
    NSString *nsCwd = [NSString stringWithCString:cwd encoding:NSUTF8StringEncoding];
    
    if(nsCwd == nil)
    {
        free(resolved);
        return EAGAIN;
    }
    
    /*
     * trying to spawn process via old ass ServerSession API, which
     * then triggers the subsystem LDEProcess on the host side.
     */
    int64_t pid = environment_proxy_spawn_process_at_path([NSString stringWithCString:resolved encoding:NSUTF8StringEncoding], NSArrayFromCArray(argv), NSDictionaryFromCDictionary(envp), mapObject, nsCwd);
    
    /* it shouldnt be negative */
    if(pid < 0)
    {
        /* lacking entitlements? */
        free(resolved);
        return EPERM;
    }
    
    /* overwriting passed process identifier pointer if applicable */
    if(process_identifier != NULL)
    {
        *process_identifier = (pid_t)pid;
    }
    
    environment_syscall(SYS_waittask, pid);
    
    free(resolved);
    return 0;
}

/*
 * https://github.com/Apple-FOSS-Mirror/Libc/blob/2ca2ae74647714acfc18674c3114b1a5d3325d7d/sys/posix_spawn.c#L1358
 *
 * skidded from apple them selves..
 */
int environment_posix_spawnp(pid_t * __restrict pid,
                             const char * __restrict file,
                             const posix_spawn_file_actions_t *file_actions,
                             const posix_spawnattr_t * __restrict attrp,
                             char *const argv[ __restrict],
                             char *const envp[ __restrict])
{
    const char *env_path;
    char *bp;
    char *cur;
    char *p;
    int lp;
    int ln;
    int err = 0;
    int eacces = 0;
    struct stat sb;
    char path_buf[PATH_MAX];
    
    if((env_path = getenv("PATH")) == NULL)
    {
        env_path = "/";
    }
    
    /* If it's an absolute or relative path name, it's easy. */
    if(index(file, '/'))
    {
        bp = (char *)file;
        cur = NULL;
        goto retry;
    }
    
    bp = path_buf;
    
    /* If it's an empty path name, fail in the usual POSIX way. */
    if(*file == '\0')
    {
        return ENOENT;
    }
    
    if((cur = alloca(strlen(env_path) + 1)) == NULL)
    {
        return ENOMEM;
    }
    
    strcpy(cur, env_path);
    
    while((p = strsep(&cur, ":")) != NULL)
    {
        /*
         * It's a SHELL path -- double, leading and trailing colons
         * mean the current directory.
         */
        if(*p == '\0')
        {
            p = ".";
            lp = 1;
        }
        else
        {
            lp = (int)strlen(p);
        }
        ln = (int)strlen(file);
        
        /*
         * If the path is too long complain.  This is a possible
         * security issue; given a way to make the path too long
         * the user may spawn the wrong program.
         */
        if(lp + ln + 2 > sizeof(path_buf))
        {
            err = ENAMETOOLONG;
            goto done;
        }
        
        bcopy(p, path_buf, lp);
        path_buf[lp] = '/';
        bcopy(file, path_buf + lp + 1, ln);
        path_buf[lp + ln + 1] = '\0';
        
    retry:
        err = environment_posix_spawn(pid, bp, file_actions, attrp, argv, envp);
        switch(err)
        {
            case E2BIG:
            case ENOMEM:
            case ETXTBSY:
                goto done;
            case ELOOP:
            case ENAMETOOLONG:
            case ENOENT:
            case ENOTDIR:
                break;
            case ENOEXEC:
                goto done;
            default:
                /*
                 * EACCES may be for an inaccessible directory or
                 * a non-executable file.  Call stat() to decide
                 * which.  This also handles ambiguities for EFAULT
                 * and EIO, and undocumented errors like ESTALE.
                 * We hope that the race for a stat() is unimportant.
                 */
                if(stat(bp, &sb) != 0)
                {
                    break;
                }
                
                if(err == EACCES)
                {
                    eacces = 1;
                    continue;
                }
                
                goto done;
        }
    }
    
    err = eacces ? EACCES : ENOENT;
    
done:
    return err;
}

#pragma mark - Initilizer

void environment_posix_spawn_init(void)
{
    litehook_rebind_symbol(LITEHOOK_REBIND_GLOBAL, posix_spawn, environment_posix_spawn, nil);
    litehook_rebind_symbol(LITEHOOK_REBIND_GLOBAL, posix_spawnp, environment_posix_spawnp, nil);
}
