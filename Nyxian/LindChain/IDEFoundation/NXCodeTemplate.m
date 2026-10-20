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

#import <LindChain/IDEFoundation/NXCodeTemplate.h>
#import <LindChain/IDEFoundation/NXUser.h>
#import <LindChain/IDEFoundation/NXUtils.h>

BOOL NXCodeTemplateMakeProjectStructure(NXProjectScheme scheme,
                                        NXProjectLanguage language,
                                        NXProjectInterface interface,
                                        NSString *projectName,
                                        NSURL *projectURL,
                                        NSString *bundleIdentifier)
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
        @"LDEDisplayName": projectName,
        @"NXBundleIdentifier": bundleIdentifier,
    };
    
    for(NSURL *srcURL in folderEntries)
    {
        NSURL *dstURL = [projectURL URLByAppendingPathComponent:[srcURL lastPathComponent]];
        
        NSString *fileName = [dstURL lastPathComponent];
        fileName = NXSubstituteContent(fileName, variables, NO);
        dstURL = [[dstURL URLByDeletingLastPathComponent] URLByAppendingPathComponent:fileName];
        
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
        @"arm64-apple-ios$(NXDeploymentTarget)",
        @"-isysroot",
        @"$(SDKROOT)",
        @"-resource-dir",
        @"$(BSROOT)/Include",
        @"-L$(BSROOT)/lib",
        @"-lclang_rt.ios",
        @"-fmodules",
    ];
    
    if(schemeKind == NXProjectSchemeKindApp)
    {
        return [baseFlags arrayByAddingObjectsFromArray:@[
            @"-fobjc-arc",
        ]];
    }
    else if(schemeKind == NXProjectSchemeKindUtility)
    {
        if(languageKind == NXProjectLanguageKindObjectiveC)
        {
            return [baseFlags arrayByAddingObjectsFromArray:@[
                @"-fobjc-arc",
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
            /* so people won't be confused on how to add framework flags */
            return [baseFlags arrayByAddingObjectsFromArray:@[
                @"-fobjc-arc",
            ]];
        }
    }
    else
    {
        return @[
            /* target */
            @"-target",
            @"arm64-apple-ios$(NXDeploymentTarget)",
            @"-isysroot",
            @"$(SDKROOT)",
            @"-resource-dir",
            @"$(BSROOT)/Include",
            @"-I$(SHDROOT)/kernel",
            @"-DHOST_ENV",              /* kext becomes Nyxian */
            
            /* main kext flags */
            @"-bundle",
            @"-ffreestanding",
            @"-fno-builtin",
            @"-fno-common",
            @"-fno-stack-protector",
            @"-nostdlib",
            
            /* relaxing the damn linker */
            @"-Wl,-undefined,dynamic_lookup",
            @"-Wl,-adhoc_codesign", /* they shall have LC_CODE_SIGNATURE */
        ];
    }
    
    return baseFlags;
}

NSArray<NSString*> *NXSwiftFlagsForCodeTemplateLanguage(NXProjectSchemeKind schemeKind,
                                                        NXProjectLanguageKind languageKind)
{
    if(schemeKind == NXProjectSchemeKindKSurfaceKext)
    {
        return @[];
    }
    
    NSArray *baseFlags = @[
        @"-target",
        @"arm64-apple-ios$(NXDeploymentTarget)",
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
    
    if(schemeKind == NXProjectSchemeKindApp ||
       languageKind != NXProjectLanguageKindSwift)  /* parse as library because swift is not the main language */
    {
        return [baseFlags arrayByAddingObject:@"-parse-as-library"];
    }
    else
    {
        return baseFlags;
    }
}
