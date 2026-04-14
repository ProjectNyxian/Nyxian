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
                                        NSString *projectName,
                                        NSString *projectPath)
{
    NSFileManager *defaultManager = [NSFileManager defaultManager];
    if(![defaultManager fileExistsAtPath:projectPath])
    {
        return NO;
    }
    [NXUser shared].projectName = projectName;
    NSString *templatePath = [[[NSString stringWithFormat:@"%@/Shared/Templates", [[NSBundle mainBundle] bundlePath]] stringByAppendingPathComponent:scheme] stringByAppendingPathComponent:language];
    
    NSError *error = NULL;
    NSArray *folderEntries = [defaultManager contentsOfDirectoryAtPath:templatePath error:&error];
    if(error)
    {
        return NO;
    }
    
    for(NSString *folderEntry in folderEntries)
    {
        NSString *srcPath = [templatePath stringByAppendingFormat:@"/%@", folderEntry];
        NSString *dstPath = [projectPath stringByAppendingFormat:@"/%@", folderEntry];
        
        NSError *error = NULL;
        NSString *codeFileContent = [NSString stringWithContentsOfFile:srcPath encoding:NSUTF8StringEncoding error:&error];
        if(error)
        {
            return NO;
        }
        NSString *authoredCodeFileContent = [[[NXUser shared] generateHeaderForFileName: [[NSURL URLWithString:dstPath] lastPathComponent]] stringByAppendingString:codeFileContent];
        [authoredCodeFileContent writeToFile:dstPath atomically:YES encoding:NSUTF8StringEncoding error:&error];
    }
    
    return YES;
}

NSArray *NXCompilerFlagsForCodeTemplateLanguage(NXCodeTemplateLanguage language)
{
    if([language isEqualToString:NXCodeTemplateLanguageC])
    {
        return @[
            @"-target",
            @"arm64-apple-ios$(LDEMinimumVersion)",
            @"-resource-dir",
            @"$(BSROOT)/Include",
            @"-isysroot",
            @"$(SDKROOT)",
            @"-L$(BSROOT)/lib",
            @"-lc",
            @"-lclang_rt.ios"
        ];
    }
    else if([language isEqualToString:NXCodeTemplateLanguageCpp])
    {
        return @[
            @"-target",
            @"arm64-apple-ios$(LDEMinimumVersion)",
            @"-resource-dir",
            @"$(BSROOT)/Include",
            @"-isysroot",
            @"$(SDKROOT)",
            @"-L$(BSROOT)/lib",
            @"-lc",
            @"-lc++",
            @"-lclang_rt.ios"
        ];
    }
    else if([language isEqualToString:NXCodeTemplateLanguageObjC])
    {
        return @[
            @"-target",
            @"arm64-apple-ios$(LDEMinimumVersion)",
            @"-resource-dir",
            @"$(BSROOT)/Include",
            @"-isysroot",
            @"$(SDKROOT)",
            @"-L$(BSROOT)/lib",
            @"-lc",
            @"-lclang_rt.ios",
            @"-framework",
            @"Foundation",
        ];
    }
    return nil;
}
