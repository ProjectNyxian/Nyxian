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

#import "LDEApplicationObject.h"
#import "LDEApplicationWorkspaceInternal.h"
#import "ISIcon.h"

#import <UIKit/UIKit.h>

@implementation LDEApplicationObject

- (instancetype)initWithBundle:(MIBundle*)miBundle
{
    self = [super init];
    
    MIExecutableBundle *bundle = [[PrivClass(MIExecutableBundle) alloc] initWithBundleURL:miBundle.bundleURL error:nil];
    
    self.bundleIdentifier = bundle.identifier;
    self.displayName = bundle.displayName;
    self.isLaunchAllowed = [[LDEApplicationWorkspaceInternal shared] doWeTrustThatBundle:bundle];
    if(self.isLaunchAllowed)
    {
        self.bundlePath = [[bundle bundleURL] path];
        self.executablePath = [[bundle executableURL] path];
        self.containerPath = [[[LDEApplicationWorkspaceInternal shared] applicationContainerForBundleID:bundle.identifier] path];
    }
    
    ISBundleIcon *bundleIcon = [[PrivClass(ISBundleIcon) alloc] initWithBundleURL:bundle.bundleURL type:nil];
    if(bundleIcon)
    {
        ISResourceProvider *provider = [bundleIcon _makeAppResourceProvider];
        if(provider.isGenericProvider) return self;
        
        ISAssetCatalogResource *resources = [provider iconResource];
        if ([resources isKindOfClass:NSClassFromString(@"IFImageBag")])
        {
            IFImageBag *imageBag = (IFImageBag*)resources;
            IFImage *image = [imageBag imageForSize:CGSizeMake(1024, 1024) scale:3.0];
            self.icon = [UIImage imageWithCGImage:image.CGImage scale:3.0 orientation:UIImageOrientationUp];
            return self;
        }
        
        IFImage *image = [resources imageForSize:CGSizeMake(1024, 1024) scale:3.0];
        self.icon = [UIImage imageWithCGImage:image.CGImage scale:3.0 orientation:UIImageOrientationUp];
    }

    return self;
}

- (instancetype)initWithNSBundle:(NSBundle*)nsBundle
{
    self = [super init];
    
    MIExecutableBundle *bundle = [[PrivClass(MIExecutableBundle) alloc] initWithBundleURL:nsBundle.bundleURL error:nil];
    
    self.bundleIdentifier = bundle.identifier;
    self.displayName = bundle.displayName;
    self.isLaunchAllowed = [[LDEApplicationWorkspaceInternal shared] doWeTrustThatBundle:bundle];
    if(self.isLaunchAllowed)
    {
        self.bundlePath = [[bundle bundleURL] path];
        self.executablePath = [[bundle executableURL] path];
        self.containerPath = [[[LDEApplicationWorkspaceInternal shared] applicationContainerForBundleID:bundle.identifier] path];
    }
    
    ISBundleIcon *bundleIcon = [[PrivClass(ISBundleIcon) alloc] initWithBundleURL:bundle.bundleURL type:nil];
    if(bundleIcon)
    {
        ISResourceProvider *provider = [bundleIcon _makeAppResourceProvider];
        if(provider.isGenericProvider) return self;
        
        ISAssetCatalogResource *resources = [provider iconResource];
        if ([resources isKindOfClass:NSClassFromString(@"IFImageBag")])
        {
            IFImageBag *imageBag = (IFImageBag*)resources;
            IFImage *image = [imageBag imageForSize:CGSizeMake(1024, 1024) scale:3.0];
            self.icon = [UIImage imageWithCGImage:image.CGImage scale:3.0 orientation:UIImageOrientationUp];
            return self;
        }
        
        IFImage *image = [resources imageForSize:CGSizeMake(1024, 1024) scale:3.0];
        self.icon = [UIImage imageWithCGImage:image.CGImage scale:3.0 orientation:UIImageOrientationUp];
    }

    return self;
}

+ (BOOL)supportsSecureCoding {
    return YES;
}

- (void)encodeWithCoder:(nonnull NSCoder *)coder
{
    [coder encodeObject:self.bundleIdentifier forKey:@"bundleIdentifier"];
    [coder encodeObject:self.bundlePath forKey:@"bundlePath"];
    [coder encodeObject:self.executablePath forKey:@"executablePath"];
    [coder encodeObject:self.displayName forKey:@"displayName"];
    [coder encodeObject:self.containerPath forKey:@"containerPath"];
    [coder encodeObject:self.icon forKey:@"icon"];
    [coder encodeObject:@(self.isLaunchAllowed) forKey:@"isLaunchAllowed"];
}

- (nullable instancetype)initWithCoder:(nonnull NSCoder *)coder
{
    if(self = [super init])
    {
        _bundleIdentifier = [coder decodeObjectOfClass:[NSString class] forKey:@"bundleIdentifier"];
        _bundlePath = [coder decodeObjectOfClass:[NSString class] forKey:@"bundlePath"];
        _executablePath = [coder decodeObjectOfClass:[NSString class] forKey:@"executablePath"];
        _displayName = [coder decodeObjectOfClass:[NSString class] forKey:@"displayName"];
        _containerPath = [coder decodeObjectOfClass:[NSString class] forKey:@"containerPath"];
        _icon = [coder decodeObjectOfClass:[UIImage class] forKey:@"icon"];
        _isLaunchAllowed = [[coder decodeObjectOfClass:[NSNumber class] forKey:@"isLaunchAllowed"] boolValue];
    }
    return self;
}

@end

@implementation LDEApplicationObjectArray

- (instancetype)initWithApplicationObjects:(NSArray<LDEApplicationObject *> *)applicationObjects
{
    self = [super init];
    _applicationObjects = applicationObjects;
    return self;
}

+ (BOOL)supportsSecureCoding {
    return YES;
}

- (void)encodeWithCoder:(nonnull NSCoder *)coder {
    [coder encodeObject:self.applicationObjects forKey:@"appObjs"];
}

- (nullable instancetype)initWithCoder:(nonnull NSCoder *)coder {
    if(self = [super init])
    {
        _applicationObjects = [coder decodeObjectOfClasses:[NSSet setWithObjects:
                    [NSArray class], [LDEApplicationObject class], nil]
                                                            forKey:@"appObjs"];
    }
    return self;
}

@end
