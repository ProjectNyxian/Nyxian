/*
 SPDX-License-Identifier: AGPL-3.0-or-later

 Copyright (C) 2025 - 2026 mach-port-t

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

#include <LindChain/ProcEnvironment/Surface/radix/radix.h>
#include <stdlib.h>
#include <stdbool.h>

static inline int radix_chunk(uint64_t ident,
                              int level)
{
    int shift = (RADIX_LEVELS - 1 - level) * RADIX_BITS;
    return(ident >> shift) & RADIX_MASK;
}

void *radix_lookup(radix_tree_t *tree,
                   uint64_t ident)
{
    radix_node_t *node = tree->root;
    
    for(int level = 0; level < RADIX_LEVELS - 1; level++)
    {
        if(node == NULL)
        {
            return NULL;
        }
        
        int chunk = radix_chunk(ident, level);
        node = (radix_node_t *)node->slots[chunk];
    }
    
    if(node == NULL)
    {
        return NULL;
    }
    
    int chunk = radix_chunk(ident, RADIX_LEVELS - 1);
    return node->slots[chunk];
}

int radix_insert(radix_tree_t *tree,
                 uint64_t ident,
                 void *value)
{
    if(tree->root == NULL)
    {
        tree->root = calloc(1, sizeof(radix_node_t));
    }
    
    radix_node_t *node = tree->root;
    
    for(int level = 0; level < RADIX_LEVELS - 1; level++)
    {
        int chunk = radix_chunk(ident, level);
        
        if(node->slots[chunk] == NULL)
        {
            node->slots[chunk] = calloc(1, sizeof(radix_node_t));
        }
        
        node = (radix_node_t *)node->slots[chunk];
    }
    
    int chunk = radix_chunk(ident, RADIX_LEVELS - 1);
    node->slots[chunk] = value;
    
    return 0;
}

void *radix_remove(radix_tree_t *tree,
                   uint64_t ident)
{
    radix_node_t *node = tree->root;
    radix_node_t *path[RADIX_LEVELS];
    int chunks[RADIX_LEVELS];
    
    for(int level = 0; level < RADIX_LEVELS; level++)
    {
        if(node == NULL)
        {
            return NULL;
        }
        
        path[level] = node;
        chunks[level] = radix_chunk(ident, level);
        
        if(level < RADIX_LEVELS - 1)
        {
            node = (radix_node_t *)node->slots[chunks[level]];
        }
    }
    
    void *old = path[RADIX_LEVELS - 1]->slots[chunks[RADIX_LEVELS - 1]];
    path[RADIX_LEVELS - 1]->slots[chunks[RADIX_LEVELS - 1]] = NULL;
    
    for(int level = RADIX_LEVELS - 2; level >= 0; level--)
    {
        bool all_null = true;
        for(int i = 0; i < RADIX_SIZE; i++)
        {
            if(path[level]->slots[i] != NULL)
            {
                all_null = false;
                break;
            }
        }
        if(all_null && level > 0)
        {
            free(path[level]);
            path[level - 1]->slots[chunks[level - 1]] = NULL;
        }
        else
        {
            break;
        }
    }
    
    return old;
}

static void radix_walk_node(radix_node_t *node,
                            int level,
                            uint64_t ident_prefix,
                            radix_walk_fn callback,
                            void *ctx)
{
    if(node == NULL)
    {
        return;
    }
    
    for(int i = 0; i < RADIX_SIZE; i++)
    {
        if(node->slots[i] == NULL)
        {
            continue;
        }
        
        uint64_t ident = ident_prefix | (i << ((RADIX_LEVELS - 1 - level) * RADIX_BITS));
        
        if(level == RADIX_LEVELS - 1)
        {
            callback(ident, node->slots[i], ctx);
        }
        else
        {
            radix_walk_node((radix_node_t *)node->slots[i], level + 1, ident_prefix, callback, ctx);
        }
    }
}

void radix_walk(radix_tree_t *tree, radix_walk_fn callback, void *ctx)
{
    radix_walk_node(tree->root, 0, 0, callback, ctx);
}
