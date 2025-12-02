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

#import <LindChain/ProcEnvironment/Surface/radix/config.h>
#import <LindChain/ProcEnvironment/Surface/radix/radix.h>
#import <LindChain/ProcEnvironment/Surface/radix/type/tree.h>
#import <LindChain/ProcEnvironment/Surface/radix/type/node.h>
#include <stdlib.h>

static inline int radix_chunk(pid_t pid,
                              int level)
{
    int shift = (RADIX_LEVELS - 1 - level) * RADIX_BITS;
    return(pid >> shift) & RADIX_MASK;
}

void *radix_lookup(radix_tree_t *tree,
                   pid_t pid)
{
    radix_node_t *node = tree->root;
    
    for(int level = 0; level < RADIX_LEVELS - 1; level++)
    {
        if(node == NULL)
        {
            return NULL;
        }
        
        int chunk = radix_chunk(pid, level);
        node = (radix_node_t *)node->slots[chunk];
    }
    
    if(node == NULL)
    {
        return NULL;
    }
    
    int chunk = radix_chunk(pid, RADIX_LEVELS - 1);
    return node->slots[chunk];
}

int radix_insert(radix_tree_t *tree,
                 pid_t pid,
                 void *value)
{
    if(tree->root == NULL)
    {
        tree->root = calloc(1, sizeof(radix_node_t));
    }
    
    radix_node_t *node = tree->root;
    
    for(int level = 0; level < RADIX_LEVELS - 1; level++)
    {
        int chunk = radix_chunk(pid, level);
        
        if(node->slots[chunk] == NULL)
        {
            node->slots[chunk] = calloc(1, sizeof(radix_node_t));
        }
        
        node = (radix_node_t *)node->slots[chunk];
    }
    
    int chunk = radix_chunk(pid, RADIX_LEVELS - 1);
    node->slots[chunk] = value;
    
    return 0;
}

void *radix_remove(radix_tree_t *tree, pid_t pid)
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
        chunks[level] = radix_chunk(pid, level);
        
        if(level < RADIX_LEVELS - 1)
        {
            node = (radix_node_t *)node->slots[chunks[level]];
        }
    }
    
    void *old = path[RADIX_LEVELS - 1]->slots[chunks[RADIX_LEVELS - 1]];
    path[RADIX_LEVELS - 1]->slots[chunks[RADIX_LEVELS - 1]] = NULL;
    
    return old;
}

static void radix_walk_node(radix_node_t *node,
                            int level,
                            pid_t pid_prefix,
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
        
        pid_t pid = pid_prefix | (i << ((RADIX_LEVELS - 1 - level) * RADIX_BITS));
        
        if(level == RADIX_LEVELS - 1)
        {
            callback(pid, node->slots[i], ctx);
        }
        else
        {
            radix_walk_node((radix_node_t *)node->slots[i], level + 1, pid, callback, ctx);
        }
    }
}

void radix_walk(radix_tree_t *tree, radix_walk_fn callback, void *ctx)
{
    radix_walk_node(tree->root, 0, 0, callback, ctx);
}
