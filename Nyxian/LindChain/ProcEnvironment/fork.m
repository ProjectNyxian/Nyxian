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

#import <LindChain/ProcEnvironment/fork.h>
#import <LindChain/ProcEnvironment/environment.h>
#import <LindChain/ProcEnvironment/syscall.h>
#import <LindChain/litehook/src/litehook.h>
#include <mach/mach.h>
#import <pthread.h>
#include <stdarg.h>

#pragma mark - Threading black magic

extern char **environ;

__thread fork_thread_snapshot_t *local_fork_thread_snapshot = NULL;

void *fork_helper_thread(void *args)
{
    // Get snapshot
    fork_thread_snapshot_t *snapshot = args;
    
    if(snapshot->fork_flag)
    {
        // MARK: This means the spawn was essentially requested
        // Safe thread state
        snapshot->thread_count = ARM_THREAD_STATE64_COUNT;
        thread_act_t thread = snapshot->thread;
        thread_get_state(snapshot->thread, ARM_THREAD_STATE64, (thread_state_t)(&snapshot->thread_state), &snapshot->thread_count); // When ever we set the state back we need to set the PC counter to a other function, it will return normally to the caller, thats for sure.. because we dont create a new stack frame, we dont hit ret in this state for it it looks like its still in helper_thread
        
        // Get stack properties
        pthread_t pthread = pthread_from_mach_thread_np(snapshot->thread);
        void *stack_base = pthread_get_stackaddr_np(pthread);
        void *sp = (void*)snapshot->thread_state.__sp;
        
        // Store live portion of the stack (safer and faster)
        snapshot->stack_recovery_buffer = (uint8_t *)sp;
        snapshot->stack_recovery_size = (uint8_t *)stack_base - (uint8_t *)sp;
        
        // Allocate FIXME: Handle null pointer
        snapshot->stack_copy_buffer = malloc(snapshot->stack_recovery_size);
        
        // Copy
        memcpy(snapshot->stack_copy_buffer, snapshot->stack_recovery_buffer, snapshot->stack_recovery_size);
        
        // ret_pid to 0 to indicate running as child
        snapshot->ret_pid = 0;
        snapshot->fork_flag = false;
        
        // Unfreeze
        thread_resume(thread);
    }
    else
    {
        // MARK: This means the spawn is happening
        // Restore thread state
        thread_set_state(snapshot->thread, ARM_THREAD_STATE64, (thread_state_t)(&snapshot->thread_state), snapshot->thread_count);
        
        // Copy back
        memcpy(snapshot->stack_recovery_buffer, snapshot->stack_copy_buffer, snapshot->stack_recovery_size);
        free(snapshot->stack_copy_buffer);
        
        // Set flag back
        snapshot->fork_flag = 1;
        
        // Unfreeze
        thread_resume(snapshot->thread);
    }
    return NULL;
}

#pragma mark - helper thread helper

void fork_helper_thread_trap(void)
{
    pthread_t nthread;
    pthread_create(&nthread, NULL, fork_helper_thread, local_fork_thread_snapshot);
    pthread_detach(nthread);
    thread_suspend(mach_thread_self());
}

#pragma mark - fork() fix

// MARK: The first pass returns 0, call to execl() or similar will result in the callers thread being restored
DEFINE_HOOK(fork, pid_t, (void))
{
    // Getting entitlement list and checking it
    int64_t retval = environment_syscall(SYS_GETENT);
    PEEntitlement entitlement = (retval == -1) ? 0 : retval;
    if(!(entitlement_got_entitlement(entitlement, PEEntitlementProcessSpawn) |
         entitlement_got_entitlement(entitlement, PEEntitlementProcessSpawnSignedOnly)))
    {
        errno = EPERM;
        return -1;
    }
    
    // Create local snapshot
    local_fork_thread_snapshot = calloc(1, sizeof(fork_thread_snapshot_t));
    
    // Null pointer check
    if(local_fork_thread_snapshot == NULL)
    {
        errno = ENOMEM;
        return -1;
    }
    
    local_fork_thread_snapshot->mapObject = [FDMapObject currentMap];
    
    // Create thread and join
    local_fork_thread_snapshot->fork_flag = true;
    local_fork_thread_snapshot->thread = mach_thread_self();
    
    // Getting into helper
    fork_helper_thread_trap();
    
    pid_t pid = local_fork_thread_snapshot->ret_pid;
    if(pid != 0)
    {
        free(local_fork_thread_snapshot);
        local_fork_thread_snapshot = NULL;
    }
    
    return pid;
}

#pragma mark - exec*() symbol family helpers

// MARK: Helper for all use cases
int environment_execvpa(const char * __path,
                        char *_LIBC_CSTR const *_LIBC_NULL_TERMINATED __argv,
                        char *_LIBC_CSTR const *_LIBC_NULL_TERMINATED __envp,
                        bool find_binary)
{
    // Check if it was even created
    // TODO: Somehow implement exec family functions without relying on fork()
    if(!local_fork_thread_snapshot) return EFAULT;
    
    // Create file actions
    environment_posix_spawn_file_actions_t *fileActions = malloc(sizeof(environment_posix_spawn_file_actions_t));
    
    // MARK: AHHH Apple, pls dont hate me for the poor none ARC friendly code here
    // MARK: Atleast I hope ARC does reference counting on these structs
    fileActions->mapObject = local_fork_thread_snapshot->mapObject;
    
    // Spawn using my own posix_spawn() fix
    if(find_binary)
    {
        environment_posix_spawnp(&local_fork_thread_snapshot->ret_pid, __path, (const environment_posix_spawn_file_actions_t**)&fileActions, nil, __argv, __envp);
    }
    else
    {
        environment_posix_spawn(&local_fork_thread_snapshot->ret_pid, __path, (const environment_posix_spawn_file_actions_t**)&fileActions, nil, __argv, __envp);
    }
    
    // Destroy file actions
    free(fileActions);
    
    if(local_fork_thread_snapshot->ret_pid != 0)
    {
        // Create thread and join
        fork_helper_thread_trap();
    }
    
    return EFAULT;
}

