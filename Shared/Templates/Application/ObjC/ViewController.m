#import "ViewController.h"

@implementation ViewController

- (void)viewDidLoad {
	[super viewDidLoad];

	self.view.backgroundColor = [UIColor systemBackgroundColor];

	UIImageSymbolConfiguration *config = [UIImageSymbolConfiguration configurationWithScale:UIImageSymbolScaleLarge];
	UIImage *img = [[UIImage systemImageNamed:@"globe"] imageByApplyingSymbolConfiguration:config];
	UIImageView * globeView = [[UIImageView alloc] initWithImage:img];
	globeView.tintColor = [UIColor systemBlueColor];

	UILabel *label = [[UILabel alloc] init];
	label.text = @"Hello, world!";
	label.textAlignment = NSTextAlignmentCenter;
	label.textColor = [UIColor labelColor];

	UIStackView *stackView = [[UIStackView alloc] initWithArrangedSubviews:@[globeView, label]];
	stackView.axis = UILayoutConstraintAxisVertical;
	stackView.distribution = UIStackViewDistributionEqualCentering;
	stackView.alignment = UIStackViewAlignmentCenter;
	[self.view addSubview:stackView];
	stackView.translatesAutoresizingMaskIntoConstraints = NO;

	[NSLayoutConstraint activateConstraints:@[
		[stackView.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
		[stackView.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor]
	]];
}


@end
