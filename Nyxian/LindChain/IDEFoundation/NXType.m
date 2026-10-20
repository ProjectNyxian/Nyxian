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

#import <Foundation/Foundation.h>
#import <LindChain/IDEFoundation/NXType.h>

NXProjectFormat NXProjectFormatFromFormatKind(NXProjectFormatKind kind)
{
    switch(kind)
    {
        case NXProjectFormatKindKate: return NXProjectFormatKate;
        case NXProjectFormatKindFalcon: return NXProjectFormatFalcon;
        case NXProjectFormatKindAvis: return NXProjectFormatAvis;
        case NXProjectFormatKindAvisR1: return NXProjectFormatAvisR1;
        case NXProjectFormatKindAvisR2: return NXProjectFormatAvisR2;
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
    else if([format isEqualToString:NXProjectFormatAvisR1])
    {
        return NXProjectFormatKindAvisR1;
    }
    else if([format isEqualToString:NXProjectFormatAvisR2])
    {
        return NXProjectFormatKindAvisR2;
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
        case NXProjectSchemeKindKSurfaceKext: return NXProjectSchemeKSurfaceKext;
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
    else if([scheme isEqualToString:NXProjectSchemeKSurfaceKext])
    {
        return NXProjectSchemeKindKSurfaceKext;
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
    else if(schemeKind == NXProjectSchemeKindKSurfaceKext)
    {
        if(interfaceKind == NXProjectInterfaceKindUnknown)
        {
            return YES;
        }
    }
    
    /* defaulting to invalidation */
    return NO;
}
