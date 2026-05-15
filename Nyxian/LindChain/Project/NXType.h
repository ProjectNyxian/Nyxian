/*
 SPDX-License-Identifier: AGPL-3.0-or-later

 Copyright (C) 2025 - 2026 mach-port-t

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

typedef NSString * NXProjectFormat NS_TYPED_ENUM;
static NXProjectFormat const NXProjectFormatUnknown = nil;
static NXProjectFormat const NXProjectFormatKate = @"NXKate";
static NXProjectFormat const NXProjectFormatFalcon = @"NXFalcon";
static NXProjectFormat const NXProjectFormatAvis = @"NSAvix";
static NXProjectFormat const NXProjectFormatAvisR1 = @"NSAvixR1";
static NXProjectFormat const NXProjectFormatAvisR2 = @"NXAvixR2";

typedef UInt64 NXProjectFormatKind NS_TYPED_ENUM;
static NXProjectFormatKind const NXProjectFormatKindUnknown = 0;
static NXProjectFormatKind const NXProjectFormatKindKate = 1;
static NXProjectFormatKind const NXProjectFormatKindFalcon = 2;
static NXProjectFormatKind const NXProjectFormatKindAvis = 3;
static NXProjectFormatKind const NXProjectFormatKindAvisR1 = 4;
static NXProjectFormatKind const NXProjectFormatKindAvisR2 = 5;

typedef NSString * NXProjectScheme NS_TYPED_ENUM;
static NXProjectScheme const NXProjectSchemeUnknown = nil;
static NXProjectScheme const NXProjectSchemeApp = @"Application";
static NXProjectScheme const NXProjectSchemeUtility = @"Utility";
static NXProjectScheme const NXProjectSchemeLibrary = @"Library";
static NXProjectScheme const NXProjectSchemeFramework = @"Framework";

typedef UInt64 NXProjectSchemeKind NS_TYPED_ENUM;
static NXProjectSchemeKind const NXProjectSchemeKindUnknown = 0;
static NXProjectSchemeKind const NXProjectSchemeKindApp = 1;
static NXProjectSchemeKind const NXProjectSchemeKindUtility = 2;
static NXProjectSchemeKind const NXProjectSchemeKindLibrary = 3;
static NXProjectSchemeKind const NXProjectSchemeKindFramework = 4;

typedef NSString * NXProjectLanguage NS_TYPED_ENUM;
static NXProjectLanguage const NXProjectLanguageUnknown = nil;
static NXProjectLanguage const NXProjectLanguageObjectiveC = @"ObjC";
static NXProjectLanguage const NXProjectLanguageC = @"C";
static NXProjectLanguage const NXProjectLanguageCXX = @"C++";
static NXProjectLanguage const NXProjectLanguageSwift = @"Swift";

typedef UInt64 NXProjectLanguageKind NS_TYPED_ENUM;
static NXProjectLanguageKind const NXProjectLanguageKindUnknown = 0;
static NXProjectLanguageKind const NXProjectLanguageKindObjectiveC = 1;
static NXProjectLanguageKind const NXProjectLanguageKindC = 2;
static NXProjectLanguageKind const NXProjectLanguageKindCXX = 3;
static NXProjectLanguageKind const NXProjectLanguageKindSwift = 4;

typedef NSString * NXProjectInterface NS_TYPED_ENUM;
static NXProjectInterface const NXProjectInterfaceUnknown = nil;
static NXProjectInterface const NXProjectInterfaceSwiftUI = @"SwiftUI";
static NXProjectInterface const NXProjectInterfaceUIKit = @"UIKit";

typedef UInt64 NXProjectInterfaceKind NS_TYPED_ENUM;
static NXProjectInterfaceKind const NXProjectInterfaceKindUnknown = 0;
static NXProjectInterfaceKind const NXProjectInterfaceKindSwiftUI = 1;
static NXProjectInterfaceKind const NXProjectInterfaceKindUIKit = 2;

NXProjectFormat NXProjectFormatFromFormatKind(NXProjectFormatKind kind);
NXProjectFormatKind NXProjectFormatKindFromFormat(NXProjectFormat format);

NXProjectScheme NXProjectSchemeFromSchemeKind(NXProjectSchemeKind kind);
NXProjectSchemeKind NXProjectSchemeKindFromScheme(NXProjectScheme scheme);

NXProjectInterface NXProjectInterfaceFromInterfaceKind(NXProjectInterfaceKind kind);
NXProjectInterfaceKind NXProjectInterfaceKindFromInterface(NXProjectInterface interface);

NXProjectLanguage NXProjectLanguageFromLanguageKind(NXProjectLanguageKind kind);
NXProjectLanguageKind NXProjectLanguageKindFromLanguage(NXProjectLanguage language);

BOOL NXProjectConfigurationIsValid(NXProjectSchemeKind schemeKind, NXProjectInterfaceKind interfaceKind, NXProjectLanguageKind languageKind);

#endif /* NXTYPE_H */
