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

#import <UI/NXRecoveryViewController.h>
#import <UI/NXVolumeButtonMonitor.h>

static NSString * const NXRecoveryAtlasResource = @"recovery_font_18x32";

const CGFloat NXRecoveryFontSize = 13.0;
static const NSInteger NXRecoveryGlyphScale = 1;

static const CGFloat NXRecoveryMargin = 0.0;
static const CGFloat NXRecoveryMenuFooterGap = 8.0;

static void NXRecoveryReleaseData(void *info, const void *data, size_t size)
{
    free((void *)data);
}

@implementation NXRecoveryItem

- (instancetype)initWithTitle:(NSString *)title
                       action:(NXRecoveryAction)action
{
    self = [super init];
    if(self)
    {
        _title = [title copy];
        _action = [action copy];
    }
    return self;
}

+ (instancetype)itemWithTitle:(NSString *)title
{
    return [[self alloc] initWithTitle:title action:nil];
}

+ (instancetype)itemWithTitle:(NSString *)title
                       action:(NXRecoveryAction)action
{
    return [[self alloc] initWithTitle:title action:action];
}

@end

@interface NXRecoveryFontAtlas : NSObject

@property (nonatomic, readonly) NSInteger cellWidth;
@property (nonatomic, readonly) NSInteger cellHeight;

+ (nullable instancetype)sharedAtlas;
- (nullable CGImageRef)imageTintedWithColor:(UIColor *)color;

@end

@implementation NXRecoveryFontAtlas
{
    NSInteger _width;
    NSInteger _height;
    uint8_t *_coverage;
    NSMutableDictionary<UIColor*, id> *_tinted;
}

+ (instancetype)sharedAtlas
{
    static NXRecoveryFontAtlas *atlas;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        atlas = [[self alloc] initWithResource:NXRecoveryAtlasResource];
    });
    return atlas;
}

- (instancetype)initWithResource:(NSString *)name
{
    self = [super init];
    if(self == nil)
    {
        return nil;
    }
    
    NSBundle *bundle = [NSBundle bundleForClass:self.class];
    NSString *path = [bundle pathForResource:name ofType:@"png"];
    CGImageRef cg = (path != nil) ? [UIImage imageWithContentsOfFile:path].CGImage : NULL;
    if(cg == NULL)
    {
        return nil;
    }
    
    _width = (NSInteger)CGImageGetWidth(cg);
    _height = (NSInteger)CGImageGetHeight(cg);
    if(_width < 96 || (_width % 96) != 0 || (_height % 2) != 0)
    {
        return nil;
    }
    
    _coverage = calloc((size_t)(_width * _height), 1);
    if(_coverage == NULL)
    {
        return nil;
    }
    
    CGColorSpaceRef gray = CGColorSpaceCreateDeviceGray();
    CGContextRef ctx = CGBitmapContextCreate(_coverage, (size_t)_width, (size_t)_height, 8, (size_t)_width, gray, (CGBitmapInfo)kCGImageAlphaNone);
    CGColorSpaceRelease(gray);
    if(ctx == NULL)
    {
        free(_coverage);
        _coverage = NULL;
        return nil;
    }
    
    CGContextDrawImage(ctx, CGRectMake(0, 0, _width, _height), cg);
    CGContextRelease(ctx);
    
    _tinted = [NSMutableDictionary dictionary];
    return self;
}

- (void)dealloc
{
    free(_coverage);
}

- (NSInteger)cellWidth
{
    return _width / 96;
}

- (NSInteger)cellHeight
{
    return _height / 2;
}

- (CGImageRef)imageTintedWithColor:(UIColor *)color
{
    if(color == nil)
    {
        return NULL;
    }
    
    id cached = _tinted[color];
    if(cached != nil)
    {
        return (__bridge CGImageRef)cached;
    }
    
    CGFloat r = 0.0, g = 0.0, b = 0.0, a = 1.0;
    if(![color getRed:&r green:&g blue:&b alpha:&a])
    {
        return NULL;
    }
    
    size_t count = (size_t)(_width * _height);
    uint8_t *rgba = malloc(count * 4);
    if(rgba == NULL)
    {
        return NULL;
    }
    
    for(size_t i = 0; i < count; i++)
    {
        uint8_t cov = _coverage[i];
        rgba[i * 4 + 0] = (uint8_t)lround(r * cov);
        rgba[i * 4 + 1] = (uint8_t)lround(g * cov);
        rgba[i * 4 + 2] = (uint8_t)lround(b * cov);
        rgba[i * 4 + 3] = cov;
    }
    
    CGDataProviderRef provider = CGDataProviderCreateWithData(NULL, rgba, count * 4, NXRecoveryReleaseData);
    CGColorSpaceRef rgb = CGColorSpaceCreateDeviceRGB();
    CGBitmapInfo bitmapInfo = (CGBitmapInfo)kCGImageAlphaPremultipliedLast | kCGBitmapByteOrderDefault;
    CGImageRef image = CGImageCreate((size_t)_width, (size_t)_height, 8, 32, (size_t)(_width * 4), rgb, bitmapInfo, provider, NULL, false, kCGRenderingIntentDefault);
    CGColorSpaceRelease(rgb);
    CGDataProviderRelease(provider);
    
    if(image == NULL)
    {
        return NULL;
    }
    
    _tinted[color] = (__bridge_transfer id)image;
    return image;
}

@end

@interface NXRecoveryGlyphView : UIView

@property (nonatomic, copy) NSString *text;
@property (nonatomic) BOOL bold;
@property (nonatomic, strong) UIColor *color;
@property (nonatomic) NSInteger glyphScale;
@property (nonatomic) BOOL wraps;

