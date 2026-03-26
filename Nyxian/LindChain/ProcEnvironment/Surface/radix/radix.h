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

#ifndef RADIX_H
#define RADIX_H

#include <stdlib.h>

#define RADIX_BITS   8
#define RADIX_SIZE   256
#define RADIX_MASK   0xFF
#define RADIX_LEVELS 8

typedef struct radix_node {
    void *slots[RADIX_SIZE];
} radix_node_t;

typedef struct radix_tree {
    radix_node_t *root;
} radix_tree_t;

typedef void (*radix_walk_fn)(uint64_t ident, void *value, void *ctx);

void *radix_lookup(radix_tree_t *tree, uint64_t ident);
int radix_insert(radix_tree_t *tree, uint64_t ident, void *value);
void *radix_remove(radix_tree_t *tree, uint64_t ident);
void radix_walk(radix_tree_t *tree, radix_walk_fn callback, void *ctx);

#endif /* RADIX_H */
