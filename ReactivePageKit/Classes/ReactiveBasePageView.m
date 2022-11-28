//
//  ReactiveBasePageView.m
//  ReactivePageKit
//
//  Created by leon0206 on 2018/2/2.
//

#import "ReactiveBasePageView.h"
#import <AKOCommonToolsKit/AKOCommonToolsKit.h>
#import <ReactiveObjC/ReactiveObjC.h>
#import "ReactiveBaseModuleView.h"
#import "ReactiveBaseModuleViewDelegate.h"

@interface ReactiveBasePageView ()<UIScrollViewDelegate>
@property (nonatomic, strong) UIScrollView *scrollView;
@property (nonatomic, strong) UIView *contentView;
@end

@implementation ReactiveBasePageView

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        [self loadSubviews];
    }
    return self;
}

- (void)setModel:(id)model
{
    _model = model;
    if (_model != nil) {
        [self refreshAllModuleViews];
    }
}

/***须子类重写***/
- (NSArray *)moduleViews
{
    return @[];
}

- (ReactiveBlackBoard *)blackBoard
{
    if(nil == _blackBoard){
        _blackBoard = [[ReactiveBlackBoard alloc] init];
    }
    return _blackBoard;
}

- (void)loadSubviews
{
    self.scrollView = [UIScrollView new];
    self.scrollView.backgroundColor = [UIColor clearColor];
    [self addSubview:self.scrollView];
    self.scrollView.bounces = NO;
    self.scrollView.showsVerticalScrollIndicator = NO;
    self.scrollView.showsHorizontalScrollIndicator = NO;
    self.scrollView.delegate = self;
    self.contentView = [UIView new];
    self.contentView.backgroundColor = [UIColor clearColor];
    [self.scrollView addSubview:self.contentView];
    [self loadContentModuleViews];
}

//加载所有ModuleView
- (void)loadContentModuleViews
{
    for (NSString *obj in [self moduleViews]) {
        [self.contentView addSubview:[[NSClassFromString(obj) alloc] initWithBoard:self.blackBoard]];
    }
    [self loadContentModuleSubViews];
}

//加载所有ModuleView的子View
- (void)loadContentModuleSubViews
{
    [self.contentView.subviews enumerateObjectsUsingBlock:^(__kindof ReactiveBaseModuleView * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        if ([obj conformsToProtocol:@protocol(ReactiveBaseModuleViewDelegate)]) {
            [obj loadModuleSubViews];
        }
    }];
}


//刷新所有模块
- (void)refreshAllModuleViews
{
    [self loadContentModulesData];
    [self layoutModuleViews];
}

//分发数据并绑定height变化监测
- (void)loadContentModulesData
{
    [self.contentView.subviews enumerateObjectsUsingBlock:^(__kindof ReactiveBaseModuleView * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        obj.moduleIndex = idx;
        if ([obj conformsToProtocol:@protocol(ReactiveBaseModuleViewDelegate)]) {
            [obj loadModuleData:self.model];
        }
    }];
    [self bindModuleViewsHeight];
}

- (void)bindModuleViewsHeight
{
    __block RACSignal *signal = [RACSubject subject];
    [self.contentView.subviews enumerateObjectsUsingBlock:^(__kindof ReactiveBaseModuleView * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        RACSubject *s = obj.heightSignal;
        if (idx == 0) {
            signal = s;
        } else {
            signal = [signal merge:s];
        }
    }];
    @weakify(self);
    [[[signal distinctUntilChanged] skip:0] subscribeNext:^(id x) {
        @strongify(self);
        [self relayoutModuleViewsWithIndex:[x integerValue]];
    }];
}

//所有模块布局
- (void)layoutModuleViews
{
    __block CGFloat layoutOffestY = 0.0;
    @weakify(self);
    [self.contentView.subviews enumerateObjectsUsingBlock:^(__kindof UIView * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        @strongify(self);
        if ([obj conformsToProtocol:@protocol(ReactiveBaseModuleViewDelegate)]) {
            [obj layoutModuleWidth:[self contentWidth]];
            obj.top = layoutOffestY;
            obj.left = 0;
            layoutOffestY = obj.bottom + [self spaceBetweenModuleViews];
        }
    }];
    self.contentView.frame = CGRectMake(0, 0, self.width, layoutOffestY);
    self.scrollView.contentSize = CGSizeMake(self.width, layoutOffestY);
}

//指定模块的布局刷新
- (void)relayoutModuleViewsWithIndex:(NSUInteger)index
{
    __block CGFloat layoutOffestY = [self.contentView.subviews objectAtIndex:index].bottom;
    NSUInteger location = index + 1;
    NSRange range = NSMakeRange(location, self.contentView.subviews.count - location);
    [[self.contentView.subviews subarrayWithRange:range] enumerateObjectsUsingBlock:^(__kindof UIView * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        obj.top = layoutOffestY + [self spaceBetweenModuleViews];
        layoutOffestY = obj.bottom;
    }];
    self.contentView.frame = CGRectMake(0, 0, self.width, layoutOffestY);
    self.scrollView.contentSize = CGSizeMake(self.width, layoutOffestY);
}

/***子类可重写***/
- (CGFloat)spaceBetweenModuleViews
{
    return 0.0;
}

- (CGFloat)contentWidth
{
    return self.frame.size.width;
}

- (CGFloat)contentHeight
{
    return self.frame.size.height;
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    self.scrollView.frame = CGRectMake(0, 0, [self contentWidth], [self contentHeight]);
    self.contentView.top = 0;
    self.contentView.left = 0;
    self.contentView.width = self.scrollView.width;
}

@end