- (CGSize)cellSizeInPoints;

@end

@implementation NXRecoveryGlyphView
{
    NSData *_bytes;
    NSArray<NSValue *> *_lines;
    CGFloat _lastWidth;
}

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if(self)
    {
        self.opaque = NO;
        self.backgroundColor = [UIColor clearColor];
        self.contentMode = UIViewContentModeRedraw;
        _glyphScale = NXRecoveryGlyphScale;
        _lastWidth = -1.0;
        [self setContentHuggingPriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisVertical];
    }
    return self;
}

- (void)invalidateGlyphs
{
    _lines = nil;
    [self invalidateIntrinsicContentSize];
    [self setNeedsDisplay];
}

- (void)setText:(NSString *)text
{
    if(_text == text || [_text isEqualToString:text])
    {
        return;
    }
    _text = [text copy];
    _bytes = [(_text ?: @"") dataUsingEncoding:NSUTF8StringEncoding];
    [self invalidateGlyphs];
}

- (void)setBold:(BOOL)bold
{
    if(_bold != bold)
    {
        _bold = bold;
        [self setNeedsDisplay];
    }
}

- (void)setColor:(UIColor *)color
{
    _color = color;
    [self setNeedsDisplay];
}

- (void)setGlyphScale:(NSInteger)glyphScale
{
    _glyphScale = MAX((NSInteger)1, glyphScale);
    [self invalidateGlyphs];
}

- (void)setWraps:(BOOL)wraps
{
    if(_wraps != wraps)
    {
        _wraps = wraps;
        [self invalidateGlyphs];
    }
}

- (CGFloat)displayScaleValue
{
    CGFloat scale = self.traitCollection.displayScale;
    if(scale <= 0.0)
    {
        scale = UIScreen.mainScreen.scale;
    }
    return (scale > 0.0) ? scale : 1.0;
}

- (CGSize)cellSizeInPoints
{
    NXRecoveryFontAtlas *atlas = [NXRecoveryFontAtlas sharedAtlas];
    if(atlas == nil)
    {
        return CGSizeZero;
    }
    
    CGFloat k = (CGFloat)self.glyphScale / [self displayScaleValue];
    return CGSizeMake(atlas.cellWidth * k, atlas.cellHeight * k);
}

- (NSArray<NSValue *> *)glyphLines
{
    if(_lines != nil)
    {
        return _lines;
    }
    
    NSMutableArray<NSValue *> *lines = [NSMutableArray array];
    const uint8_t *b = _bytes.bytes;
    NSUInteger len = _bytes.length;
    
    CGFloat cellWidth = [self cellSizeInPoints].width;
    NSUInteger columns = NSUIntegerMax;
    if(self.wraps && cellWidth > 0.0 && CGRectGetWidth(self.bounds) > 0.0)
    {
        NSInteger fit = (NSInteger)floor(CGRectGetWidth(self.bounds) / cellWidth);
        columns = (NSUInteger)MAX((NSInteger)1, fit);
    }
    
    NSUInteger start = 0;
    for(NSUInteger i = 0; i <= len; i++)
    {
        BOOL hardBreak = (i < len && b[i] == '\n');
        BOOL full = (i > start) && ((i - start) == columns);
        if(i == len || hardBreak || full)
        {
            [lines addObject:[NSValue valueWithRange:NSMakeRange(start, i - start)]];
            start = hardBreak ? (i + 1) : i;
            if(i == len)
            {
                break;
            }
        }
    }
    
    if(lines.count == 0)
    {
        [lines addObject:[NSValue valueWithRange:NSMakeRange(0, 0)]];
    }
    
    _lines = [lines copy];
    return _lines;
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    
    if(self.wraps && fabs(CGRectGetWidth(self.bounds) - _lastWidth) > 0.5)
    {
        _lastWidth = CGRectGetWidth(self.bounds);
        [self invalidateGlyphs];
    }
}

- (CGSize)intrinsicContentSize
{
    CGSize cell = [self cellSizeInPoints];
    NSArray<NSValue *> *lines = [self glyphLines];
    
    CGFloat width = UIViewNoIntrinsicMetric;
    if(!self.wraps)
    {
        NSUInteger longest = 0;
        for(NSValue *v in lines)
        {
            longest = MAX(longest, v.rangeValue.length);
        }
        width = cell.width * (CGFloat)longest;
    }
    
    return CGSizeMake(width, cell.height * (CGFloat)MAX((NSUInteger)1, lines.count));
}

- (void)traitCollectionDidChange:(UITraitCollection *)previous
{
    [super traitCollectionDidChange:previous];
    
    if(previous.displayScale != self.traitCollection.displayScale)
    {
        [self invalidateGlyphs];
    }
}

- (void)drawRect:(CGRect)rect
{
    UIColor *ink = self.color ?: UIColor.whiteColor;
    NXRecoveryFontAtlas *atlas = [NXRecoveryFontAtlas sharedAtlas];
    NSArray<NSValue *> *lines = [self glyphLines];
    CGSize cell = [self cellSizeInPoints];
    if(atlas == nil)
    {
        return;
    }
    
    CGImageRef tinted = [atlas imageTintedWithColor:ink];
    if(tinted == NULL)
    {
        return;
    }
    
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    CGContextSetShouldAntialias(ctx, NO);
    CGContextSetInterpolationQuality(ctx, kCGInterpolationNone);
    
    const uint8_t *b = _bytes.bytes;
    CGFloat limit = CGRectGetWidth(self.bounds);
    for(NSUInteger li = 0; li < lines.count; li++)
    {
        NSRange line = lines[li].rangeValue;
        CGFloat y = cell.height * (CGFloat)li;
        CGFloat x = 0.0;
        for(NSUInteger i = 0; i < line.length && x < limit; i++)
        {
            NSInteger off = (NSInteger)b[line.location + i] - 32;
            if(off >= 0 && off < 96)
            {
                CGRect src = CGRectMake(off * atlas.cellWidth, self.bold ? atlas.cellHeight : 0, atlas.cellWidth, atlas.cellHeight);
                CGImageRef glyph = CGImageCreateWithImageInRect(tinted, src);
                if(glyph != NULL)
                {
                    [[UIImage imageWithCGImage:glyph] drawInRect:CGRectMake(x, y, cell.width, cell.height)];
                    CGImageRelease(glyph);
                }
            }
            x += cell.width;
        }
    }
}

