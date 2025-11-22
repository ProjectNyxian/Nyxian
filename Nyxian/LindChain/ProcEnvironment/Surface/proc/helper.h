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

#ifndef PROC_HELPER_H
#define PROC_HELPER_H

#include <stdbool.h>

void proc_helper_lock(bool wantLock);
void proc_helper_unlock(bool wantLock);

unsigned long proc_helper_read_begin(bool wantLock);
bool proc_helper_read_retry(bool wantLock, unsigned long seq);

#endif /* PROC_HELPER_H */
