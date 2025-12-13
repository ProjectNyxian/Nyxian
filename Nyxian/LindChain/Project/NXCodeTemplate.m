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

#import <LindChain/Project/NXCodeTemplate.h>
#import <LindChain/Project/NXUser.h>

@implementation NXCodeTemplate

- (void)createAuthoredCodeFileFromSourceFileAtPath:(NSString*)srcPath
                                            toPath:(NSString*)dstPath
{
    if(![[NSFileManager defaultManager] fileExistsAtPath:srcPath])
        return;
    
    NSError *error = NULL;
    NSString *codeFileContent = [NSString stringWithContentsOfFile:srcPath encoding:NSUTF8StringEncoding error:&error];
    if(error)
        return;
    NSString *authoredCodeFileContent = [[[NXUser shared] generateHeaderForFileName: [[NSURL URLWithString:dstPath] lastPathComponent]] stringByAppendingString:codeFileContent];
    [authoredCodeFileContent writeToFile:dstPath atomically:YES encoding:NSUTF8StringEncoding error:&error];
}

- (void)generateCodeStructureFromTemplateScheme:(NXCodeTemplateScheme)scheme
                                   withLanguage:(NXCodeTemplateLanguage)language
                                withProjectName:(NSString*)projectName
                                       intoPath:(NSString*)path
{
    NSFileManager *defaultManager = [NSFileManager defaultManager];
    if(![defaultManager fileExistsAtPath:path])
        return;
    [NXUser shared].projectName = projectName;
    NSString *templatePath = [[[NSString stringWithFormat:@"%@/Shared/Templates", [[NSBundle mainBundle] bundlePath]] stringByAppendingPathComponent:scheme] stringByAppendingPathComponent:language];
    
    NSError *error = NULL;
    NSArray *folderEntries = [defaultManager contentsOfDirectoryAtPath:templatePath error:&error];
    if(error)
        return;
    
    for(NSString *folderEntry in folderEntries)
    {
        [self createAuthoredCodeFileFromSourceFileAtPath:[templatePath stringByAppendingFormat:@"/%@", folderEntry] toPath:[path stringByAppendingFormat:@"/%@", folderEntry]];
    }
}

+ (NXCodeTemplate*)shared
{
    static NXCodeTemplate *nxCodeTemplateSingleton = NULL;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        nxCodeTemplateSingleton = [[NXCodeTemplate alloc] init];
    });
    return nxCodeTemplateSingleton;
}

@end