@end

@interface NXRecoveryRow : NSObject

@property (nonatomic, strong) UIView *bar;
@property (nonatomic, strong) NXRecoveryGlyphView *glyph;

@end

@implementation NXRecoveryRow
@end

@interface NXRecoveryLogLine : NSObject

@property (nonatomic, copy) NSString *text;
@property (nonatomic) NXRecoveryLogLevel level;

+ (instancetype)lineWithText:(NSString *)text level:(NXRecoveryLogLevel)level;

@end

@implementation NXRecoveryLogLine

+ (instancetype)lineWithText:(NSString *)text
                       level:(NXRecoveryLogLevel)level
{
    NXRecoveryLogLine *line = [self new];
    line.text = text;
    line.level = level;
    return line;
}

@end

@interface NXRecoveryEntry : NSObject

@property (nonatomic, copy) NSString *name;
@property (nonatomic, copy) NSString *path;
@property (nonatomic, copy, nullable) NSString *linkDestination;
@property (nonatomic) BOOL isSymlink;
@property (nonatomic) BOOL isDirectory;
@property (nonatomic) BOOL isBroken;
@property (nonatomic, readonly) NSString *displayTitle;

@end

@implementation NXRecoveryEntry

- (NSString *)displayTitle
{
    NSString *base = self.isDirectory ? [self.name stringByAppendingString:@"/"] : self.name;
    if(!self.isSymlink)
    {
        return base;
    }
    
    NSString *dest = self.linkDestination ?: @"?";
    
    return self.isBroken ? [NSString stringWithFormat:@"%@ -> %@ (broken)", self.name, dest] : [NSString stringWithFormat:@"%@ -> %@", base, dest];
}

@end

@interface NXRecoveryViewController ()

@property (nonatomic, strong) NXRecoveryGlyphView *headerView;
@property (nonatomic, strong) NXRecoveryGlyphView *instructionsView;
@property (nonatomic, strong) UIStackView *menuStack;
@property (nonatomic, strong) UIStackView *footerStack;

@property (nonatomic, strong) NSMutableArray<NXRecoveryRow*> *rows;
@property (nonatomic, strong) NSMutableArray<UIView*> *decor;
@property (nonatomic, strong) NSMutableArray<NXRecoveryItem*> *mutableItems;

@property (nonatomic) NSInteger menuOffset;
@property (nonatomic) NSInteger visibleWindow;
@property (nonatomic) NSInteger menuWindow;

@property (nonatomic, strong) NSMutableArray<NXRecoveryLogLine*> *logLines;
@property (nonatomic, strong) NSMutableArray<NXRecoveryGlyphView*> *logRows;
@property (nonatomic, strong) UIFont *logFont;

@property (nonatomic, readwrite, getter=isRecoveryActive) BOOL recoveryActive;
@property (nonatomic, copy, nullable) NXRecoveryIndexHandler onSelect;
@property (nonatomic, copy, nullable) NXRecoveryIndexHandler onMove;

@property (nonatomic, copy, nullable) NSString *browserRoot;
@property (nonatomic, copy, nullable) NSString *browserHeader;
@property (nonatomic, copy, nullable) NSString *browserPath;
@property (nonatomic, copy, nullable) NXRecoveryAction browserOnBack;
@property (nonatomic, copy, nullable) NXRecoveryFileHandler browserOnFile;

@property (nonatomic, readwrite, getter=isConsoleActive) BOOL consoleActive;
@property (nonatomic, copy, nullable) NXRecoveryAction consoleSelectAction;
@property (nonatomic) NSInteger savedLogMax;
@property (nonatomic, strong) NSLayoutConstraint *menuFooterConstraint;
@property (nonatomic, strong) NSLayoutConstraint *consoleTopConstraint;

@end

@implementation NXRecoveryViewController

+ (UIColor *)rgbR:(CGFloat)r
                g:(CGFloat)g
                b:(CGFloat)b
{
    return [UIColor colorWithRed:r green:g blue:b alpha:1.0];
}

+ (UIColor *)recoveryBackgroundColor
{
    return [self rgbR:0.0 g:0.0 b:0.0];
}

+ (UIColor *)recoveryHeaderColor
{
    /* HEADER */
    return [self rgbR:247/255.0 g:0.0 b:6/255.0];
}

+ (UIColor *)recoveryInfoColor
{
    /* INFO */
    return [self rgbR:249/255.0 g:194/255.0 b:0.0];
}

+ (UIColor *)recoveryItemColor
{
    /* MENU */
    return [self rgbR:0.0 g:106/255.0 b:157/255.0];
}

+ (UIColor *)recoveryHighlightColor
{
    /* MENU_SEL_BG */
    return [self rgbR:0.0 g:106/255.0 b:157/255.0];
}

