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

#import <Foundation/Foundation.h>
#import <LindChain/Project/NXType.h>

NXProjectFormat NXProjectFormatFromFormatKind(NXProjectFormatKind kind)
{
    switch(kind)
    {
        case NXProjectFormatKindKate: return NXProjectFormatKate;
        case NXProjectFormatKindFalcon: return NXProjectFormatFalcon;
        case NXProjectFormatKindAvis: return NXProjectFormatAvis;
        default: return NXProjectFormatUnknown;
    }
}

NXProjectFormatKind NXProjectFormatKindFromFormat(NXProjectFormat format)
{
    if([format isEqualToString:NXProjectFormatKate])
    {
        return NXProjectFormatKindKate;
    }
    else if([format isEqualToString:NXProjectFormatFalcon])
    {
        return NXProjectFormatKindFalcon;
    }
    else if([format isEqualToString:NXProjectFormatAvis])
    {
        return NXProjectFormatKindAvis;
    }
    return NXProjectFormatKindUnknown;
}

NXProjectScheme NXProjectSchemeFromSchemeKind(NXProjectSchemeKind kind)
{
    switch(kind)
    {
        case NXProjectSchemeKindApp: return NXProjectSchemeApp;
        case NXProjectSchemeKindUtility: return NXProjectSchemeUtility;
        case NXProjectSchemeKindLibrary: return NXProjectSchemeLibrary;
        case NXProjectSchemeKindFramework: return NXProjectSchemeFramework;
        default: return NXProjectSchemeUnknown;
    }
}

NXProjectSchemeKind NXProjectSchemeKindFromScheme(NXProjectScheme scheme)
{
    if([scheme isEqualToString:NXProjectSchemeApp])
    {
        return NXProjectSchemeKindApp;
    }
    else if([scheme isEqualToString:NXProjectSchemeUtility])
    {
        return NXProjectSchemeKindUtility;
    }
    else if([scheme isEqualToString:NXProjectSchemeLibrary])
    {
        return NXProjectSchemeKindLibrary;
    }
    else if([scheme isEqualToString:NXProjectSchemeFramework])
    {
        return NXProjectSchemeKindFramework;
    }
    return NXProjectSchemeKindUnknown;
}

NXProjectInterface NXProjectInterfaceFromInterfaceKind(NXProjectInterfaceKind kind)
{
    switch(kind)
    {
        case NXProjectInterfaceKindSwiftUI: return NXProjectInterfaceSwiftUI;
        case NXProjectInterfaceKindUIKit: return NXProjectInterfaceUIKit;
        default: return NXProjectInterfaceUnknown;
    }
}

NXProjectInterfaceKind NXProjectInterfaceKindFromInterface(NXProjectInterface interface)
{
    if([interface isEqualToString:NXProjectInterfaceSwiftUI])
    {
        return NXProjectInterfaceKindSwiftUI;
    }
    else if([interface isEqualToString:NXProjectInterfaceUIKit])
    {
        return NXProjectInterfaceKindUIKit;
    }
    return NXProjectInterfaceKindUnknown;
}

NXProjectLanguage NXProjectLanguageFromLanguageKind(NXProjectLanguageKind kind)
{
    switch(kind)
    {
        case NXProjectLanguageKindObjectiveC: return NXProjectLanguageObjectiveC;
        case NXProjectLanguageKindC: return NXProjectLanguageC;
        case NXProjectLanguageKindCXX: return NXProjectLanguageCXX;
        case NXProjectLanguageKindSwift: return NXProjectLanguageSwift;
        default: return NXProjectLanguageUnknown;
    }
}

NXProjectLanguageKind NXProjectLanguageKindFromLanguage(NXProjectLanguage language)
{
    if([language isEqualToString:NXProjectLanguageObjectiveC])
    {
        return NXProjectLanguageKindObjectiveC;
    }
    else if([language isEqualToString:NXProjectLanguageC])
    {
        return NXProjectLanguageKindC;
    }
    else if([language isEqualToString:NXProjectLanguageCXX])
    {
        return NXProjectLanguageKindCXX;
    }
    else if([language isEqualToString:NXProjectLanguageObjectiveC])
    {
        return NXProjectLanguageKindObjectiveC;
    }
    return NXProjectLanguageKindUnknown;
}

BOOL NXProjectConfigurationIsValid(NXProjectSchemeKind schemeKind,
                                   NXProjectInterfaceKind interfaceKind,
                                   NXProjectLanguageKind languageKind)
{
    if(schemeKind == NXProjectSchemeKindApp)
    {
        if(languageKind == NXProjectLanguageKindSwift)
        {
            if(interfaceKind == NXProjectInterfaceKindSwiftUI || interfaceKind == NXProjectInterfaceKindUIKit)
            {
                return YES;
            }
        }
        else if(languageKind == NXProjectLanguageKindObjectiveC)
        {
            if(interfaceKind == NXProjectInterfaceKindUIKit)
            {
                return YES;
            }
        }
    }
    else if(schemeKind == NXProjectSchemeKindUtility)
    {
        if(interfaceKind == NXProjectInterfaceKindUnknown)
        {
            /*
             * later checks like getting the the language
             * from kind will reveil failure if applicable.
             */
            return YES;
        }
    }
    
    /* defaulting to invalidation */
    return NO;
}
