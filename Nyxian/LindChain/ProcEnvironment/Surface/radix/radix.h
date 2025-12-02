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

#ifndef RADIX_H
#define RADIX_H

#import <LindChain/ProcEnvironment/Surface/radix/type/tree.h>
#include <stdlib.h>

typedef void (*radix_walk_fn)(pid_t pid, void *value, void *ctx);

void *radix_lookup(radix_tree_t *tree, pid_t pid);
int radix_insert(radix_tree_t *tree, pid_t pid, void *value);
void *radix_remove(radix_tree_t *tree, pid_t pid);
void radix_walk(radix_tree_t *tree, radix_walk_fn callback, void *ctx);

#endif /* RADIX_H */
