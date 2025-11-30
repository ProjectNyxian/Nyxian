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
#import <LindChain/litehook/src/litehook.h>
#include <mach/mach.h>
#import <pthread.h>
#include <stdarg.h>

/*
 There is a better approach..
 
 1. forkfix.dylib gets loaded at a fixed high memory address where images get never loaded to
 2. forkfix.dylib gets jumped too with the dyld list
 3. forkfix.dylib rebases the main thread to a new "stack memory" that is allocated in the upper regions
 4. all heap allocations of forkfix.dylib happen above the scene via mmap
 5. forkfix.dylib destroys the main image and all memory underneath destroys all library loads
 6. forkfix.dylib atp uses its own libc traps and syscall traps it took when it arrived in the address space
 7. forkfix.dylib reloads all dylibs using mmap at fixed addresses and loads the main image where it was for the child and data mappings via mach memory entries
 8. forkfix.dylib jumps back to a symbol in the main image
 the main image unloads forkfix.dylib
 9. the main image does again the ProcEnvironment setup and invoked a thread restore state thread
 10. the thread restores all threads by suspending them and create suspended threads and then it resumes all threads and exits

 Who ever can do this is a absoulute genius... why I wont do it... atleast for now
 
 in theory its possible
 but im not masochistical enough
 this kind of work requires you to really hate your self and your life and everyone so much that you need to vent this by torturing your self
 because building this would be extreme torture
 no debugging
 even debugging it, no chance
 everything would have to be build on assumptioons and logical thinking
 fixing bugs in forkfix.dylib would take eternaties
 because many thing would be written in low level assembly
 */

#pragma mark - Threading black magic

extern char **environ;

typedef struct {
    /* Stack properties*/
    void *stack_recovery_buffer;
    void *stack_copy_buffer;
    size_t stack_recovery_size;
    
    /* Flags */
    pid_t ret_pid;
    BOOL fork_flag;
    
    /* ThreadID */
    mach_msg_type_number_t thread_count;
    arm_thread_state64_t thread_state;
    thread_act_t thread;
    
    /* File descriptors */
    FDMapObject *mapObject;
} thread_snapshot_t;

__thread thread_snapshot_t *local_thread_snapshot = NULL;

