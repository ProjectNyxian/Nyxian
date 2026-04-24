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

#ifndef NXTYPE_H
#define NXTYPE_H

#import <Foundation/Foundation.h>

typedef int NXProjectType NS_TYPED_ENUM;
static NXProjectType const NXProjectTypeAny = 0;
static NXProjectType const NXProjectTypeApp = 1;
static NXProjectType const NXProjectTypeUtility = 2;

typedef int NXProjectFormat NS_TYPED_ENUM;
static NXProjectFormat const NXProjectFormatKate = 0;
static NXProjectFormat const NXProjectFormatFalcon = 1;
static NXProjectFormat const NXProjectFormatDefault = NXProjectFormatKate;

typedef NSString * NXCodeTemplateScheme NS_TYPED_ENUM;
static NXCodeTemplateScheme const NXCodeTemplateSchemeInvalid = @"";
static NXCodeTemplateScheme const NXCodeTemplateSchemeApp = @"Application";
static NXCodeTemplateScheme const NXCodeTemplateSchemeUtility = @"Utility";

typedef NSString * NXCodeTemplateLanguage NS_TYPED_ENUM;
static NXCodeTemplateLanguage const NXCodeTemplateLanguageObjC = @"ObjC";
static NXCodeTemplateLanguage const NXCodeTemplateLanguageC = @"C";
static NXCodeTemplateLanguage const NXCodeTemplateLanguageCpp = @"C++";
static NXCodeTemplateLanguage const NXCodeTemplateLanguageSwift = @"Swift";

NXCodeTemplateScheme NXCodeTemplateSchemeFromProjectType(NXProjectType type);

#endif /* NXTYPE_H */
