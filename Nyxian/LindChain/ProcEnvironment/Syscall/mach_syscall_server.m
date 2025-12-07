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

#import <LindChain/ProcEnvironment/Syscall/mach_syscall_server.h>
#import <LindChain/ProcEnvironment/Surface/proc/proc.h>
#import <LindChain/ProcEnvironment/Surface/proc/copy.h>
#import <LindChain/ProcEnvironment/panic.h>
#include <pthread.h>
#include <stdlib.h>
#include <string.h>
#include <stdio.h>

// MARK: Todo.. right before suspending.. justify one more push to get the request out of our way, otherwise it might fill up all 4 threads.. or break the request up and then sent the reply on process wakeup (complex shit)

#define MAX_SYSCALLS 1024

struct syscall_server {
    mach_port_t port;
    pthread_t threads[SYSCALL_SERVER_THREADS];
    volatile bool running;
    syscall_handler_t handlers[MAX_SYSCALLS];
};

typedef struct {
    mach_msg_header_t header;
    uint8_t body[sizeof(syscall_request_t)];
    mach_msg_max_trailer_t trailer;
} recv_buffer_t;

/*
 * To ensure safety in nyxian we rely on the XNU kernel, as asking processes for their pid is extremely stupid
 * So we ensure nothing can be tempered
 */
static bool get_caller(mach_msg_header_t *msg,
                       syscall_caller_t *caller)
{
    /* getting mach msg audit trailer which contains audit information */
    mach_msg_audit_trailer_t *trailer = (mach_msg_audit_trailer_t *)((uint8_t *)msg + round_msg(msg->msgh_size));
    
    /* checking trailer format */
    if(trailer->msgh_trailer_type != MACH_MSG_TRAILER_FORMAT_0 ||
       trailer->msgh_trailer_size < sizeof(mach_msg_audit_trailer_t))
    {
        /* defensive programming, didnt got the caller */
        return false;
    }
    
    /* yep clear to go */
    audit_token_t *token = &trailer->msgh_audit;
    caller->pid  = (pid_t)token->val[5];
    
    /* getting process */
    ksurface_proc_t *proc = proc_for_pid(caller->pid);
    
    /* null pointer check */
    if(proc == NULL)
    {
        return false;
    }
    
    /* creating process copy with process reference consumption */
    ksurface_proc_copy_t *proc_copy = proc_copy_for_proc(proc, kProcCopyOptionConsumeReference);
    
    /* null pointer check */
    if(proc_copy == NULL)
    {
        return false;
    }
    
    caller->proc_cpy = proc_copy;
    
    /* take the auth properties from proc copy */
    caller->euid = proc_geteuid(proc_copy);
    caller->egid = proc_getegid(proc_copy);
    caller->ruid = proc_getruid(proc_copy);
    caller->rgid = proc_getrgid(proc_copy);
    
    return true;
}

/*
 * This is the symbol that sends the result from the syscall back to the guest process
 */
static void send_reply(mach_msg_header_t *request,
                       int64_t result,
                       uint8_t *payload,
                       uint32_t payload_len,
                       mach_port_t *out_ports,
                       uint32_t out_ports_cnt,
                       errno_t err)
{
    /* allocating a reply */
    syscall_reply_t reply;
    memset(&reply, 0, sizeof(reply));
    
    /* setting reply data */
    reply.header.msgh_bits = MACH_MSGH_BITS_REMOTE(MACH_MSG_TYPE_MOVE_SEND_ONCE);
    reply.header.msgh_remote_port = request->msgh_remote_port;
    reply.header.msgh_local_port = MACH_PORT_NULL;
    reply.header.msgh_size = sizeof(reply);
    reply.header.msgh_id = request->msgh_id + 100;
    reply.body.msgh_descriptor_count = 2;
    
    /* storing syscall result */
    reply.result = result;
    reply.err = err;
    
    /* validating payload */
    if(payload &&
       payload_len > 0)
    {
        /* creating ool descriptor */
        reply.header.msgh_bits |= MACH_MSGH_BITS_COMPLEX;
        reply.ool.type = MACH_MSG_OOL_DESCRIPTOR;
        reply.ool.address = payload;
        reply.ool.copy = MACH_MSG_VIRTUAL_COPY;
        reply.ool.size = payload_len;
        reply.ool.deallocate = TRUE;
    }
    else
    {
        /* creating invalid ool */
        reply.ool.type = MACH_MSG_OOL_DESCRIPTOR;
        reply.ool.address = NULL;
        reply.ool.size = 0;
        reply.ool.deallocate = FALSE;
    }
    
    /* validating ports */
    if(out_ports &&
       out_ports_cnt > 0)
    {
        printf("[server] sending ports payload\n");
        reply.header.msgh_bits |= MACH_MSGH_BITS_COMPLEX;
        reply.oolp.type = MACH_MSG_OOL_PORTS_DESCRIPTOR;
        reply.oolp.disposition = MACH_MSG_TYPE_COPY_SEND;
        reply.oolp.address = out_ports;
        reply.oolp.count = out_ports_cnt;
        reply.oolp.copy = MACH_MSG_PHYSICAL_COPY;
        reply.oolp.deallocate = FALSE;
    }
    else
    {
        /* create invalid oolp*/
        reply.oolp.type = MACH_MSG_OOL_PORTS_DESCRIPTOR;
        reply.oolp.address = NULL;
        reply.oolp.count = 0;
        reply.oolp.deallocate = FALSE;
    }
    
    /* sending reply to child */
    mach_msg(&reply.header, MACH_SEND_MSG, sizeof(reply), 0, MACH_PORT_NULL, MACH_MSG_TIMEOUT_NONE, MACH_PORT_NULL);
}

