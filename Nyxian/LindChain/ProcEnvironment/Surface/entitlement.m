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
#include <OpenSSL/hmac.h>

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
