#import "FoundationPrivate.h"
#import "LDEAppScene.h"

@interface LDEWindow : UIViewController<LDEAppSceneDelegate>

@property (nonatomic) NSString* windowName;
@property (nonatomic) LDEAppScene* appSceneVC;
@property (nonatomic) UIStackView *view;
@property (nonatomic) UINavigationBar *navigationBar;
@property (nonatomic) UINavigationItem *navigationItem;
@property (nonatomic) UIView *resizeHandle;
@property (nonatomic) UIView *contentView;
@property (nonatomic) UILabel *label;

@property (nonatomic) BOOL isMaximized;
@property (nonatomic) CGFloat scaleRatio;

- (instancetype)initWithProcess:(LDEProcess*)process
                 withDimensions:(CGRect)rect
              dismissalCallback:(void (^)(void))dismissalCallback;
- (void)updateVerticalConstraints;
- (void)closeWindow;

@end
