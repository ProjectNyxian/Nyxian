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

#import <LindChain/Project/NXCodeTemplate.h>
#import <LindChain/Project/NXUser.h>

BOOL NXCodeTemplateMakeProjectStructure(NXCodeTemplateScheme scheme,
                                        NXCodeTemplateLanguage language,
                                        NXCodeTemplateInterface interface,
                                        NSString *projectName,
                                        NSURL *projectURL)
{
    NSFileManager *defaultManager = [NSFileManager defaultManager];
    [NXUser shared].projectName = projectName;
    NSURL *templateURL = [[[NSBundle.mainBundle.bundleURL URLByAppendingPathComponent:@"/Shared/Templates"] URLByAppendingPathComponent:scheme] URLByAppendingPathComponent:language];
    if([scheme isEqualToString:NXCodeTemplateSchemeApp])
    {
        templateURL = [templateURL URLByAppendingPathComponent:interface];
    }
    
    NSError *error = NULL;
    NSArray<NSURL*> *folderEntries = [defaultManager contentsOfDirectoryAtURL:templateURL includingPropertiesForKeys:nil options:0 error:&error];
    if(error)
    {
        return NO;
    }
    
    for(NSURL *srcURL in folderEntries)
    {
        NSURL *dstURL = [projectURL URLByAppendingPathComponent:[srcURL lastPathComponent]];
        
        NSError *error = NULL;
        NSString *codeFileContent = [NSString stringWithContentsOfURL:srcURL encoding:NSUTF8StringEncoding error:&error];
        if(error)
        {
            return NO;
        }
        NSString *authoredCodeFileContent = [[[NXUser shared] generateHeaderForFileName: [dstURL lastPathComponent]] stringByAppendingString:codeFileContent];
        [authoredCodeFileContent writeToURL:dstURL atomically:YES encoding:NSUTF8StringEncoding error:&error];
    }
    
    return YES;
}

NSArray *NXCompilerFlagsForCodeTemplateLanguage(NXCodeTemplateLanguage language)
{
    if([language isEqualToString:NXCodeTemplateLanguageObjC])
    {
        return @[
            @"-target",
            @"arm64-apple-ios$(LDEMinimumVersion)",
            @"-isysroot",
            @"$(SDKROOT)",
            @"-resource-dir",
            @"$(BSROOT)/Include",
            @"-L$(BSROOT)/lib",
            @"-lclang_rt.ios",
            @"-fobjc-arc"
        ];
    }
    else if([language isEqualToString:NXCodeTemplateLanguageCpp])
    {
        return @[
            @"-target",
            @"arm64-apple-ios$(LDEMinimumVersion)",
            @"-isysroot",
            @"$(SDKROOT)",
            @"-resource-dir",
            @"$(BSROOT)/Include",
            @"-L$(BSROOT)/lib",
            @"-lclang_rt.ios",
            @"-fobjc-arc",
            @"-lc++"
        ];
    }
    else
    {
        return @[
            @"-target",
            @"arm64-apple-ios$(LDEMinimumVersion)",
            @"-isysroot",
            @"$(SDKROOT)",
            @"-resource-dir",
            @"$(BSROOT)/Include",
            @"-L$(BSROOT)/lib",
            @"-lclang_rt.ios",
            @"-framework",
            @"Foundation"
        ];
    }
}

NSArray *NXSwiftFlagsForCodeTemplateLanguage(NXCodeTemplateScheme scheme,
                                             NXCodeTemplateLanguage language)
{
    if([language isEqualToString:NXCodeTemplateLanguageSwift])
    {
        NSArray *baseFlags = @[
            @"-target",
            @"arm64-apple-ios$(LDEMinimumVersion)",
            @"-Xllvm",
            @"-aarch64-use-tbi",
            @"-enable-objc-interop",
            @"-sdk",
            @"$(SDKROOT)",
            @"-resource-dir",
            @"$(BSROOT)/swift",
            @"-module-cache-path",
            @"$(BSROOT)/ModuleCache",
            @"-no-color-diagnostics",
            @"-Xcc",
            @"-fno-color-diagnostics"
        ];
        
        if([scheme isEqualToString:NXCodeTemplateSchemeApp])
        {
            return [baseFlags arrayByAddingObject:@"-parse-as-library"];
        }
        else
        {
            return baseFlags;
        }
    }
    else
    {
        return @[];
    }
}
