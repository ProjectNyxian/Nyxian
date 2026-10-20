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

#ifndef PROCENVIRONMENT_APPLICATION_H
#define PROCENVIRONMENT_APPLICATION_H

/*!
 @function environment_application_init
 @abstract Initializes application environment.
 @discussion
    These fixes are supposed to fix headless programs. So they can choose if they rather wanna run a GUI or a CLI process or a being a background daemon.
 */
void environment_application_init(void);

#endif /* PROCENVIRONMENT_APPLICATION_H */