+ (UIColor *)recoveryHighlightTextColor
{
    /* MENU_SEL_FG */
    return [self rgbR:1.0 g:1.0 b:1.0];
}

+ (UIColor *)recoveryFooterColor
{
    return [self rgbR:0.5 g:0.5 b:0.5];
}

+ (UIColor *)recoveryLogInfoColor
{
    /* LOG */
    return [self rgbR:196/255.0 g:196/255.0 b:196/255.0];
}

+ (UIColor *)recoveryLogErrorColor
{
    /* Nyxian addition since AOSP's text log has no severity =3 */
    return [self rgbR:1.0 g:0.27 b:0.27];
}

- (instancetype)initWithNibName:(NSString *)nib
                         bundle:(NSBundle *)bundle
{
    self = [super initWithNibName:nib bundle:bundle];
    if(self)
    {
        _rows = [NSMutableArray array];
        _decor = [NSMutableArray array];
        _mutableItems = [NSMutableArray array];
        _logLines = [NSMutableArray array];
        _logRows = [NSMutableArray array];
        _recoveryIndex = 0;
        _recoveryLogMax = 30;
        _recoveryActive = NO;
        _menuOffset = 0;
        _visibleWindow = 0;
        _menuWindow = 0;
    }
    return self;
}

- (void)createRecoveryView
{
    [self loadViewIfNeeded];
}

- (NXRecoveryGlyphView *)makeGlyphViewWrapping:(BOOL)wraps
                                         color:(UIColor *)color
                                          bold:(BOOL)bold
{
    NXRecoveryGlyphView *v = [NXRecoveryGlyphView new];
    v.translatesAutoresizingMaskIntoConstraints = NO;
    v.glyphScale = NXRecoveryGlyphScale;
    v.wraps = wraps;
    v.color = color;
    v.bold = bold;
    return v;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.view.backgroundColor = [self.class recoveryBackgroundColor];
    self.view.hidden = YES;
    
    NXRecoveryGlyphView *header = [self makeGlyphViewWrapping:YES color:[self.class recoveryInfoColor] bold:YES];
    header.text = @"Nyxian Recovery";
    [self.view addSubview:header];
    self.headerView = header;
    
    NXRecoveryGlyphView *instructions = [self makeGlyphViewWrapping:YES color:[self.class recoveryInfoColor] bold:NO];
    instructions.text = @"Use volume up/down and hold both volume keys.";
    [self.view addSubview:instructions];
    self.instructionsView = instructions;
    
    UIStackView *stack = [UIStackView new];
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    stack.axis = UILayoutConstraintAxisVertical;
    stack.alignment = UIStackViewAlignmentFill;
    stack.distribution = UIStackViewDistributionFill;
    stack.spacing = 0;
    [self.view addSubview:stack];
    self.menuStack = stack;
    
    UIStackView *footer = [UIStackView new];
    footer.translatesAutoresizingMaskIntoConstraints = NO;
    footer.axis = UILayoutConstraintAxisVertical;
    footer.alignment = UIStackViewAlignmentFill;
    footer.distribution = UIStackViewDistributionFill;
    footer.spacing = 0;
    [self.view addSubview:footer];
    self.footerStack = footer;
    
    UILayoutGuide *guide = self.view.safeAreaLayoutGuide;
    
    self.menuFooterConstraint = [stack.bottomAnchor constraintLessThanOrEqualToAnchor:footer.topAnchor constant:-NXRecoveryMenuFooterGap];
    self.consoleTopConstraint = [footer.topAnchor constraintGreaterThanOrEqualToAnchor:guide.topAnchor constant:12];
    footer.clipsToBounds = YES;
    
    [NSLayoutConstraint activateConstraints:@[
        [header.topAnchor constraintEqualToAnchor:guide.topAnchor constant:12],
        [header.leadingAnchor constraintEqualToAnchor:guide.leadingAnchor constant:NXRecoveryMargin],
        [header.trailingAnchor constraintEqualToAnchor:guide.trailingAnchor],
        
        [instructions.topAnchor constraintEqualToAnchor:header.bottomAnchor constant:0],
        [instructions.leadingAnchor constraintEqualToAnchor:guide.leadingAnchor constant:NXRecoveryMargin],
        [instructions.trailingAnchor constraintEqualToAnchor:guide.trailingAnchor],
        
        [stack.topAnchor constraintEqualToAnchor:instructions.bottomAnchor constant:4],
        [stack.leadingAnchor constraintEqualToAnchor:guide.leadingAnchor constant:NXRecoveryMargin],
        [stack.trailingAnchor constraintEqualToAnchor:guide.trailingAnchor constant:0],
        self.menuFooterConstraint,
        
        [footer.bottomAnchor constraintEqualToAnchor:guide.bottomAnchor constant:-12],
        [footer.leadingAnchor constraintEqualToAnchor:guide.leadingAnchor constant:NXRecoveryMargin],
        [footer.trailingAnchor constraintEqualToAnchor:guide.trailingAnchor],
    ]];
}

- (void)viewDidLayoutSubviews
{
    [super viewDidLayoutSubviews];
    
    if(self.consoleActive)
    {
        if([self trimRecoveryLog])
        {
            [self paintRecoveryLog];
        }
        return;
    }
    if(self.mutableItems.count == 0)
    {
        return;
    }
    if([self effectiveMenuWindow] != self.visibleWindow)
    {
        [self rebuildMenuRows];
    }
}

- (void)traitCollectionDidChange:(UITraitCollection *)previous
{
    [super traitCollectionDidChange:previous];
    
    if(previous.displayScale != self.traitCollection.displayScale)
    {
        [self rebuildMenuRows];
        [self paintRecoveryLog];
    }
}

