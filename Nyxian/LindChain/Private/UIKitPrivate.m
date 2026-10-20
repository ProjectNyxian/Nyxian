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

#import <LindChain/Private/UIKitPrivate.h>

@implementation UIImage (SFCoreGlyphBundle)

- (instancetype)initWithPrivateSystemName:(NSString *)name
{
    NSBundle *const bundle = [NSClassFromString(@"SFSCoreGlyphsBundle") private];
    _UIAssetManager *const assetManager = [_UIAssetManager assetManagerForBundle:bundle];
    UIImage *raw = [assetManager imageNamed:name];
    UIImageSymbolConfiguration *cfg = [UIImageSymbolConfiguration configurationWithPointSize:17 weight:UIImageSymbolWeightRegular scale:UIImageSymbolScaleDefault];
    UIImage *configured = [raw imageByApplyingSymbolConfiguration:cfg];
    self = [configured imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    return self;
}

@end
