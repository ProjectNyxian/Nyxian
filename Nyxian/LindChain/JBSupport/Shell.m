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

#import <LindChain/JBSupport/Shell.h>
#import <LindChain/JBSupport/jbroot.h>
#import <Foundation/Foundation.h>
#import <Nyxian-Swift.h>
#include <spawn.h>

extern int posix_spawnattr_set_persona_np(posix_spawnattr_t *attr, uid_t persona_id, uint32_t flags);
extern int posix_spawnattr_set_persona_uid_np(posix_spawnattr_t *attr, uid_t uid);
extern int posix_spawnattr_set_persona_gid_np(posix_spawnattr_t *attr, uid_t gid);

void createArgv(NSString *executableName,
                NSArray<NSString *> *arguments,
                int *argc,
                char ***argv)
{
    if(!arguments)
    {
        *argc = 0;
        return;
    }
    
    NSInteger count = arguments.count + 1;
    *argc = (int)count;
    
    *argv = malloc(sizeof(char *) * (count + 1));
    (*argv)[0] = strdup([executableName UTF8String]);
    for(NSInteger i = 0; i < arguments.count; i++)
    {
        (*argv)[i + 1] = strdup(arguments[i].UTF8String);
    }
    (*argv)[count] = NULL;
}

void createEnvp(NSArray<NSString *> *environment,
                int *envCount,
                char ***envp)
{
    if(!environment)
    {
        *envCount = 0;
        *envp = NULL;
        return;
    }

    NSInteger count = environment.count;
    *envCount = (int)count;

    *envp = malloc(sizeof(char *) * (count + 1));
    for(NSInteger i = 0; i < count; i++)
    {
        (*envp)[i] = strdup([environment[i] UTF8String]);
    }
    (*envp)[count] = NULL;
}


static int runCommand(NSString *command,
                      NSArray<NSString *> *args,
                      uid_t uid,
                      NSArray<NSString *> *extraEnv,
                      NSString **output)
{
    pid_t pid = 0;

    NSString *execName = command.lastPathComponent;
    NSMutableArray<NSString *> *argvStrings = [NSMutableArray arrayWithObject:execName];
    [argvStrings addObjectsFromArray:args];

    int argc = 0;
    char **argv = NULL;
    
    createArgv(command, args, &argc, &argv);
    
    NSString *jbroot = IGottaNeedTheActualJBRootMate();
    NSArray *baseEnv = @[
        [NSString stringWithFormat:
        @"PATH=/usr/local/sbin:%@/usr/local/sbin:/usr/local/bin:%@/usr/local/bin:/usr/sbin:%@/usr/sbin:/usr/bin:%@/usr/bin:/sbin:%@/sbin:/bin:%@/bin:/usr/bin/X11:%@/usr/bin/X11:/usr/games:%@/usr/games", jbroot, jbroot, jbroot, jbroot, jbroot, jbroot, jbroot, jbroot],
        [NSString stringWithFormat:@"HOME=%@", NSHomeDirectory()],
        [NSString stringWithFormat:@"TMPDIR=%@", NSTemporaryDirectory()]
    ];

    NSMutableArray *envStrings = [NSMutableArray arrayWithArray:baseEnv];
    if(extraEnv)
    {
        [envStrings addObjectsFromArray:extraEnv];
    }

    int envc = 0;
    char **envp = NULL;
    createEnvp(envStrings, &envc, &envp);
    
    int outPipe[2];
    pipe(outPipe);
    
    posix_spawn_file_actions_t actions;
    posix_spawn_file_actions_init(&actions);
    posix_spawn_file_actions_adddup2(&actions, outPipe[1], STDOUT_FILENO);
    posix_spawn_file_actions_adddup2(&actions, outPipe[1], STDERR_FILENO);
    posix_spawn_file_actions_addclose(&actions, outPipe[0]);
    
    posix_spawnattr_t attr;
    posix_spawnattr_init(&attr);

    posix_spawnattr_set_persona_np(&attr, 99, 1);
    posix_spawnattr_set_persona_uid_np(&attr, uid);
    posix_spawnattr_set_persona_gid_np(&attr, uid);

    int result = posix_spawn(&pid,
                             [[jbroot stringByAppendingString:command] UTF8String],
                             &actions,
                             &attr,
                             (char * const *)argv,
                             (char * const *)envp);

    posix_spawnattr_destroy(&attr);
    
    int status = 0;

    if(result != 0)
    {
        NSLog(@"Failed to spawn process");
        goto cleanup;
    }

    waitpid(pid, &status, 0);

cleanup:
    close(outPipe[1]);
    
    NSMutableData *outputData = [NSMutableData data];
    char buffer[1024];
    ssize_t bytesRead;
    
    while ((bytesRead = read(outPipe[0], buffer, sizeof(buffer))) > 0) {
        [outputData appendBytes:buffer length:bytesRead];
    }
    
    close(outPipe[0]);
    
    if(output != nil)
    {
        *output = [[NSString alloc] initWithData:outputData encoding:NSUTF8StringEncoding];
    }
    
    for(int i = 0; i < argc; i++)
    {
        free(argv[i]);
    }
    for(int i = 0; i < envc; i++)
    {
        free(envp[i]);
    }

    return result == 0 ? status : -1;
}


int shell(NSString *command, uid_t uid, NSArray<NSString *> *env, NSString **output)
{
    return runCommand(@"/usr/bin/bash", @[ @"-e", @"-c", command], uid ?: 0, env ?: @[], output);
}