- (void)attachToViewController:(UIViewController *)parent
{
    if(parent == nil)
    {
        return;
    }
    
    [parent addChildViewController:self];
    
    self.view.translatesAutoresizingMaskIntoConstraints = NO;
    [parent.view addSubview:self.view];
    
    [NSLayoutConstraint activateConstraints:@[
        [self.view.topAnchor constraintEqualToAnchor:parent.view.topAnchor],
        [self.view.bottomAnchor constraintEqualToAnchor:parent.view.bottomAnchor],
        [self.view.leadingAnchor constraintEqualToAnchor:parent.view.leadingAnchor],
        [self.view.trailingAnchor constraintEqualToAnchor:parent.view.trailingAnchor],
    ]];
    
    [self didMoveToParentViewController:parent];
}

- (BOOL)prefersStatusBarHidden
{
    return YES;
}

- (void)setRecoveryHeader:(NSString *)text
{
    [self createRecoveryView];
    self.headerView.text = text ?: @"";
}

- (void)setRecoveryInstructions:(NSString *)text
{
    [self createRecoveryView];
    self.instructionsView.text = text ?: @"";
}

- (void)setRecoveryFooter:(NSString *)text
{
    [self createRecoveryView];
    [self.logLines removeAllObjects];
    if(text.length > 0)
    {
        [self.logLines addObject:[NXRecoveryLogLine lineWithText:text level:NXRecoveryLogLevelInfo]];
    }
    [self paintRecoveryLog];
}

- (CGFloat)px:(CGFloat)pixels
{
    CGFloat scale = self.traitCollection.displayScale;
    if(scale <= 0.0)
    {
        scale = UIScreen.mainScreen.scale;
    }
    return (scale > 0.0) ? (pixels / scale) : pixels;
}

- (CGFloat)menuCellHeight
{
    NXRecoveryGlyphView *probe = [self makeGlyphViewWrapping:NO color:[self.class recoveryItemColor] bold:NO];
    return [probe cellSizeInPoints].height;
}

- (CGFloat)menuRowHeight
{
    return [self menuCellHeight] + 2.0 * [self px:2.0];
}

- (CGFloat)menuRuleGap
{
    return [self px:6.0];
}

- (UIView *)makeRecoveryLine
{
    UIView *v = [UIView new];
    v.translatesAutoresizingMaskIntoConstraints = NO;
    v.backgroundColor = [self.class recoveryItemColor];
    [v.heightAnchor constraintEqualToConstant:[self px:2.0]].active = YES;
    return v;
}

- (NSArray<NXRecoveryItem *> *)recoveryItems
{
    return [self.mutableItems copy];
}

- (void)setRecoveryItems:(NSArray<NXRecoveryItem *> *)items
{
    [self createRecoveryView];
    
    [self.mutableItems setArray:(items ?: @[])];
    
    _recoveryIndex = 0;
    _menuOffset = 0;
    
    [self rebuildMenuRows];
}

- (NSInteger)autoMenuWindow
{
    CGFloat rowHeight = [self menuRowHeight];
    if(rowHeight <= 0.0)
    {
        return 1;
    }
    
    CGFloat top = CGRectGetMinY(self.menuStack.frame);
    CGFloat bottom = CGRectGetMinY(self.footerStack.frame) - NXRecoveryMenuFooterGap;
    
    if(bottom <= top)
    {
        top = 0.0;
        bottom = CGRectGetHeight(self.view.bounds);
        if(bottom <= 0.0)
        {
            return 1;
        }
    }
    
    CGFloat chrome = 2.0 * [self px:2.0] + 2.0 * [self menuRuleGap];
    CGFloat available = (bottom - top) - chrome;
    if(available < rowHeight)
    {
        return 1;
    }
    return MAX(1, (NSInteger)floor(available / rowHeight));
}

- (NSInteger)effectiveMenuWindow
{
    NSInteger count = (NSInteger)self.mutableItems.count;
    if(count == 0)
    {
        return 0;
    }
    
    NSInteger window = (self.menuWindow > 0) ? self.menuWindow : [self autoMenuWindow];
    return MIN(MAX(window, 1), count);
}

- (void)setMenuWindow:(NSInteger)menuWindow
{
    _menuWindow = MAX(0, menuWindow);
    [self rebuildMenuRows];
}

- (void)clampMenuOffset
{
    NSInteger count = (NSInteger)self.mutableItems.count;
    NSInteger window = self.visibleWindow;
    if(count == 0 || window <= 0 || window >= count)
    {
        _menuOffset = 0;
        return;
    }
    
    NSInteger offset = _menuOffset;
    if(_recoveryIndex < offset)
    {
        offset = _recoveryIndex;
    }
    else if(_recoveryIndex >= offset + window)
    {
        offset = _recoveryIndex - window + 1;
    }
    
    _menuOffset = MIN(MAX(offset, 0), count - window);
}

- (void)styleRow:(NXRecoveryRow *)row
     highlighted:(BOOL)highlighted
{
    row.bar.backgroundColor = highlighted ? [self.class recoveryHighlightColor] : [UIColor clearColor];
    row.glyph.color = highlighted ? [self.class recoveryHighlightTextColor] : [self.class recoveryItemColor];
    row.glyph.bold = highlighted;
}

- (void)applyMenuWindow
{
    [self clampMenuOffset];
    
    NSInteger count = (NSInteger)self.mutableItems.count;
    for(NSInteger slot = 0; slot < (NSInteger)self.rows.count; slot++)
    {
        NSInteger index = self.menuOffset + slot;
        NXRecoveryRow *row = self.rows[slot];
        
        if(index < 0 || index >= count)
        {
            row.glyph.text = @"";
            [self styleRow:row highlighted:NO];
            continue;
        }
        
        row.glyph.text = self.mutableItems[index].title;
        [self styleRow:row highlighted:(index == _recoveryIndex)];
    }
}

