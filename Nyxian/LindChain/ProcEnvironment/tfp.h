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

// MARK: This needs TXM support on-device

#ifndef PROCENVIRONMENT_TFP_H
#define PROCENVIRONMENT_TFP_H

/* ----------------------------------------------------------------------
 *  Apple API Headers
 * -------------------------------------------------------------------- */
#import <Foundation/Foundation.h>
#import <mach/mach.h>

kern_return_t environment_task_for_pid(mach_port_name_t tp_in, pid_t pid,  mach_port_name_t *tp_out);

bool environment_supports_full_tfp(void);

mach_port_t environment_tfp_create_transfer_port(task_t task);
void environment_tfp_extract_transfer_port(mach_port_t *tport);

void environment_tfp_init(void);

#endif /* PROCENVIRONMENT_TFP_H */