void *helper_thread(void *args)
{
    // Get snapshot
    thread_snapshot_t *snapshot = args;
    
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
        
        // Allocate
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

#pragma mark - fork() fix

// MARK: The first pass returns 0, call to execl() or similar will result in the callers thread being restored
DEFINE_HOOK(fork, pid_t, (void))
{
    // Getting entitlement list and checking it
    PEEntitlement entitlement = environment_proxy_getprocinfo(ProcessInfoEntitlements);
    if(!(entitlement_got_entitlement(entitlement, PEEntitlementProcessSpawn) |
         entitlement_got_entitlement(entitlement, PEEntitlementProcessSpawnSignedOnly)))
    {
        return -1;
    }
    
    // Create local snapshot
    local_thread_snapshot = malloc(sizeof(thread_snapshot_t));
    local_thread_snapshot->mapObject = [FDMapObject currentMap];
    
    // Create thread and join
    local_thread_snapshot->fork_flag = true;
    local_thread_snapshot->thread = mach_thread_self();
    pthread_t nthread;
    pthread_create(&nthread, NULL, helper_thread, local_thread_snapshot);
    thread_suspend(mach_thread_self());
    
    pid_t pid = local_thread_snapshot->ret_pid;
    if(pid != 0)
    {
        free(local_thread_snapshot);
        local_thread_snapshot = NULL;
    }
    
    return pid;
}

#pragma mark - exec*() function family fixes

// MARK: Helper for all use cases
int environment_execvpa(const char * __path,
                        char *_LIBC_CSTR const *_LIBC_NULL_TERMINATED __argv,
                        char *_LIBC_CSTR const *_LIBC_NULL_TERMINATED __envp,
                        bool find_binary)
{
    // Check if it was even created
    // TODO: Somehow implement exec family functions without relying on fork()
    if(!local_thread_snapshot) return EFAULT;
    
    // Create file actions
    environment_posix_spawn_file_actions_t *fileActions = malloc(sizeof(environment_posix_spawn_file_actions_t));
    
    // MARK: AHHH Apple, pls dont hate me for the poor none ARC friendly code here
    // MARK: Atleast I hope ARC does reference counting on these structs
    fileActions->mapObject = local_thread_snapshot->mapObject;
    
    // Spawn using my own posix_spawn() fix
    if(find_binary)
        environment_posix_spawnp(&local_thread_snapshot->ret_pid, __path, (const environment_posix_spawn_file_actions_t**)&fileActions, nil, __argv, __envp);
    else
        environment_posix_spawn(&local_thread_snapshot->ret_pid, __path, (const environment_posix_spawn_file_actions_t**)&fileActions, nil, __argv, __envp);
    
    // Destroy file actions
    free(fileActions);
    
    if(local_thread_snapshot->ret_pid != 0)
    {
        // Create thread and join
        pthread_t nthread;
        pthread_create(&nthread, NULL, helper_thread, local_thread_snapshot);
        thread_suspend(mach_thread_self());
    }
    
    return EFAULT;
}

DEFINE_HOOK(execl, int, (const char * __path,
                         const char * __arg0,
                         ...))
{
    // Now create argv
    va_list ap;
    int argc = 0;
    
    // First pass: count arguments
    va_start(ap, __arg0);
    const char *arg = __arg0;
    while(arg != NULL)
    {
        argc++;
        arg = va_arg(ap, const char *);
    }
    va_end(ap);
    
    // Allocate argv
    char **argv = malloc((argc + 1) * sizeof(char *));
    if(argv == NULL)
    {
        perror("malloc");
        return -1;
    }
    
    // Stuff argv
    va_start(ap, __arg0);
    arg = __arg0;
    for(int i = 0; i < argc; i++)
    {
        argv[i] = (char *)arg;
        arg = va_arg(ap, const char *);
    }
    argv[argc] = NULL;
    va_end(ap);
    
    int result = environment_execvpa(__path, argv, environ, false);
    
    free(argv);
    
    return result;
}

DEFINE_HOOK(execle, int, (const char *path,
                        const char *arg0, ...))
{
    va_list ap;
    int argc = 0;
    const char *arg;

    // First pass: count arguments
    va_start(ap, arg0);
    arg = arg0;
    while(arg != NULL)
    {
        argc++;
        arg = va_arg(ap, const char *);
    }

    // Get envp
    char *const *envp = va_arg(ap, char *const *);
    va_end(ap);

    // Allocate argv
    char **argv = malloc((argc + 1) * sizeof(char *));
    if(argv == NULL)
    {
        perror("malloc");
        return -1;
    }

    // Stuff argv
    va_start(ap, arg0);
    arg = arg0;
    for(int i = 0; i < argc; i++)
    {
        argv[i] = (char *)arg;
        arg = va_arg(ap, const char *);
    }
    argv[argc] = NULL;

    (void)va_arg(ap, char *const *);
    envp = va_arg(ap, char *const *);
    va_end(ap);

    int result = environment_execvpa(path, argv, envp, false);
    
    free(argv);
    
    return result;
}

DEFINE_HOOK(execlp, int, (const char * __path,
                          const char * __arg0,
                          ...))
{
    // Now create argv
    va_list ap;
    int argc = 0;
    
    // First pass: count arguments
    va_start(ap, __arg0);
    const char *arg = __arg0;
    while(arg != NULL)
    {
        argc++;
        arg = va_arg(ap, const char *);
    }
    va_end(ap);
    
    // Allocate argv
    char **argv = malloc((argc + 1) * sizeof(char *));
    if(argv == NULL)
    {
        perror("malloc");
        return -1;
    }
    
    // Stuff argv
    va_start(ap, __arg0);
    arg = __arg0;
    for(int i = 0; i < argc; i++)
    {
        argv[i] = (char *)arg;
        arg = va_arg(ap, const char *);
    }
    argv[argc] = NULL;
    va_end(ap);
    
    int result = environment_execvpa(__path, argv, environ, true);
    
    free(argv);
    
    return result;
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
    if(local_thread_snapshot && local_thread_snapshot->fork_flag == 0)
        return [local_thread_snapshot->mapObject closeWithFileDescriptor:fd];
    else
        return ORIG_FUNC(close)(fd);
}

DEFINE_HOOK(dup2, int, (int oldFD,
                        int newFD))
{
    if(local_thread_snapshot && local_thread_snapshot->fork_flag == 0)
        return [local_thread_snapshot->mapObject dup2WithOldFileDescriptor:oldFD withNewFileDescriptor:newFD];
    else
        return ORIG_FUNC(dup2)(oldFD,newFD);
}

DEFINE_HOOK(_exit, void, (int code))
{
    if(local_thread_snapshot && local_thread_snapshot->fork_flag == 0)
    {
        // Failed?
        local_thread_snapshot->ret_pid = -1;
        
        // Create thread and join
        pthread_t nthread;
        pthread_create(&nthread, NULL, helper_thread, local_thread_snapshot);
        thread_suspend(mach_thread_self());
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
