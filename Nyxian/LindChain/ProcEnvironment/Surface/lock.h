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

#ifndef PROCENVIRONMENT_LOCK_H
#define PROCENVIRONMENT_LOCK_H

#define proc_table_rdlock() pthread_rwlock_rdlock(&(ksurface->proc_info.struct_lock))
#define proc_table_wrlock() pthread_rwlock_wrlock(&(ksurface->proc_info.struct_lock))
#define proc_table_unlock() pthread_rwlock_unlock(&(ksurface->proc_info.struct_lock))

#define host_rdlock() pthread_rwlock_rdlock(&(ksurface->host_info.struct_lock))
#define host_wrlock() pthread_rwlock_wrlock(&(ksurface->host_info.struct_lock))
#define host_unlock() pthread_rwlock_unlock(&(ksurface->host_info.struct_lock))

#define task_rdlock() pthread_rwlock_rdlock(&(ksurface->proc_info.task_lock))
#define task_wrlock() pthread_rwlock_wrlock(&(ksurface->proc_info.task_lock))
#define task_unlock() pthread_rwlock_unlock(&(ksurface->proc_info.task_lock))

#endif /* PROCENVIRONMENT_LOCK_H */