static char **argv_from_va(const char *arg0,
                           va_list ap)
{
    va_list ap_copy;
    int argc = 0;
    va_copy(ap_copy, ap);
    for(const char *a = arg0; a; a = va_arg(ap_copy, const char *))
    {
        argc++;
    }
    va_end(ap_copy);
    char **argv = malloc((argc + 1) * sizeof(char *));
    if(!argv)
    {
        return NULL;
    }
    argv[0] = (char *)arg0;
    for(int i = 1; i < argc; i++)
    {
        argv[i] = va_arg(ap, char *);
    }
    argv[argc] = NULL;
    return argv;
}

static inline void cleanup_argv(char ***argv)
{
    free(*argv);
}

#define _cleanup_argv_ __attribute__((cleanup(cleanup_argv)))

#pragma mark - exec*() symbol family fixes

DEFINE_HOOK(execl, int, (const char *path,
                         const char *arg0,
                         ...))
{
    va_list ap;
    va_start(ap, arg0);
    _cleanup_argv_ char **argv = argv_from_va(arg0, ap);
    va_end(ap);
    
    if(!argv)
    {
        return -1;
    }
    
    return environment_execvpa(path, argv, environ, false);
}

DEFINE_HOOK(execle, int, (const char *path,
                          const char *arg0,
                          ...))
{
    va_list ap;
    va_start(ap, arg0);
    _cleanup_argv_ char **argv = argv_from_va(arg0, ap);
    
    while(va_arg(ap, const char *) != NULL);
    char **envp = va_arg(ap, char **);
    va_end(ap);
    
    if(!argv)
    {
        return -1;
    }
    
    return environment_execvpa(path, argv, envp, false);
}

DEFINE_HOOK(execlp, int, (const char *path,
                          const char *arg0,
                          ...))
{
    va_list ap;
    va_start(ap, arg0);
    _cleanup_argv_ char **argv = argv_from_va(arg0, ap);
    va_end(ap);
    
    if(!argv)
    {
        return -1;
    }
    
    return environment_execvpa(path, argv, environ, false);
}

DEFINE_HOOK(execv, int, (const char * __path,
                         char *_LIBC_CSTR const *_LIBC_NULL_TERMINATED __argv))
{
    return environment_execvpa(__path, __argv, environ, false);
}

DEFINE_HOOK(execve, int, (const char * __file,
                          char *_LIBC_CSTR const *_LIBC_NULL_TERMINATED __argv,
                          char *_LIBC_CSTR const *_LIBC_NULL_TERMINATED __envp))
{
    return environment_execvpa(__file, __argv, __envp, false);
}

DEFINE_HOOK(execvp, int, (const char * __file,
                          char *_LIBC_CSTR const *_LIBC_NULL_TERMINATED __argv))
{
    return environment_execvpa(__file, __argv, environ, true);
}

#pragma mark - File descriptor management fixes

DEFINE_HOOK(close, int, (int fd))
{
    if(local_fork_thread_snapshot && local_fork_thread_snapshot->fork_flag == 0)
    {
        return [local_fork_thread_snapshot->mapObject closeWithFileDescriptor:fd];
    }
    else
    {
        return ORIG_FUNC(close)(fd);
    }
}

DEFINE_HOOK(dup2, int, (int oldFD,
                        int newFD))
{
    if(local_fork_thread_snapshot && local_fork_thread_snapshot->fork_flag == 0)
    {
        return [local_fork_thread_snapshot->mapObject dup2WithOldFileDescriptor:oldFD withNewFileDescriptor:newFD];
    }
    else
    {
        return ORIG_FUNC(dup2)(oldFD,newFD);
    }
}

DEFINE_HOOK(_exit, void, (int code))
{
    if(local_fork_thread_snapshot &&
       local_fork_thread_snapshot->fork_flag == 0)
    {
        // Failed?
        local_fork_thread_snapshot->ret_pid = -1;
        
        // Create thread and join
        fork_helper_thread_trap();
    }
    else
    {
        return ORIG_FUNC(_exit)(code);
    }
}

DEFINE_HOOK(exit, void, (int code))
{
    return hook__exit(code);
}

#pragma mark - Initilizer

void environment_fork_init(void)
{
    if(environment_is_role(EnvironmentRoleGuest))
    {
        DO_HOOK_GLOBAL(fork);
        DO_HOOK_GLOBAL(execl);
        DO_HOOK_GLOBAL(execle);
        DO_HOOK_GLOBAL(execlp);
        DO_HOOK_GLOBAL(execv);
        DO_HOOK_GLOBAL(execve);
        DO_HOOK_GLOBAL(execvp);
        DO_HOOK_GLOBAL(close);
        DO_HOOK_GLOBAL(dup2);
        DO_HOOK_GLOBAL(exit);
        DO_HOOK_GLOBAL(_exit);
    }
}
