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

#import <Foundation/Foundation.h>

typedef NSString * NXCodeTemplateScheme NS_TYPED_ENUM;
static NXCodeTemplateScheme const NXCodeTemplateSchemeApp = @"Application";
static NXCodeTemplateScheme const NXCodeTemplateSchemeUtility = @"Utility";

typedef NSString * NXCodeTemplateLanguage NS_TYPED_ENUM;
static NXCodeTemplateLanguage const NXCodeTemplateLanguageSelf = @"Self";       /* For types that are based on it self */
static NXCodeTemplateLanguage const NXCodeTemplateLanguageObjC = @"ObjC";
static NXCodeTemplateLanguage const NXCodeTemplateLanguageC = @"C";

@interface NXCodeTemplate : NSObject

- (void)generateCodeStructureFromTemplateScheme:(NXCodeTemplateScheme)scheme
                                   withLanguage:(NXCodeTemplateLanguage)language
                                withProjectName:(NSString*)projectName
                                       intoPath:(NSString*)path;
+ (NXCodeTemplate*)shared;

@end
