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

#ifndef PROCENVIRONMENT_LIMITS_H
#define PROCENVIRONMENT_LIMITS_H

/*
 * im sorry if you complain about the
 * amount of maximum processes, dont
 * complain about this to me, complain
 * about this to apple, their the reason
 * why, launchd doesnt let us spawn more.
 */
#define PROC_MAX 1024

/*
 * why would a process need more than 128
 * childs?
 */
#define CHILD_PROC_MAX 128

/*
 * the maximum count of pid that the
 * radix tree supports.
 */
#define PID_MAX 1048575

#endif /* PROCENVIRONMENT_LIMITS_H */