- (void)rebuildMenuRows
{
    [self createRecoveryView];
    
    for(NXRecoveryRow *row in self.rows)
    {
        [row.bar removeFromSuperview];
    }
    [self.rows removeAllObjects];
    
    for(UIView *d in self.decor)
    {
        [d removeFromSuperview];
    }
    [self.decor removeAllObjects];
    
    NSInteger window = [self effectiveMenuWindow];
    self.visibleWindow = window;
    if(window == 0)
    {
        return;
    }
    
    CGFloat rowHeight = [self menuRowHeight];
    CGFloat cellHeight = [self menuCellHeight];
    
    UIView *topLine = [self makeRecoveryLine];
    [self.menuStack addArrangedSubview:topLine];
    [self.decor addObject:topLine];
    [self.menuStack setCustomSpacing:[self menuRuleGap] afterView:topLine];
    
    for(NSInteger slot = 0; slot < window; slot++)
    {
        UIView *bar = [UIView new];
        bar.translatesAutoresizingMaskIntoConstraints = NO;
        bar.backgroundColor = [UIColor clearColor];
        
        NXRecoveryGlyphView *glyph = [self makeGlyphViewWrapping:NO color:[self.class recoveryItemColor] bold:NO];
        [bar addSubview:glyph];
        [NSLayoutConstraint activateConstraints:@[
            [bar.heightAnchor constraintEqualToConstant:rowHeight],
            [glyph.centerYAnchor constraintEqualToAnchor:bar.centerYAnchor],
            [glyph.heightAnchor constraintEqualToConstant:cellHeight],
            [glyph.leadingAnchor constraintEqualToAnchor:bar.leadingAnchor constant:[self px:4.0]],
            [glyph.trailingAnchor constraintEqualToAnchor:bar.trailingAnchor],
        ]];
        
        [self.menuStack addArrangedSubview:bar];
        
        NXRecoveryRow *row = [NXRecoveryRow new];
        row.bar = bar;
        row.glyph = glyph;
        [self.rows addObject:row];
    }
    
    UIView *bottomLine = [self makeRecoveryLine];
    [self.menuStack addArrangedSubview:bottomLine];
    [self.decor addObject:bottomLine];
    [self.menuStack setCustomSpacing:[self menuRuleGap] afterView:self.rows.lastObject.bar];
    
    [self applyMenuWindow];
}

- (void)setRecoveryIndex:(NSInteger)index
{
    NSInteger count = (NSInteger)self.mutableItems.count;
    if(count == 0)
    {
        _recoveryIndex = 0;
        _menuOffset = 0;
        return;
    }
    
    index = ((index % count) + count) % count;
    if(index == _recoveryIndex)
    {
        return;
    }
    
    _recoveryIndex = index;
    [self applyMenuWindow];
}

- (NXRecoveryItem *)currentRecoveryItem
{
    if(_recoveryIndex < 0 || _recoveryIndex >= (NSInteger)self.mutableItems.count)
    {
        return nil;
    }
    return self.mutableItems[_recoveryIndex];
}

- (void)showRecovery:(BOOL)visible
{
    [self createRecoveryView];
    [self.view.superview bringSubviewToFront:self.view];
    self.view.hidden = !visible;
}

- (void)enterRecoveryWithHeader:(NSString *)header
                   instructions:(NSString *)instructions
                         footer:(NSString *)footer
                          items:(NSArray<NXRecoveryItem *> *)items
                       onSelect:(NXRecoveryIndexHandler)onSelect
                         onMove:(NXRecoveryIndexHandler)onMove
{
    [self createRecoveryView];
    
    if(header != nil)
    {
        [self setRecoveryHeader:header];
    }
    [self setRecoveryItems:(items ?: @[])];
    if(footer != nil)
    {
        [self setRecoveryFooter:footer];
    }
    if(instructions != nil)
    {
        [self setRecoveryInstructions:instructions];
    }
    
    self.onSelect = onSelect;
    self.onMove = onMove;
    
    self.recoveryActive = YES;
    [self showRecovery:YES];
    
    [self armVolumeInput];
}

- (void)exitRecovery
{
    self.recoveryActive = NO;
    [self disarmVolumeInput];
    [self showRecovery:NO];
}

- (void)armVolumeInput
{
    __weak typeof(self) weakSelf = self;
    [NXVolumeButtonMonitor armWithHandler:^(NSInteger button, NSString *kind) {
        [weakSelf handleButton:button kindString:kind];
    }];
}

- (void)disarmVolumeInput
{
    [NXVolumeButtonMonitor disarm];
}

- (void)handleButton:(NSInteger)button
          kindString:(NSString*)kind
{
    NXRecoveryEventKind k = [kind isEqualToString:@"select"] ? NXRecoveryEventKindSelect : NXRecoveryEventKindTap;
    [self handleButton:(NXRecoveryButton)button kind:k];
}

- (void)handleButton:(NXRecoveryButton)button
                kind:(NXRecoveryEventKind)kind
{
    if(!self.recoveryActive)
    {
        return;
    }
    if(self.consoleActive)
    {
        if(kind == NXRecoveryEventKindSelect && self.consoleSelectAction != nil)
        {
            NXRecoveryAction action = self.consoleSelectAction;
            self.consoleSelectAction = nil;
            action(self);
        }
        return;
    }
    if(kind == NXRecoveryEventKindSelect)
    {
        [self performRecoverySelect];
    }
    else
    {
        [self moveRecoveryBy:(button == NXRecoveryButtonVolumeUp) ? -1 : 1];
    }
}