/*
 * This is similar to an kernel worker thread, it works for our "userspace" to
 * process syscalls, unlike XPC this shitty framework that can easily be poisoned
 * this is the proper way for an kernel virtualisation layer to do it,
 * because we can control raw mach to 100%
 */
static void* worker_thread(void *ctx)
{
    /* getting the server */
    syscall_server_t *server = (syscall_server_t *)ctx;
    
    /* receive buffer to receive request from guest */
    recv_buffer_t buffer;
    
    /*
     * setting options, this is what XPC cannot really give us
     * we simply tell XNU to always give us the identity of the process
     * requesting.
     */
    mach_msg_option_t options = MACH_RCV_MSG | MACH_RCV_LARGE | MACH_RCV_TRAILER_TYPE(MACH_MSG_TRAILER_FORMAT_0) | MACH_RCV_TRAILER_ELEMENTS(MACH_RCV_TRAILER_AUDIT);
    
    /* worker thread request loop */
    while(server->running)
    {
        /* nullifying the buffer */
        memset(&buffer, 0, sizeof(buffer));
        
        /* waiting for the kernel to give us the childs request */
        kern_return_t kr = mach_msg(&buffer.header, options, 0, sizeof(buffer), server->port, MACH_MSG_TIMEOUT_NONE, MACH_PORT_NULL);
        
        /* evaluating if the request received from the kernel was geniune */
        if(kr != KERN_SUCCESS)
        {
            if(!server->running)
            {
                /* in case the server is marked as not running we exit */
                break;
            }
            continue;
        }
        
        /* getting the callers identity from the payload */
        syscall_caller_t caller;
        if(!get_caller(&buffer.header, &caller))
        {
            /* checking if proc copy is null */
            if(caller.proc_cpy != NULL)
            {
                proc_copy_destroy(caller.proc_cpy);
                send_reply(&buffer.header, -1, NULL, 0, NULL, 0, EINVAL);
            }
            else
            {
                send_reply(&buffer.header, -1, NULL, 0, NULL, 0, EAGAIN);
            }
            continue;
        }
        
        /* parsing request */
        syscall_request_t *req = (syscall_request_t *)&buffer.header;
        
        /* checking syscall bounds */
        if(req->syscall_num >= MAX_SYSCALLS)
        {
            proc_copy_destroy(caller.proc_cpy);
            send_reply(&buffer.header, -1, NULL, 0, NULL, 0, EINVAL);
            continue;
        }
        
        /* getting the syscall handler the kernel virtualisation layer previously has set */
        syscall_handler_t handler = server->handlers[req->syscall_num];
        
        /* checking if the handler was set by the kernel virtualisation layer */
        if(!handler)
        {
            proc_copy_destroy(caller.proc_cpy);
            send_reply(&buffer.header, -1, NULL, 0, NULL, 0, EINVAL);
            continue;
        }
        
        /* creating out payload buffer to be sent back */
        uint8_t *out_payload = NULL;
        uint32_t out_len = 0;
        errno_t err;
        mach_port_t *out_ports = NULL;
        uint32_t out_ports_cnt = 0;
        
        /* calling syscall handler */
        int64_t result = handler(&caller, req->args, req->ool.address, req->ool.size, &out_payload, &out_len, (mach_port_t*)(req->oolp.address), req->oolp.count, &out_ports, &out_ports_cnt, &err);
        
        /* deallocate input payload because otherwise it will eat our ram sticks :c */
        if(req->ool.address != VM_MIN_ADDRESS ||
           req->ool.address != NULL)
        {
            /* deallocate what the guest requested via input buffer (i.e SYS_SETHOSTNAME) (avoiding memory leaks is a extremely good idea ^^) */
            vm_deallocate(mach_task_self(), (mach_vm_address_t)req->ool.address, req->ool.size);
        }
        
        /* deallocate input ports because otherwise bad things :c */
        if(req->oolp.address != VM_MIN_ADDRESS ||
           req->oolp.address != NULL)
        {
            /* deallocate */
            vm_deallocate(mach_task_self(), (mach_vm_address_t)req->oolp.address, req->oolp.count * sizeof(mach_port_t));
        }
        
        /* destroying copy of process */
        proc_copy_destroy(caller.proc_cpy);
        
        /* replying to the guest */
        send_reply(&buffer.header, result, out_payload, out_len, out_ports, out_ports_cnt, err);
    }
    
    return NULL;
}

