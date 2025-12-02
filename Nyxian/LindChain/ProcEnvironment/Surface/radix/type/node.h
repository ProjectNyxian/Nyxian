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

#ifndef RADIX_TYPE_NODE_H
#define RADIX_TYPE_NODE_H

#import <LindChain/ProcEnvironment/Surface/radix/config.h>

typedef struct radix_node {
    void *slots[RADIX_SIZE];
} radix_node_t;

#endif /* RADIX_TYPE_NODE_H */
