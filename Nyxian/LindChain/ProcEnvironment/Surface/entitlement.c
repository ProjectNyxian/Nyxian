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

#include <LindChain/ProcEnvironment/Surface/entitlement.h>
#include <LindChain/ProcEnvironment/Surface/proc/proc.h>
#import <LindChain/ProcEnvironment/Surface/key.h>
#include <LindChain/ProcEnvironment/Surface/trust.h>
#include <OpenSSL/evp.h>
#include <OpenSSL/err.h>
#include <OpenSSL/ec.h>
#include <OpenSSL/pem.h>
#include <assert.h>

ksurface_return_t entitlement_token_mach_gen(ksurface_ent_blob_t *blob,
                                             const char *cdhash,
                                             PEEntitlement entitlement)
{
    blob->entitlement = entitlement;
    
    /* copy cdhash and entitlements over */
    if(cdhash != NULL)
    {
        memcpy((void*)(blob->cdhash), cdhash, USER_FSIGNATURES_CDHASH_LEN);
    }
    else
    {
        /* dont sign at all (just containing entitlements) */
        bzero((void*)(blob->cdhash), USER_FSIGNATURES_CDHASH_LEN);
        return SURFACE_SUCCESS;
    }
    
    /* generating nonce so it's harder to crack */
    arc4random_buf(&(blob->nonce), sizeof(uint64_t));

    /* signing blob */
    const uint8_t *p = ksurface->priv_key;
    EVP_PKEY *priv = d2i_PrivateKey(EVP_PKEY_EC, NULL, &p, (long)ksurface->priv_key_len);
    if(!priv)
    {
        return SURFACE_FAILED;
    }
    
    EVP_MD_CTX *mdctx = EVP_MD_CTX_new();
    if(!mdctx)
    {
        EVP_PKEY_free(priv);
        return SURFACE_FAILED;
    }
    
    if(EVP_DigestSignInit(mdctx, NULL, EVP_sha256(), NULL, priv) != 1)
    {
        EVP_MD_CTX_free(mdctx);
        EVP_PKEY_free(priv);
        return SURFACE_FAILED;
    }

    size_t mac_len;
    if(EVP_DigestSign(mdctx, blob->mac, &mac_len, (unsigned char*)blob, offsetof(ksurface_ent_blob_t, mac)) != 1)
    {
        EVP_MD_CTX_free(mdctx);
        EVP_PKEY_free(priv);
        return SURFACE_FAILED;
    }
    blob->mac_len = mac_len;
    
    EVP_MD_CTX_free(mdctx);
    EVP_PKEY_free(priv);
    
    return SURFACE_SUCCESS;
}

ksurface_return_t entitlement_mach_verify(ksurface_ent_result_t *mach,
                                          uint8_t *pub_key,
                                          size_t pub_key_len)
{
    assert(mach != NULL);
    
    /* verify signature from blob */
    const uint8_t *p = pub_key;
    EVP_PKEY *pub = d2i_PUBKEY(NULL, &p, pub_key_len);
    if(!pub)
    {
        return SURFACE_DENIED;
    }
    
    EVP_MD_CTX *mdctx = EVP_MD_CTX_new();
    if(!mdctx)
    {
        EVP_PKEY_free(pub);
        return SURFACE_DENIED;
    }
    
    if(EVP_DigestVerifyInit(mdctx, NULL, EVP_sha256(), NULL, pub) != 1)
    {
        EVP_MD_CTX_free(mdctx);
        EVP_PKEY_free(pub);
        return SURFACE_DENIED;
    }
    
    int ret = EVP_DigestVerify(mdctx, mach->blob.mac, mach->blob.mac_len, (unsigned char *)&mach->blob, offsetof(ksurface_ent_blob_t, mac));
    
    EVP_MD_CTX_free(mdctx);
    EVP_PKEY_free(pub);
    
    if(ret != 1)
    {
        return SURFACE_DENIED;
    }
    
    mach->blob_valid = true;
    if(!mach->cdhash_valid)
    {
        return SURFACE_DENIED;
    }
    
    return SURFACE_SUCCESS;
}

PEEntitlement entitlement_get_path(const char *path,
                                   bool *wasLocallySigned)
{
    int fd = open(path, O_RDONLY);
    if(fd < 0)
    {
        return PEEntitlementNone;
    }
    
    ksurface_ent_result_t mach;
    macho_read_token(fd, &mach);
    close(fd);
    
    ksurface_return_t ksr = entitlement_mach_verify(&mach, ksurface->pub_key, ksurface->pub_key_len);
    *wasLocallySigned = (ksr == SURFACE_SUCCESS);
    
    return mach.blob.entitlement;
}

bool entitlement_set_path(const char *path,
                          PEEntitlement entitlement)
{
    int fd = open(path, O_RDWR);
    if(fd < 0)
    {
        return false;
    }
    
    int retval = macho_after_sign_fd(fd, entitlement);
    fsync(fd);
    close(fd);
    
    return (retval == 0);
}
