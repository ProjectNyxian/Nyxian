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

#import <LindChain/Compiler/LDEDependencyScanner.h>
#include <clang/Tooling/DependencyScanning/DependencyScanningTool.h>
#include <clang/Tooling/DependencyScanning/DependencyScanningService.h>
#include <clang/Tooling/CompilationDatabase.h>
#include <llvm/Support/VirtualFileSystem.h>

using namespace clang;
using namespace clang::tooling::dependencies;

struct opaque_scan_service {
    DependencyScanningService service;
    opaque_scan_service() : service(ScanningMode::DependencyDirectivesScan, ScanningOutputFormat::Make, ScanningOptimizations::None, false) {}
};

extern "C" {

dependency_scan_service_t CreateScanService(void)
{
    return new opaque_scan_service();
}

void FreeScanService(dependency_scan_service_t svc)
{
    delete static_cast<opaque_scan_service *>(svc);
}

dependency_scan_result_t ScanDependencies(dependency_scan_service_t svc, int argc, const char **argv)
{
    dependency_scan_result_t out = {nullptr, 0, 0, nullptr};
    DependencyScanningTool tool(static_cast<opaque_scan_service *>(svc)->service);
    
    std::vector<std::string> args(argv, argv + argc);
    
    std::string sysroot;
    std::string resourceDir;
    for(size_t i = 0; i < args.size(); i++)
    {
        if(args[i] == "-isysroot" && i + 1 < args.size())
        {
            sysroot = args[i + 1];
            i++;
        }
        else if(llvm::StringRef(args[i]).starts_with("-isysroot") && args[i].size() > 9)
        {
            sysroot = args[i].substr(9);
        }
        else if(args[i] == "-resource-dir" && i + 1 < args.size())
        {
            resourceDir = args[i + 1];
            i++;
        }
        else if(llvm::StringRef(args[i]).starts_with("-resource-dir="))
        {
            resourceDir = args[i].substr(strlen("-resource-dir="));
        }
    }
    
    llvm::Expected<std::string> depsOrErr = tool.getDependencyFile(args, "/");
    if(!depsOrErr)
    {
        std::string errStr = llvm::toString(depsOrErr.takeError());
        out.failed   = 1;
        out.errorMsg = strdup(errStr.c_str());
        return out;
    }
    
    std::string depStr = *depsOrErr;
    size_t colonPos = depStr.find(':');
    if(colonPos == std::string::npos)
    {
        out.failed = 1;
        out.errorMsg = strdup("dependency scan produced no output");
        return out;
    }
    
    std::vector<std::string> headers;
    llvm::StringRef remaining(depStr.c_str() + colonPos + 1);
    llvm::SmallVector<llvm::StringRef, 32> tokens;
    remaining.split(tokens, ' ', -1, false);
    
    bool first = true;
    for(llvm::StringRef token : tokens)
    {
        token = token.trim(" \t\n\r\\");
        if(token.empty()) continue;
        if(first) { first = false; continue; }
        if(!sysroot.empty() && token.starts_with(sysroot)) continue;
        if(!resourceDir.empty() && token.starts_with(resourceDir)) continue;
        headers.push_back(token.str());
    }
    
    out.headers = (char **)malloc(sizeof(char *) * headers.size());
    for(size_t i = 0; i < headers.size(); i++)
    {
        out.headers[i] = strdup(headers[i].c_str());
    }
    out.count = (int)headers.size();
    return out;
}

void FreeScanResult(dependency_scan_result_t result)
{
    for(int i = 0; i < result.count; i++)
    {
        free(result.headers[i]);
    }
    free(result.headers);
    if(result.errorMsg)
    {
        free(result.errorMsg);
    }
}

}
