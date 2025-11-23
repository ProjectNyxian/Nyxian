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

#import <LindChain/ProcEnvironment/Sysctl/sysctl.h>
#import <LindChain/ProcEnvironment/Surface/surface.h>
#include <errno.h>

int sysctl_kernprocall(sysctl_req_t *req)
{
    if(!req->oldlenp)
    {
        errno = EINVAL;
        return -1;
    }
    
    size_t needed = proc_sysctl_listproc(NULL, 0, NULL);
    
    if(req->oldp == NULL || *(req->oldlenp) == 0)
    {
        *(req->oldlenp) = needed;
        return 0;
    }
    
    if(*(req->oldlenp) < needed)
    {
        *(req->oldlenp) = needed;
        errno = ENOMEM;
        return -1;
    }
    
    int written = proc_sysctl_listproc(req->oldp, *(req->oldlenp), NULL);
    if(written < 0) return -1;
    
    *(req->oldlenp) = written;
    return 0;
}
