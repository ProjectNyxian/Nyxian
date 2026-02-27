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

#ifndef SIGNING_TRUST_H
#define SIGNING_TRUST_H

#import <Foundation/Foundation.h>
#import <LindChain/ProcEnvironment/Surface/entitlement.h>

int macho_after_sign(NSString *path, PEEntitlement entitlement);    /* MARK: unavailable on guest environment, but doesnt really matter runtime tokens arent signed with a valid cdhash associated with such binary */
int macho_read_token(NSString *path, ksurface_ent_mach_t *mach);

#endif /* SIGNING_TRUST_H */