- (void)moveRecoveryBy:(NSInteger)delta
{
    self.recoveryIndex = self.recoveryIndex + delta;
    if(self.onMove != nil)
    {
        self.onMove(self, self.recoveryIndex, self.currentRecoveryItem);
    }
}

- (void)performRecoverySelect
{
    NXRecoveryItem *item = self.currentRecoveryItem;
    if(item == nil)
    {
        return;
    }
    
    if(item.action != nil)
    {
        item.action(self);
    }
    
    if(self.recoveryActive && self.onSelect != nil)
    {
        self.onSelect(self, self.recoveryIndex, item);
    }
}

- (void)setRecoveryLogMax:(NSInteger)recoveryLogMax
{
    _recoveryLogMax = MAX(1, recoveryLogMax);
    [self trimRecoveryLog];
    [self paintRecoveryLog];
}

- (NSInteger)rowsForLogText:(NSString *)text
                     columns:(NSUInteger)columns
{
    NSInteger rows = 0;
    for(NSString *part in [(text ?: @"") componentsSeparatedByString:@"\n"])
    {
        NSUInteger len = [part lengthOfBytesUsingEncoding:NSUTF8StringEncoding];
        rows += MAX((NSInteger)1, (NSInteger)((len + columns - 1) / columns));
    }
    return rows;
}

- (BOOL)trimRecoveryLog
{
    BOOL trimmed = NO;
    
    NSInteger over = (NSInteger)self.logLines.count - self.recoveryLogMax;
    if(over > 0)
    {
        [self.logLines removeObjectsInRange:NSMakeRange(0, (NSUInteger)over)];
        trimmed = YES;
    }
    
    if(!self.consoleActive)
    {
        return trimmed;
    }
    
    CGRect frame = self.view.safeAreaLayoutGuide.layoutFrame;
    CGSize cell = [[self makeGlyphViewWrapping:YES color:UIColor.whiteColor bold:NO] cellSizeInPoints];
    CGFloat width = CGRectGetWidth(frame) - NXRecoveryMargin;
    CGFloat height = CGRectGetHeight(frame) - 24.0;
    if(cell.width <= 0.0 || cell.height <= 0.0 || width <= 0.0 || height <= 0.0)
    {
        return trimmed;
    }
    
    NSUInteger columns = (NSUInteger)MAX((NSInteger)1, (NSInteger)floor(width / cell.width));
    NSInteger capacity = MAX((NSInteger)1, (NSInteger)floor(height / cell.height));
    
    NSInteger total = 0;
    for(NXRecoveryLogLine *line in self.logLines)
    {
        total += [self rowsForLogText:line.text columns:columns];
    }
    
    while(total > capacity && self.logLines.count > 1)
    {
        total -= [self rowsForLogText:self.logLines.firstObject.text columns:columns];
        [self.logLines removeObjectAtIndex:0];
        trimmed = YES;
    }
    
    return trimmed;
}

- (UIColor *)logColorForLevel:(NXRecoveryLogLevel)level
{
    return (level == NXRecoveryLogLevelError) ? [self.class recoveryLogErrorColor] : [self.class recoveryLogInfoColor];
}

- (void)paintRecoveryLog
{
    [self createRecoveryView];
    
    for(NXRecoveryGlyphView *row in self.logRows)
    {
        [row removeFromSuperview];
    }
    [self.logRows removeAllObjects];
    
    for(NXRecoveryLogLine *line in self.logLines)
    {
        NXRecoveryGlyphView *v = [self makeGlyphViewWrapping:YES color:[self logColorForLevel:line.level] bold:NO];
        v.text = line.text;
        
        [self.footerStack addArrangedSubview:v];
        [self.logRows addObject:v];
    }
}

- (void)recoveryLog:(NSString *)line
{
    [self recoveryLog:line level:NXRecoveryLogLevelInfo];
}

- (void)recoveryLog:(NSString *)line
              level:(NXRecoveryLogLevel)level
{
    [self createRecoveryView];
    
    for(NSString *part in [(line ?: @"") componentsSeparatedByString:@"\n"])
    {
        [self.logLines addObject:[NXRecoveryLogLine lineWithText:part level:level]];
    }
    
    [self trimRecoveryLog];
    [self paintRecoveryLog];
}

- (void)recoveryLogError:(NSString *)line
{
    [self recoveryLog:line level:NXRecoveryLogLevelError];
}

- (void)clearRecoveryLog
{
    [self.logLines removeAllObjects];
    [self paintRecoveryLog];
}

- (NSFileManager *)fm
{
    return [NSFileManager defaultManager];
}

- (NSString *)fmJoin:(NSString *)dir
                name:(NSString *)name
{
    return [dir isEqualToString:@"/"] ? [@"/" stringByAppendingString:name] : [NSString stringWithFormat:@"%@/%@", dir, name];
}

- (NSString *)fmParentOfPath:(NSString *)p
{
    if([p isEqualToString:@"/"])
    {
        return @"/";
    }
    
    NSString *q = p;
    while(q.length > 1 && [q hasSuffix:@"/"])
    {
        q = [q substringToIndex:q.length - 1];
    }

    NSRange slash = [q rangeOfString:@"/" options:NSBackwardsSearch];
    if(slash.location == NSNotFound || slash.location == 0)
    {
        return @"/";
    }
    return [q substringToIndex:slash.location];
}

