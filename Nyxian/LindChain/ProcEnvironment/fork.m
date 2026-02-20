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
#import <LindChain/litehook/litehook.h>
#include <mach/mach.h>
#import <pthread.h>
#include <stdarg.h>

#pragma mark - Threading black magic

extern char **environ;

__thread fork_thread_snapshot_t *local_fork_thread_snapshot = NULL;

void *fork_helper_thread(void *args)
{
    /*
     * getting thread snapshot which has been
     * passed by the callers thread of it self.
     */
    fork_thread_snapshot_t *snapshot = args;
    
    /* sanity check */
    if(snapshot == NULL)
    {
        return NULL;
    }
    
    if(snapshot->ret_pid == 0)
    {
        /* creating copy of current fd map */
        snapshot->mapObject = [FDMapObject currentMap];
        
        /* getting arm64 thread state of our own thread. */
        snapshot->thread_state = thread_save_state_arm64(snapshot->thread);
        
        /* doing the black magic~~ math */
        pthread_t pthread = pthread_from_mach_thread_np(snapshot->thread);
        void *stack_top = pthread_get_stackaddr_np(pthread);
        size_t stack_size = pthread_get_stacksize_np(pthread);
        void *stack_bottom = stack_top - stack_size;
        
        /* storing result */
        snapshot->stack_recovery_buffer = stack_bottom;
        snapshot->stack_recovery_size = stack_size;
        
        /* copying stack */
        snapshot->stack_copy_buffer = malloc(snapshot->stack_recovery_size);
        
        /* checking for null pointer */
        if(snapshot->stack_copy_buffer == NULL)
        {
            snapshot->suceeded = false;
            return NULL;
        }
        
        memcpy(snapshot->stack_copy_buffer, snapshot->stack_recovery_buffer, snapshot->stack_recovery_size);
        
        /* setting succession flag */
        snapshot->suceeded = true;
        
        /* resuming thread */
        thread_resume(snapshot->thread);
    }
    else
    {
        /* spawn it self happens now restoring thread state */
        thread_restore_state_arm64(snapshot->thread, snapshot->thread_state);
        
        /* restoring stack */
        memcpy(snapshot->stack_recovery_buffer, snapshot->stack_copy_buffer, snapshot->stack_recovery_size);
        free(snapshot->stack_copy_buffer);
        
        /* resuming caller thread */
        thread_resume(snapshot->thread);
    }

    return NULL;
}

#pragma mark - helper thread helper

bool fork_helper_thread_trap(void)
{
    /* trapping into fork helper thread */
    pthread_t nthread;
    pthread_create(&nthread, NULL, fork_helper_thread, local_fork_thread_snapshot);
    pthread_detach(nthread);
    thread_suspend(mach_thread_self());
    
    /* checking thread snapshot for null ptr */
    if(local_fork_thread_snapshot == NULL)
    {
        return false;
    }
    
    /* returning if successful */
    return local_fork_thread_snapshot->suceeded;
}

#pragma mark - fork() fix

// MARK: The first pass returns 0, call to execl() or similar will result in the callers thread being restored
DEFINE_HOOK(fork, pid_t, (void))
{
    /*
     * allocating local thread snapshot, which
     * is used to snapshot the current stack
     * memory of the caller thread to later
     * restore it so it looks as if its returning
     * from fork but in reality it did a time
     * travel.
     */
    local_fork_thread_snapshot = malloc(sizeof(fork_thread_snapshot_t));
    
    /* sanity check */
    if(local_fork_thread_snapshot == NULL)
    {
        errno = ENOMEM;
        return -1;
    }
    
    /* preparing for thread handoff */
    local_fork_thread_snapshot->ret_pid = 0;
    local_fork_thread_snapshot->thread = mach_thread_self();
    
    /* handing off */
    bool success = fork_helper_thread_trap();
    
    /* checking for succession */
    if(!success)
    {
        if(local_fork_thread_snapshot != NULL)
        {
            free(local_fork_thread_snapshot);
            local_fork_thread_snapshot = NULL;
        }
        
        errno = EBADEXEC;
        return -1;
    }
    
    /* we will go here twice! */
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
    /* sanity check */
    if(local_fork_thread_snapshot == NULL)
    {
        errno = EBADEXEC;
        return -1;
    }
    
    /* creating file actions structure */
    environment_posix_spawn_file_actions_t *fileActions = malloc(sizeof(environment_posix_spawn_file_actions_t));
    
    /*
     * MARK: AHHH Apple, pls dont hate me for the poor none ARC friendly code here
     * MARK: Atleast I hope ARC does reference counting on these structs
     */
    fileActions->mapObject = local_fork_thread_snapshot->mapObject;
    
    /* commiting the posix spawn */
    int retval = find_binary ? environment_posix_spawnp(&local_fork_thread_snapshot->ret_pid, __path, (const environment_posix_spawn_file_actions_t**)&fileActions, nil, __argv, __envp) :
                               environment_posix_spawn(&local_fork_thread_snapshot->ret_pid, __path, (const environment_posix_spawn_file_actions_t**)&fileActions, nil, __argv, __envp);
    
    /* evaluating return */
    if(retval != 0)
    {
        errno = EBADEXEC;
        return -1;
    }
    
    /* destroying file actions, were done with it */
    free(fileActions);
    
    /*
     * trapping into fork helper, but only if its
     * the return process identifier indicates that
     * were about to spawn.
     */
    if(local_fork_thread_snapshot->ret_pid != 0)
    {
        local_fork_thread_snapshot->suceeded = true;
        fork_helper_thread_trap();
    }
    
    errno = EBADEXEC;
    return -1;
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
        errno = EFAULT;
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
        errno = EFAULT;
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
        errno = EFAULT;
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
    if(local_fork_thread_snapshot && local_fork_thread_snapshot->ret_pid == 0)
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
    if(local_fork_thread_snapshot && local_fork_thread_snapshot->ret_pid == 0)
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
    if(local_fork_thread_snapshot && local_fork_thread_snapshot->ret_pid == 0)
    {
        local_fork_thread_snapshot->suceeded = false;
        local_fork_thread_snapshot->ret_pid = -1;
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

DEFINE_HOOK(waitpid, pid_t, (pid_t pid,
                             int *ecode,
                             int idk))
{
    task_name_t name;
    int64_t ret = environment_syscall(SYS_gettask, pid, true, &name);
    
    if(ret != 0)
    {
        *ecode = 1;
        return pid;
    }
    
    mach_port_t notify_port;
    mach_port_t prev;
    
    mach_port_allocate(mach_task_self(), MACH_PORT_RIGHT_RECEIVE, &notify_port);
    
    mach_port_request_notification(mach_task_self(), name, MACH_NOTIFY_DEAD_NAME, 0, notify_port, MACH_MSG_TYPE_MAKE_SEND_ONCE, &prev);
    
    struct {
        mach_msg_header_t header;
        mach_msg_trailer_t trailer;
    } msg;
    
    mach_msg(&msg.header, MACH_RCV_MSG, 0, sizeof(msg), notify_port, MACH_MSG_TIMEOUT_NONE, MACH_PORT_NULL);
    
    mach_port_deallocate(mach_task_self(), notify_port);
    mach_port_deallocate(mach_task_self(), name);
    
    return pid;
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
        DO_HOOK_GLOBAL(waitpid);
    }
}
