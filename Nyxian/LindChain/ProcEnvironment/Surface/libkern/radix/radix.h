/*
 SPDX-License-Identifier: LicenseRef-EPSL-1.1

 Copyright (C) 2025 - 2026 emexlab

 This file is part of Nyxian.

 Licensed under the emexLabs Public Source License, version 1.1
 (EPSL 1.1).

 Private use and modification are permitted under the license.
 Redistribution of source or binaries, modified or unmodified,
 requires prior written permission from emexLabs.

 External deployment is subject to the source-availability
 requirements and other conditions of the license.

 Provided "AS IS", without warranty, to the extent permitted by law.

 See LICENSE for the full license terms.
*/

#ifndef LIBKERN_RADIX_RADIX_H
#define LIBKERN_RADIX_RADIX_H

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

#endif /* LIBKERN_RADIX_RADIX_H */
