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

#import <LindChain/Multitask/ProcessManager/LDEProcessManager.h>
#import <LindChain/Multitask/WindowServer/LaunchPad/LDEAppLaunchpad.h>
#import <LindChain/Multitask/WindowServer/LaunchPad/LDEAppCell.h>
#import <LindChain/Services/applicationmgmtd/LDEApplicationWorkspace.h>
#import <LindChain/ProcEnvironment/Surface/entitlement.h>
#import <LindChain/Services/trustd/LDETrust.h>
#import <LindChain/ProcEnvironment/Server/Trust.h>

NSArray *entitlementsMenuStructure = @[
    @{
        @"title": @"Task Port (iOS 26.0 Only)",
        @"icon": @"powerplug.portrait.fill",
        @"items": @[
            @{@"name": @"Get Task Allowed", @"value": @(PEEntitlementGetTaskAllowed)},
            @{@"name": @"Task for Pid", @"value": @(PEEntitlementTaskForPid)},
            @{@"name": @"Task for Host Pid", @"value": @(PEEntitlementTaskForPidHost)}
        ]
    },
    @{
        @"title": @"Process",
        @"icon": @"cable.coaxial",
        @"items": @[
            @{@"name": @"Enumeration", @"value": @(PEEntitlementProcessEnumeration)},
            @{@"name": @"Kill", @"value": @(PEEntitlementProcessKill)},
            @{@"name": @"Spawn (Unsigned)", @"value": @(PEEntitlementProcessSpawn)},
            @{@"name": @"Spawn (Signed Only)", @"value": @(PEEntitlementProcessSpawnSignedOnly)},
            @{@"name": @"Spawn (Inherite Entitlements)", @"value": @(PEEntitlementProcessSpawnInheriteEntitlements)},
            @{@"name": @"Elevate", @"value": @(PEEntitlementProcessElevate)}
        ]
    },
    @{
        @"title": @"Host",
        @"icon": @"pc",
        @"items": @[
            @{@"name": @"Host Manager", @"value": @(PEEntitlementHostManager)},
            @{@"name": @"Credentials Manager", @"value": @(PEEntitlementCredentialsManager)}
        ]
    },
    @{
        @"title": @"LaunchServices",
        @"icon": @"bolt.fill",
        @"items": @[
            @{@"name": @"Start", @"value": @(PEEntitlementLaunchServicesStart)},
            @{@"name": @"Stop", @"value": @(PEEntitlementLaunchServicesStop)},
            @{@"name": @"Toggle", @"value": @(PEEntitlementLaunchServicesToggle)},
            @{@"name": @"Get Endpoint", @"value": @(PEEntitlementLaunchServicesGetEndpoint)},
            @{@"name": @"Manager", @"value": @(PEEntitlementLaunchServicesManager)}
        ]
    },
    @{
        @"title": @"TrustCache",
        @"icon": @"tray.full.fill",
        @"items": @[
            @{@"name": @"Read", @"value": @(PEEntitlementTrustCacheRead)},
            @{@"name": @"Write", @"value": @(PEEntitlementTrustCacheWrite)},
            @{@"name": @"Manager", @"value": @(PEEntitlementTrustCacheManager)}
        ]
    },
    @{
        @"title": @"Misc",
        @"icon": @"ellipsis",
        @"items": @[
            @{@"name": @"Platform", @"value": @(PEEntitlementPlatform)},
            @{@"name": @"Enforce Device Spoof", @"value": @(PEEntitlementEnforceDeviceSpoof)},
            @{@"name": @"DYLD Hide LiveProcess", @"value": @(PEEntitlementDyldHideLiveProcess)}
        ]
    }
];

@interface LDEAppLaunchpad ()

@property (nonatomic, strong) UICollectionView *collectionView;
@property (nonatomic, strong) NSMutableArray<LDEAppEntry *> *apps;
@property (nonatomic, strong) UISearchBar *searchBar;
@property (nonatomic, strong) NSArray<LDEAppEntry *> *filteredApps;
@property (nonatomic, strong) UIStackView *emptyStack;

@end

@implementation LDEAppLaunchpad

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    [[LDEApplicationWorkspace shared] ping];
    _apps = [NSMutableArray array];
    _filteredApps = [NSArray array];
    [self setupUI];
    return self;
}

