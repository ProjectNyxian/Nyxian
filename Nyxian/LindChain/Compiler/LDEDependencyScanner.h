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

#ifndef LDEDEPENDENCYSCANNER_H
#define LDEDEPENDENCYSCANNER_H

#ifdef __cplusplus
extern "C" {
#endif /* __cplusplus */

typedef struct {
    char **headers;
    int count;
    bool failed;
    char *errorMsg;
} dependency_scan_result_t;

typedef struct opaque_scan_service *dependency_scan_service_t;

dependency_scan_service_t CreateScanService(void);
void FreeScanService(dependency_scan_service_t svc);

dependency_scan_result_t ScanDependencies(dependency_scan_service_t svc, int argc, const char **argv);
void FreeScanResult(dependency_scan_result_t result);

#ifdef __cplusplus
}
#endif /* __cplusplus */

#endif /* LDEDEPENDENCYSCANNER_H */
