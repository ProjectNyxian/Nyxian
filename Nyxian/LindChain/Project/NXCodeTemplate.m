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
#import <LindChain/Project/NXUtils.h>

BOOL NXCodeTemplateMakeProjectStructure(NXProjectScheme scheme,
                                        NXProjectLanguage language,
                                        NXProjectInterface interface,
                                        NSString *projectName,
                                        NSURL *projectURL)
{
    assert(scheme != nil && language != nil);
    
    NSFileManager *defaultManager = [NSFileManager defaultManager];
    [NXUser shared].projectName = projectName;
    NSURL *templateURL = [[[NSBundle.mainBundle.bundleURL URLByAppendingPathComponent:@"/Shared/Templates"] URLByAppendingPathComponent:scheme] URLByAppendingPathComponent:language];
    if(interface != nil)
    {
        templateURL = [templateURL URLByAppendingPathComponent:interface];
    }
    
    NSError *error = NULL;
    NSArray<NSURL*> *folderEntries = [defaultManager contentsOfDirectoryAtURL:templateURL includingPropertiesForKeys:nil options:0 error:&error];
    if(error)
    {
        return NO;
    }
    
    NSDictionary<NSString*,NSString*> *variables = @{
        @"LDEDisplayName": projectName
    };
    
    for(NSURL *srcURL in folderEntries)
    {
        NSURL *dstURL = [projectURL URLByAppendingPathComponent:[srcURL lastPathComponent]];
        
        NSString *fileName = [dstURL lastPathComponent];
        fileName = NXSubstituteContent(fileName, variables, NO);
        dstURL = [[dstURL URLByDeletingLastPathComponent] URLByAppendingPathComponent:fileName];
        
        
        NSError *error = NULL;
        NSString *codeFileContent = [NSString stringWithContentsOfURL:srcURL encoding:NSUTF8StringEncoding error:&error];
        if(error)
        {
            return NO;
        }
        
        codeFileContent = NXSubstituteContent(codeFileContent, variables, NO);
        
        NSString *authoredCodeFileContent = [[[NXUser shared] generateHeaderForFileName: [dstURL lastPathComponent]] stringByAppendingString:codeFileContent];
        [authoredCodeFileContent writeToURL:dstURL atomically:YES encoding:NSUTF8StringEncoding error:&error];
    }
    
    return YES;
}

NSArray<NSString*> *NXCompilerFlagsForCodeTemplateLanguage(NXProjectSchemeKind schemeKind,
                                                           NXProjectLanguageKind languageKind)
{
    NSArray *baseFlags = @[
        @"-target",
        @"arm64-apple-ios$(LDEMinimumVersion)",
        @"-isysroot",
        @"$(SDKROOT)",
        @"-resource-dir",
        @"$(BSROOT)/Include",
        @"-L$(BSROOT)/lib",
        @"-lclang_rt.ios",
    ];
    
    if(schemeKind == NXProjectSchemeKindApp)
    {
        return [baseFlags arrayByAddingObjectsFromArray:@[
            @"-fobjc-arc",
            @"-framework",
            @"Foundation",
            @"-framework",
            @"UIKit"
        ]];
    }
    else
    {
        if(languageKind == NXProjectLanguageKindObjectiveC)
        {
            return [baseFlags arrayByAddingObjectsFromArray:@[
                @"-fobjc-arc",
                @"-framework",
                @"Foundation"
            ]];
        }
        else if(languageKind == NXProjectLanguageKindCXX)
        {
            return [baseFlags arrayByAddingObjectsFromArray:@[
                @"-lc++"
            ]];
        }
        else if(languageKind == NXProjectLanguageKindSwift)
        {
            /* so linker won't be confused */
            return [baseFlags arrayByAddingObjectsFromArray:@[
                @"-framework",
                @"Foundation"
            ]];
        }
    }
    
    return baseFlags;
}

NSArray<NSString*> *NXSwiftFlagsForCodeTemplateLanguage(NXProjectSchemeKind schemeKind,
                                                        NXProjectLanguageKind languageKind)
{
    if(languageKind == NXProjectLanguageKindSwift)
    {
        NSArray *baseFlags = @[
            @"-target",
            @"arm64-apple-ios$(LDEMinimumVersion)",
            @"-Xllvm",
            @"-aarch64-use-tbi",
            @"-Xfrontend",
            @"-enable-objc-interop",
            @"-sdk",
            @"$(SDKROOT)",
            @"-resource-dir",
            @"$(BSROOT)/swift",
            @"-module-cache-path",
            @"$(BSROOT)/ModuleCache",
        ];
        
        if(schemeKind == NXProjectSchemeKindApp)
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