- (void)setupUI
{
    self.backgroundColor = [UIColor clearColor];
    
    _searchBar = [[UISearchBar alloc] init];
    _searchBar.translatesAutoresizingMaskIntoConstraints = NO;
    _searchBar.placeholder = @"Search Apps";
    _searchBar.searchBarStyle = UISearchBarStyleMinimal;
    _searchBar.delegate = self;
    _searchBar.backgroundImage = [UIImage new];
    _searchBar.tintColor = [UIColor systemBlueColor];
    [self addSubview:_searchBar];
    
    UICollectionViewFlowLayout *layout = [[UICollectionViewFlowLayout alloc] init];
    layout.itemSize = CGSizeMake(70, 85);
    layout.minimumInteritemSpacing = 20;
    layout.minimumLineSpacing = 20;
    layout.sectionInset = UIEdgeInsetsMake(20, 20, 20, 20);
    
    _collectionView = [[UICollectionView alloc] initWithFrame:CGRectZero collectionViewLayout:layout];
    _collectionView.translatesAutoresizingMaskIntoConstraints = NO;
    _collectionView.backgroundColor = [UIColor clearColor];
    _collectionView.delegate = self;
    _collectionView.dataSource = self;
    _collectionView.showsVerticalScrollIndicator = NO;
    _collectionView.showsHorizontalScrollIndicator = NO;
    _collectionView.alwaysBounceVertical = YES;
    _collectionView.keyboardDismissMode = UIScrollViewKeyboardDismissModeOnDrag;
    [_collectionView registerClass:[LDEAppCell class] forCellWithReuseIdentifier:@"AppCell"];
    [self addSubview:_collectionView];
    
    [self setupEmptyState];
    
    [NSLayoutConstraint activateConstraints:@[
        [_searchBar.topAnchor constraintEqualToAnchor:self.topAnchor constant:10],
        [_searchBar.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:10],
        [_searchBar.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-10],
        [_searchBar.heightAnchor constraintEqualToConstant:44],
        
        [_collectionView.topAnchor constraintEqualToAnchor:_searchBar.bottomAnchor constant:10],
        [_collectionView.leadingAnchor constraintEqualToAnchor:self.leadingAnchor],
        [_collectionView.trailingAnchor constraintEqualToAnchor:self.trailingAnchor],
        [_collectionView.bottomAnchor constraintEqualToAnchor:self.bottomAnchor],
        
        [_emptyStack.centerXAnchor constraintEqualToAnchor:_collectionView.centerXAnchor],
        [_emptyStack.centerYAnchor constraintEqualToAnchor:_collectionView.centerYAnchor],
    ]];
}

- (void)setupEmptyState
{
    UIImageSymbolConfiguration *config = [UIImageSymbolConfiguration configurationWithPointSize:50 weight:UIImageSymbolWeightLight];
    UIImage *emptyIcon = [UIImage systemImageNamed:@"square.grid.3x3.fill" withConfiguration:config];
    UIImageView *emptyImageView = [[UIImageView alloc] initWithImage:emptyIcon];
    emptyImageView.tintColor = [UIColor tertiaryLabelColor];
    emptyImageView.translatesAutoresizingMaskIntoConstraints = NO;
    
    UILabel *emptyLabel = [[UILabel alloc] init];
    emptyLabel.translatesAutoresizingMaskIntoConstraints = NO;
    emptyLabel.text = @"No Apps Installed";
    emptyLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightMedium];
    emptyLabel.textColor = [UIColor tertiaryLabelColor];
    emptyLabel.textAlignment = NSTextAlignmentCenter;
    
    _emptyStack = [[UIStackView alloc] initWithArrangedSubviews:@[emptyImageView, emptyLabel]];
    _emptyStack.axis = UILayoutConstraintAxisVertical;
    _emptyStack.alignment = UIStackViewAlignmentCenter;
    _emptyStack.spacing = 12;
    _emptyStack.translatesAutoresizingMaskIntoConstraints = NO;
    [self addSubview:_emptyStack];
}

- (NSArray<LDEAppEntry *> *)installedApps
{
    return [_apps copy];
}

- (void)registerAppWithBundleID:(NSString *)bundleID
                    displayName:(NSString *)name
                           icon:(UIImage *)icon
                        appPath:(NSString *)path
{
    if(!bundleID ||
       bundleID.length == 0)
    {
        return;
    }

    for(LDEAppEntry *entry in _apps)
    {
        if([entry.bundleID isEqualToString:bundleID])
        {
            entry.displayName = name ?: bundleID;
            entry.icon = icon ?: [UIImage imageNamed:@"DefaultIcon"];
            [self reloadApps];
            return;
        }
    }
    
    LDEAppEntry *entry = [[LDEAppEntry alloc] init];
    entry.bundleID = bundleID;
    entry.displayName = name ?: bundleID;
    entry.icon = icon ?: [UIImage imageNamed:@"DefaultIcon"];

    
    [_apps addObject:entry];
    [self reloadApps];
}