- (NXRecoveryEntry*)entryForName:(NSString*)name
                     inDirectory:(NSString*)dir
{
    NXRecoveryEntry *e = [NXRecoveryEntry new];
    e.name = name;
    e.path = [self fmJoin:dir name:name];
    
    NSDictionary *attrs = [self.fm attributesOfItemAtPath:e.path error:NULL];
    NSString *type = attrs[NSFileType];
    
    if([type isEqualToString:NSFileTypeSymbolicLink])
    {
        e.isSymlink = YES;
        e.linkDestination = [self.fm destinationOfSymbolicLinkAtPath:e.path error:NULL];
        BOOL targetIsDir = NO;
        BOOL targetExists = [self.fm fileExistsAtPath:e.path isDirectory:&targetIsDir];
        
        e.isBroken = !targetExists;
        e.isDirectory = targetExists && targetIsDir;
    }
    else
    {
        e.isDirectory = [type isEqualToString:NSFileTypeDirectory];
    }
    
    return e;
}

- (void)browsePath:(NSString *)path
{
    [self browsePath:path root:self.browserRoot header:self.browserHeader onBack:self.browserOnBack onFile:self.browserOnFile];
}

- (void)browsePath:(NSString *)path
              root:(NSString *)root
            header:(NSString *)header
            onBack:(NXRecoveryAction)onBack
            onFile:(NXRecoveryFileHandler)onFile
{
    NSArray<NSString *> *names = [self.fm contentsOfDirectoryAtPath:path error:NULL];
    if(names == nil)
    {
        [self recoveryLogError:[@"open failed: " stringByAppendingString:path]];
        names = @[];
    }
    names = [names sortedArrayUsingSelector:@selector(localizedCompare:)];
    
    NSMutableArray<NXRecoveryEntry*> *dirs = [NSMutableArray array];
    NSMutableArray<NXRecoveryEntry*> *files = [NSMutableArray array];
    for(NSString *name in names)
    {
        NXRecoveryEntry *e = [self entryForName:name inDirectory:path];
        [(e.isDirectory ? dirs : files) addObject:e];
    }
    
    self.browserRoot = root ?: @"/";
    self.browserHeader = header;
    self.browserPath = path;
    self.browserOnBack = onBack;
    self.browserOnFile = onFile;
    
    NSMutableArray<NXRecoveryItem *> *items = [NSMutableArray array];
    NSString *here = [path copy];
    [items addObject:[NXRecoveryItem itemWithTitle:@"../" action:^(NXRecoveryViewController *c){
        if(![here isEqualToString:c.browserRoot])
        {
            [c browsePath:[c fmParentOfPath:here]];
        }
        else if(c.browserOnBack != nil)
        {
            c.browserOnBack(c);
        }
        else
        {
            [c exitRecovery];
        }
    }]];
    
    for(NXRecoveryEntry *e in dirs)
    {
        NSString *full = e.path;
        [items addObject:[NXRecoveryItem itemWithTitle:e.displayTitle action:^(NXRecoveryViewController *c) {
            [c browsePath:full];
        }]];
    }
    
    for(NXRecoveryEntry *e in files)
    {
        NSString *full = e.path;
        NSString *name = e.name;
        BOOL broken = e.isBroken;
        
        [items addObject:[NXRecoveryItem itemWithTitle:e.displayTitle action:^(NXRecoveryViewController *c) {
            if(broken)
            {
                [c recoveryLogError:[@"dangling symlink: " stringByAppendingString:name]];
                return;
            }
            if(c.browserOnFile != nil)
            {
                c.browserOnFile(full, name, c);
            }
        }]];
    }
    
    [self setRecoveryHeader:[NSString stringWithFormat:@"%@\n%@", (header ?: @"Files"), path]];
    [self setRecoveryItems:items];
}

- (void)enterFileBrowserAtPath:(NSString *)path
                          root:(NSString *)root
                        header:(NSString *)header
                        onBack:(NXRecoveryAction)onBack
                        onFile:(NXRecoveryFileHandler)onFile
{
    [self enterRecoveryWithHeader:(header ?: @"Files") instructions:nil footer:nil items:@[] onSelect:nil onMove:nil];
    [self browsePath:path root:root header:header onBack:onBack onFile:onFile];
}

- (void)enterConsole
{
    [self createRecoveryView];
    if(self.consoleActive)
    {
        return;
    }
    
    self.consoleActive = YES;
    self.consoleSelectAction = nil;
    
    self.savedLogMax = self.recoveryLogMax;
    _recoveryLogMax = 1024;
    
    self.headerView.hidden = YES;
    self.instructionsView.hidden = YES;
    self.menuStack.hidden = YES;
    self.view.userInteractionEnabled = NO;
    
    self.menuFooterConstraint.active = NO;
    self.consoleTopConstraint.active = YES;
    [self.view setNeedsLayout];
    [self.view layoutIfNeeded];
    
    [self trimRecoveryLog];
    [self paintRecoveryLog];
}

- (void)finishConsoleWithSelectAction:(NXRecoveryAction)action
{
    if(!self.consoleActive)
    {
        return;
    }
    self.consoleSelectAction = action;
}

- (void)exitConsole
{
    if(!self.consoleActive)
    {
        return;
    }
    
    self.consoleActive = NO;
    self.consoleSelectAction = nil;
    
    self.consoleTopConstraint.active = NO;
    self.menuFooterConstraint.active = YES;
    
    self.headerView.hidden = NO;
    self.instructionsView.hidden = NO;
    self.menuStack.hidden = NO;
    self.view.userInteractionEnabled = YES;
    
    self.recoveryLogMax = self.savedLogMax;
}

@end
