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

#import <UI/TableCells/NXProjectTableCell.h>
#import <LindChain/Project/NXProject.h>

@interface NXProjectTableCell ()

@property (nonatomic, strong) NSLayoutConstraint *textCenterConstraint;
@property (nonatomic, strong) NSLayoutConstraint *textCenterConstraintBox;
@property (nonatomic, strong) NSLayoutConstraint *detailBelowTitleConstraint;
@property (nonatomic, strong) NSArray<NSLayoutConstraint*> *imageConstraints;

@property (nonatomic, strong) NSLayoutConstraint *leadingConstraintWImage;
@property (nonatomic, strong) NSLayoutConstraint *leadingConstraintWHImage;
@property (nonatomic, strong) NSLayoutConstraint *detailLeadingConstraintWImage;
@property (nonatomic, strong) NSLayoutConstraint *detailLeadingConstraintWHImage;

@end

@implementation NXProjectTableCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style
              reuseIdentifier:(NSString *)reuseIdentifier
{
    self = [super initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:reuseIdentifier];
    if(self)
    {
        [self setupConstraints];
    }
    return self;
}

- (void)setupConstraints
{
    self.textLabel.numberOfLines = 1;
    self.detailTextLabel.numberOfLines = 1;
    self.textLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightBold];
    self.detailTextLabel.font = [UIFont systemFontOfSize:10];

    self.imageView.translatesAutoresizingMaskIntoConstraints = NO;
    self.textLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.detailTextLabel.translatesAutoresizingMaskIntoConstraints = NO;

    CGFloat imageSize = 50;

    self.imageConstraints = @[
        [self.imageView.widthAnchor constraintEqualToConstant:imageSize],
        [self.imageView.heightAnchor constraintEqualToConstant:imageSize],
        [self.imageView.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:16],
        [self.imageView.centerYAnchor constraintEqualToAnchor:self.contentView.centerYAnchor],
    ];

    self.leadingConstraintWImage = [self.textLabel.leadingAnchor constraintEqualToAnchor:self.imageView.trailingAnchor constant:16];
    self.leadingConstraintWHImage = [self.textLabel.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:16];
    self.detailLeadingConstraintWImage = [self.detailTextLabel.leadingAnchor constraintEqualToAnchor:self.imageView.trailingAnchor constant:16];
    self.detailLeadingConstraintWHImage = [self.detailTextLabel.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:16];

    self.textCenterConstraint = [self.textLabel.centerYAnchor constraintEqualToAnchor:self.contentView.centerYAnchor];
    self.textCenterConstraintBox = [self.textLabel.centerYAnchor constraintEqualToAnchor:self.contentView.centerYAnchor constant:-10];
    self.detailBelowTitleConstraint = [self.detailTextLabel.topAnchor constraintEqualToAnchor:self.textLabel.bottomAnchor constant:4];

    [NSLayoutConstraint activateConstraints:@[
        self.textCenterConstraint,
        self.detailBelowTitleConstraint,

        [self.textLabel.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-16],
        [self.detailTextLabel.trailingAnchor constraintEqualToAnchor:self.textLabel.trailingAnchor]
    ]];

    [NSLayoutConstraint activateConstraints:self.imageConstraints];
    self.leadingConstraintWImage.active = YES;
    self.detailLeadingConstraintWImage.active = YES;

    if(@available(iOS 26.0, *))
    {
        self.imageView.layer.cornerRadius = 15;
    }
    else
    {
        self.imageView.layer.cornerRadius = 10;
    }

    self.imageView.clipsToBounds = YES;
    self.imageView.layer.borderWidth = 0.5;
    self.imageView.layer.borderColor = UIColor.grayColor.CGColor;

    self.separatorInset = UIEdgeInsetsZero;
    self.layoutMargins = UIEdgeInsetsZero;
    self.preservesSuperviewLayoutMargins = NO;
}

- (void)configureWithDisplayName:(NSString*)displayName
            withBundleIdentifier:(NSString*)bundleIdentifier
                     withAppIcon:(UIImage*)image
                     showAppIcon:(BOOL)showAppIcon
                    showBundleID:(BOOL)showBundleID
                       showArrow:(BOOL)showArrow
{
    self.textLabel.text = displayName;
    self.imageView.image = image ?: [UIImage imageNamed:@"DefaultIcon"];
    self.accessoryType = showArrow ? UITableViewCellAccessoryDisclosureIndicator : UITableViewCellAccessoryNone;

    if(showBundleID)
    {
        self.detailTextLabel.text = bundleIdentifier;
        self.detailTextLabel.hidden = NO;
        self.detailBelowTitleConstraint.active = YES;
        self.textCenterConstraint.active = false;
        self.textCenterConstraintBox.active = true;
    }
    else
    {
        self.detailTextLabel.text = @"";
        self.detailTextLabel.hidden = YES;
        self.detailBelowTitleConstraint.active = NO;
        self.textCenterConstraint.active = true;
        self.textCenterConstraintBox.active = false;
    }

    if(showAppIcon)
    {
        self.imageView.hidden = NO;
        [NSLayoutConstraint activateConstraints:self.imageConstraints];
        self.leadingConstraintWHImage.active = NO;
        self.leadingConstraintWImage.active = YES;
        self.detailLeadingConstraintWHImage.active = NO;
        self.detailLeadingConstraintWImage.active = YES;
    }
    else
    {
        self.imageView.hidden = YES;
        self.leadingConstraintWImage.active = NO;
        self.leadingConstraintWHImage.active = YES;
        self.detailLeadingConstraintWImage.active = NO;
        self.detailLeadingConstraintWHImage.active = YES;
    }
}

- (void)prepareForReuse
{
    [super prepareForReuse];
    self.textLabel.text = nil;
    self.detailTextLabel.text = nil;
    self.imageView.image = nil;
    self.accessoryType = UITableViewCellAccessoryNone;
    self.imageView.hidden = NO;
    self.detailTextLabel.hidden = NO;
}

+ (NSString *)reuseIdentifier
{
    return @"NXProjectTableCell";
}

@end