- (void)unregisterAppWithBundleID:(NSString *)bundleID
{
    if(!bundleID || bundleID.length == 0)
    {
        return;
    }
    
    NSUInteger index = [_apps indexOfObjectPassingTest:^BOOL(LDEAppEntry *entry, NSUInteger idx, BOOL *stop) {
        return [entry.bundleID isEqualToString:bundleID];
    }];
    
    if(index != NSNotFound)
    {
        [_apps removeObjectAtIndex:index];
        [self reloadApps];
    }
}

- (void)reloadApps
{
    [_apps sortUsingComparator:^NSComparisonResult(LDEAppEntry *a, LDEAppEntry *b){
        return [a.displayName localizedCaseInsensitiveCompare:b.displayName];
    }];
    
    NSString *searchText = _searchBar.text;
    if(searchText.length > 0)
    {
        NSPredicate *predicate = [NSPredicate predicateWithFormat:@"displayName CONTAINS[cd] %@ OR bundleID CONTAINS[cd] %@", searchText, searchText];
        _filteredApps = [_apps filteredArrayUsingPredicate:predicate];
    }
    else
    {
        _filteredApps = [_apps copy];
    }
    
    _emptyStack.hidden = (_filteredApps.count > 0);
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [self->_collectionView reloadData];
    });
}

- (NSInteger)numberOfSectionsInCollectionView:(UICollectionView *)collectionView
{
    return 1;
}

- (NSInteger)collectionView:(UICollectionView *)collectionView
     numberOfItemsInSection:(NSInteger)section
{
    return _filteredApps.count;
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView
                  cellForItemAtIndexPath:(NSIndexPath *)indexPath
{
    LDEAppCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:@"AppCell" forIndexPath:indexPath];
    
    if(indexPath.item < _filteredApps.count)
    {
        LDEAppEntry *app = _filteredApps[indexPath.item];
        cell.iconView.image = app.icon;
        cell.nameLabel.text = app.displayName;
    }
    
    return cell;
}

- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath
{
    [collectionView deselectItemAtIndexPath:indexPath animated:YES];
    
    if(indexPath.item >= _filteredApps.count)
    {
        return;
    }
    
    LDEAppEntry *app = _filteredApps[indexPath.item];
    
    LDEAppCell *cell = (LDEAppCell *)[collectionView cellForItemAtIndexPath:indexPath];
    
    [UIView animateWithDuration:0.1 animations:^{
        cell.iconView.transform = CGAffineTransformMakeScale(1.15, 1.15);
    } completion:^(BOOL finished) {
        [UIView animateWithDuration:0.1 animations:^{
            cell.iconView.transform = CGAffineTransformIdentity;
        } completion:^(BOOL finished) {
            if([self.delegate respondsToSelector:@selector(launchpadDidSelectAppWithBundleID:)])
            {
                [self.delegate launchpadDidSelectAppWithBundleID:app.bundleID];
            }
        }];
    }];
    
    UIImpactFeedbackGenerator *impact = [[UIImpactFeedbackGenerator alloc]
        initWithStyle:UIImpactFeedbackStyleMedium];
    [impact impactOccurred];
}

#pragma mark - UISearchBarDelegate

- (void)searchBar:(UISearchBar *)searchBar
    textDidChange:(NSString *)searchText
{
    if(searchText.length == 0)
    {
        _filteredApps = [_apps copy];
    }
    else
    {
        NSPredicate *predicate = [NSPredicate predicateWithFormat:@"displayName CONTAINS[cd] %@ OR bundleID CONTAINS[cd] %@", searchText, searchText];
        _filteredApps = [_apps filteredArrayUsingPredicate:predicate];
    }
    
    _emptyStack.hidden = (_filteredApps.count > 0);
    [_collectionView reloadData];
}

- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar
{
    [searchBar resignFirstResponder];
}

- (void)searchBarCancelButtonClicked:(UISearchBar *)searchBar
{
    searchBar.text = @"";
    [self searchBar:searchBar textDidChange:@""];
    [searchBar resignFirstResponder];
}

#pragma mark - Context Menu