syscall_server_t* syscall_server_create(void)
{
    /* allocating server */
    syscall_server_t *server = malloc(sizeof(syscall_server_t));
    memset(server, 0, sizeof(syscall_server_t));
    return server;
}

void syscall_server_destroy(syscall_server_t *server)
{
    /* null pointer check */
    if(!server)
    {
        return;
    }
    
    /* stopping the server */
    syscall_server_stop(server);
    
    /* releasing the memory the server was created with */
    free(server);
}

void syscall_server_register(syscall_server_t *server,
                             uint32_t syscall_num,
                             syscall_handler_t handler)
{
    /* null pointer check */
    if(server == NULL ||
       syscall_num >= MAX_SYSCALLS)
    {
        /* shall never ever happen */
        environment_panic();
    }
    
    /* trying to get syscall handler */
    syscall_handler_t phandler = server->handlers[syscall_num];
    
    /* if its already present panic */
    if(phandler != NULL)
    {
        /* shall never ever happen */
        environment_panic();
    }
    
    /* setting syscall handler */
    server->handlers[syscall_num] = handler;
}

int syscall_server_start(syscall_server_t *server)
{
    /* null pointer check*/
    if(!server)
    {
        return -1;
    }
    
    kern_return_t kr;
    
    /* creating syscall server port */
    kr = mach_port_allocate(mach_task_self(), MACH_PORT_RIGHT_RECEIVE, &server->port);
    
    /* mach return check */
    if(kr != KERN_SUCCESS)
    {
        return -1;
    }
    
    /* inserting port send right */
    kr = mach_port_insert_right(mach_task_self(), server->port, server->port, MACH_MSG_TYPE_MAKE_SEND);
    
    /* mach return check */
    if(kr != KERN_SUCCESS)
    {
        mach_port_deallocate(mach_task_self(), server->port);
        return -1;
    }
    
    /* setting limits on how many syscalls can be queued at once */
    mach_port_limits_t limits = { .mpl_qlimit = SYSCALL_QUEUE_LIMIT };
    
    /* setting it as a attribute MARK: fuck XPC */
    mach_port_set_attributes(mach_task_self(), server->port, MACH_PORT_LIMITS_INFO, (mach_port_info_t)&limits, MACH_PORT_LIMITS_INFO_COUNT);
    
    /* starting syscall server */
    server->running = true;
    for(int i = 0; i < SYSCALL_SERVER_THREADS; i++)
    {
        pthread_create(&server->threads[i], NULL, worker_thread, server);
    }
    
    return 0;
}

void syscall_server_stop(syscall_server_t *server)
{
    /* null pointer check */
    if(!server)
    {
        return;
    }
    
    /* stopping the server */
    server->running = false;
    
    /* checking if port is null */
    if(server->port != MACH_PORT_NULL)
    {
        /* destroying mach port */
        mach_port_deallocate(mach_task_self(), server->port);
        
        /* setting port */
        server->port = MACH_PORT_NULL;
    }
    
    /* stopping each thread of the server */
    for(int i = 0; i < SYSCALL_SERVER_THREADS; i++)
    {
        if(server->threads[i])
        {
            pthread_join(server->threads[i], NULL);
        }
    }
}

mach_port_t syscall_server_get_port(syscall_server_t *server)
{
    /* returning server port */
    return server->port;
}
