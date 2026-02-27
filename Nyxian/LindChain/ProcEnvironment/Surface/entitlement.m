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

#include <LindChain/ProcEnvironment/Surface/entitlement.h>
#include <LindChain/ProcEnvironment/Surface/proc/proc.h>
#import <LindChain/ProcEnvironment/Surface/key.h>
#include <OpenSSL/hmac.h>

ksurface_return_t entitlement_token_generate_for_entitlement(ksurface_proc_t *proc,
                                                             PEEntitlement entitlement,
                                                             ksurface_ent_token_t *token)
{
    assert(proc != NULL && token != NULL);
    
    kvo_rdlock(proc);
    
    /* permitive check */
    if(!entitlement_got_entitlement(proc_getentitlements(proc), entitlement))
    {
        kvo_unlock(proc);
        return SURFACE_DENIED;
    }
    
    /* zero blob */
    bzero(&(token->blob), sizeof(ksurface_ent_blob_t));
    
    /* stuffing blob */
    token->blob.issuer_pid = proc_getpid(proc);
    token->blob.entitlement = entitlement & proc_getmaxentitlements(proc);
    arc4random_buf(&(token->blob.nonce), sizeof(uint64_t));
    
    /* generating cryptographic key */
    unsigned int mac_len = 0;
    HMAC(EVP_sha256(), ksurface->kernel_token_key, 32, (unsigned char*)&(token->blob), sizeof(ksurface_ent_blob_t), token->mac, &mac_len);
    
    kvo_unlock(proc);
    
    return (mac_len != 32) ? SURFACE_FAILED : SURFACE_SUCCESS;
}

ksurface_return_t entitlement_token_verify(ksurface_ent_token_t *token)
{
    assert(token != NULL);
    
    uint8_t expected[32];
    unsigned int mac_len = 0;

    HMAC(EVP_sha256(), ksurface->kernel_token_key, 32, (unsigned char *)&(token->blob), sizeof(ksurface_ent_blob_t), expected, &mac_len);
    
    /* sanity check */
    if(mac_len != 32)
    {
        return SURFACE_DENIED;
    }
    
    if(CRYPTO_memcmp(expected, token->mac, 32) != 0)
    {
        return SURFACE_DENIED;
    }

    return SURFACE_SUCCESS;
}

ksurface_return_t entitlement_token_consume(ksurface_proc_t *consumer,
                                            ksurface_ent_token_t *token)
{
    assert(consumer != NULL && token != NULL);
    
    /* verify authenticity of the token */
    if(entitlement_token_verify(token) != SURFACE_SUCCESS)
    {
        return SURFACE_DENIED;
    }
    
    /*
     * make sure the token was created by a
     * process which is still alive.
     */
    ksurface_proc_t *issuer = NULL;
    ksurface_return_t ksr = proc_for_pid(token->blob.issuer_pid, &issuer);
    
    if(ksr != KERN_SUCCESS)
    {
        return SURFACE_DENIED;
    }
    
    /* releasing proc again since that was the verification lol */
    kvo_release(issuer);
    
    /* token is valid now consume */
    kvo_wrlock(consumer);
    consumer->kproc.kcproc.nyx.max_entitlements |= token->blob.entitlement;
    consumer->kproc.kcproc.nyx.entitlements |= token->blob.entitlement;
    kvo_unlock(consumer);
    
    return SURFACE_SUCCESS;
}

ksurface_return_t entitlement_token_mach_gen(ksurface_ent_token_t *token,
                                             const char *cdhash,
                                             PEEntitlement entitlement)
{
    /* copy cdhash and entitlements over */
    memcpy((void*)(token->blob.cdhash), cdhash, USER_FSIGNATURES_CDHASH_LEN);
    token->blob.entitlement = entitlement;
    arc4random_buf(&(token->blob.nonce), sizeof(uint64_t));
    
    /* generating cryptographic key */
    unsigned int mac_len = 0;
    HMAC(EVP_sha256(), get_static_kernel_key(), 32, (unsigned char*)&(token->blob), sizeof(ksurface_ent_blob_t), token->mac, &mac_len);
    
    /* sanity check */
    if(mac_len != 32)
    {
        return SURFACE_FAILED;
    }
    
    return SURFACE_SUCCESS;
}

ksurface_return_t entitlement_mach_verify(ksurface_ent_mach_t *mach)
{
    assert(mach != NULL);
    
    uint8_t expected[32];
    unsigned int mac_len = 0;

    HMAC(EVP_sha256(), get_static_kernel_key(), 32, (unsigned char *)&(mach->token.blob), sizeof(ksurface_ent_blob_t), expected, &mac_len);
    
    /* sanity check */
    if(mac_len != 32)
    {
        return SURFACE_DENIED;
    }
    
    if(CRYPTO_memcmp(expected, mach->token.mac, 32) != 0)
    {
        return SURFACE_DENIED;
    }
    
    /* blob is valid */
    mach->blob_valid = true;

    /* check if cdhash check by trustd is valid */
    if(!mach->cdhash_valid)
    {
        return SURFACE_DENIED;
    }
    
    return SURFACE_SUCCESS;
}