- (UIAction*)createEntitlementActionWithTitle:(NSString*)title
                       withCurrentEntitlement:(PEEntitlement)entitlement
                        withTargetEntitlement:(PEEntitlement)targetEntitlement
                              withApplication:(LDEApplicationObject*)application
{
    __block PEEntitlement bEntitlement = entitlement;
    __block PEEntitlement bTargetEntitlement = targetEntitlement;
    return [UIAction actionWithTitle:title image:[UIImage systemImageNamed:entitlement_got_entitlement(entitlement, targetEntitlement) ? @"checkmark.circle.fill" : @"circle"] identifier:nil handler:^(UIAction *action){
        if(!entitlement_got_entitlement(entitlement, targetEntitlement))
        {
            bEntitlement |= bTargetEntitlement;
        }
        else
        {
            bEntitlement &= ~bTargetEntitlement;
        }
        NSString *entHash = [LDETrust entHashOfExecutableAtPath:application.executablePath];
        [[TrustCache shared] setEntitlementsForHash:entHash usingEntitlements:bEntitlement];
        [[LDEProcessManager shared] closeIfRunningUsingBundleIdentifier:application.bundleIdentifier];
    }];
}

- (UIContextMenuConfiguration *)collectionView:(UICollectionView *)collectionView
    contextMenuConfigurationForItemAtIndexPath:(NSIndexPath *)indexPath
                                         point:(CGPoint)point
{
    if(indexPath.item >= _filteredApps.count)
    {
        return nil;
    }
    
    LDEAppEntry *app = _filteredApps[indexPath.item];
    
    return [UIContextMenuConfiguration configurationWithIdentifier:nil
                                                   previewProvider:nil
                                                    actionProvider:^UIMenu *(NSArray<UIMenuElement *> *suggestedActions) {
        
        NSMutableArray<UIMenu *> *subMenus = [NSMutableArray array];
        NSMutableArray<UIMenu *> *entMenus = [NSMutableArray array];
        
        UIAction *openAction = [UIAction actionWithTitle:@"Open" image:[UIImage systemImageNamed:@"arrow.up.right.square.fill"] identifier:nil handler:^(UIAction *action) {
            [[LDEProcessManager shared] spawnProcessWithBundleIdentifier:app.bundleID withKernelSurfaceProcess:kernel_proc_ doRestartIfRunning:NO];
        }];
        [subMenus addObject:(UIMenu*)openAction];
        
        UIAction *clearContainer = [UIAction actionWithTitle:@"Clear Dara Container" image:[UIImage systemImageNamed:@"arrow.up.trash.fill"] identifier:nil handler:^(UIAction *action) {
            [[LDEApplicationWorkspace shared] clearContainerForBundleID:app.bundleID];
        }];
        [subMenus addObject:(UIMenu*)clearContainer];
        
        LDEApplicationObject *applicationObject = [[LDEApplicationWorkspace shared] applicationObjectForBundleID:app.bundleID];
        NSString *entHash = [LDETrust entHashOfExecutableAtPath:applicationObject.executablePath];
        PEEntitlement entitlement = [[TrustCache shared] getEntitlementsForHash:entHash];
        
        for(NSDictionary *category in entitlementsMenuStructure)
        {
            NSString *title = category[@"title"];
            NSString *iconName = category[@"icon"];
            NSArray *items = category[@"items"];
            
            NSMutableArray<UIAction *> *actions = [NSMutableArray array];
            
            for(NSDictionary *item in items)
            {
                NSString *name = item[@"name"];
                NSNumber *value = item[@"value"];
                [actions addObject:[self createEntitlementActionWithTitle:name withCurrentEntitlement:entitlement withTargetEntitlement:value.unsignedLongLongValue withApplication:applicationObject]];
            }
            
            UIImage *menuIcon = [UIImage systemImageNamed:iconName];
            UIMenu *submenu = [UIMenu menuWithTitle:title image:menuIcon identifier:nil options:0 children:actions];
            [entMenus addObject:submenu];
        }
        [subMenus addObject:[UIMenu menuWithTitle:@"Entitlements" image:[UIImage systemImageNamed:@"checkmark.seal.text.page.fill"] identifier:nil options:UIMenuOptionsSingleSelection children:entMenus]];
        
        UIAction *deleteAction = [UIAction actionWithTitle:@"Uninstall" image:[UIImage systemImageNamed:@"trash.fill"] identifier:nil handler:^(UIAction *action) {
            [[LDEApplicationWorkspace shared] deleteApplicationWithBundleID:app.bundleID];
        }];
        deleteAction.attributes = UIMenuElementAttributesDestructive;
        [subMenus addObject:(UIMenu*)deleteAction];
        
        return [UIMenu menuWithChildren:subMenus];
    }];
}

@end
