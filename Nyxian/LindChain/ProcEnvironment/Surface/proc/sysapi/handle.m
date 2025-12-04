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

#import <LindChain/ProcEnvironment/Surface/proc/proc.h>
#import <LindChain/ProcEnvironment/Surface/proc/sysapi/handle.h>
#import <LindChain/Private/FoundationPrivate.h>
#import <LindChain/Private/UIKitPrivate.h>
#import <LindChain/ProcEnvironment/Surface/proc/create.h>

typedef struct {
    // C stuff
    ksurface_proc_t *proc;
    wid_t wid;
    CGRect frame;
    
    // ObjC stuff (opaque to outside world)
    __unsafe_unretained NSExtension *extension;
    __unsafe_unretained NSUUID *identifier;
    __unsafe_unretained RBSProcessMonitor *monitor;
    __unsafe_unretained FBScene *scene;
} proc_khandle_t;

static inline proc_khandle_t *proc_handle_alloc_internal(void)
{
    /* alloc khandle */
    proc_khandle_t *h = malloc(sizeof(proc_khandle_t));
    
    /* null pointer check */
    if(h == NULL)
    {
        return NULL;
    }
    
    /* nullify khandle */
    memset(h, 0, sizeof(proc_khandle_t));
    
    return h;
}

static inline void proc_handle_free_internal(proc_khandle_t *h)
{
    /* null pointer check */
    if(h == NULL)
    {
        return;
    }
    
    /* free */
    free(h);
}

proc_handle_t *proc_handle_alloc_khandle(void)
{
    /* allocate handle */
    proc_khandle_t *h = malloc(sizeof(proc_khandle_t));
    
    /* null pointer check */
    if(h == NULL)
    {
        return NULL;
    }
    
    /* moving kproc into it */
    h->proc = kernel_proc_;
    
    return (proc_handle_t*)h;
}

proc_handle_t *proc_handle_spawn(NSString *executable_path,
                                 proc_handle_t *parent_handle,
                                 NSArray<NSString*> *arguments,
                                 NSDictionary *environ,
                                 FDMapObject *mapObject)
{
    /* allocate handle */
    proc_khandle_t *h = malloc(sizeof(proc_khandle_t));
    
    /* null pointer check */
    if(h == NULL)
    {
        return NULL;
    }
    
    /* creating real process */
    return NULL;
}
