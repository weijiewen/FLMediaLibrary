//
//  FLTips.m
//  FLKit_Example
//
//  Created by tckj on 2022/3/11.
//  Copyright © 2022 weijiwen. All rights reserved.
//

#import <objc/runtime.h>
#import "FLTips.h"

@interface FLTip : UIView
@property (nonatomic, copy) dispatch_block_t action;
@end

@interface UIView (FLTipProperty)
@property (nonatomic, strong) FLTip *fl_currentTip;
@end

@implementation UIView (FLTipProperty)
- (void)setFl_currentTip:(FLTips *)fl_currentTip {
    objc_setAssociatedObject(self, @selector(fl_currentTip), fl_currentTip, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}
- (FLTips *)fl_currentTip {
    return objc_getAssociatedObject(self, _cmd);
}
@end

@implementation FLTip

+ (instancetype)loadToView:(UIView *)view color:(UIColor *)color {
    [view.fl_currentTip removeFromSuperview];
    view.fl_currentTip = nil;
    FLTip *tip = FLTip.alloc.init;
    tip.backgroundColor = color;
    [view addSubview:tip];
    [tip addLayoutConstraint];
    [tip addActivityIndicatorView];
    return tip;
}

- (void)addLayoutConstraint {
    self.translatesAutoresizingMaskIntoConstraints = NO;
    if ([self.superview isKindOfClass:UIScrollView.class]) {
        [NSLayoutConstraint activateConstraints:@[
            [NSLayoutConstraint constraintWithItem:self attribute:NSLayoutAttributeWidth relatedBy:NSLayoutRelationEqual toItem:self.superview attribute:NSLayoutAttributeWidth multiplier:1 constant:0],
            [NSLayoutConstraint constraintWithItem:self attribute:NSLayoutAttributeHeight relatedBy:NSLayoutRelationEqual toItem:self.superview attribute:NSLayoutAttributeHeight multiplier:1 constant:0],
            [NSLayoutConstraint constraintWithItem:self attribute:NSLayoutAttributeCenterX relatedBy:NSLayoutRelationEqual toItem:self.superview attribute:NSLayoutAttributeCenterX multiplier:1 constant:0],
            [NSLayoutConstraint constraintWithItem:self attribute:NSLayoutAttributeCenterY relatedBy:NSLayoutRelationEqual toItem:self.superview attribute:NSLayoutAttributeCenterY multiplier:1 constant:0]
        ]];
    }
    else {
        [NSLayoutConstraint activateConstraints:@[
            [NSLayoutConstraint constraintWithItem:self attribute:NSLayoutAttributeLeft relatedBy:NSLayoutRelationEqual toItem:self.superview attribute:NSLayoutAttributeLeft multiplier:1 constant:0],
            [NSLayoutConstraint constraintWithItem:self attribute:NSLayoutAttributeTop relatedBy:NSLayoutRelationEqual toItem:self.superview attribute:NSLayoutAttributeTop multiplier:1 constant:0],
            [NSLayoutConstraint constraintWithItem:self attribute:NSLayoutAttributeRight relatedBy:NSLayoutRelationEqual toItem:self.superview attribute:NSLayoutAttributeRight multiplier:1 constant:0],
            [NSLayoutConstraint constraintWithItem:self attribute:NSLayoutAttributeBottom relatedBy:NSLayoutRelationEqual toItem:self.superview attribute:NSLayoutAttributeBottom multiplier:1 constant:0]
        ]];
    }
}

- (void)addActivityIndicatorView {
    UIColor *backgroundColor = self.backgroundColor;
    UIView *superView = self.superview;
    BOOL flag = superView != nil;
    while (flag && (!backgroundColor || backgroundColor == UIColor.clearColor) && superView) {
        backgroundColor = superView.backgroundColor;
        superView = superView.superview;
    }
    UIActivityIndicatorViewStyle style;
    UIColor *color = UIColor.grayColor;
    if (@available(iOS 13.0, *)) {
        style = UIActivityIndicatorViewStyleMedium;
        if ([FLTip isGrayColor:backgroundColor]) {
            color = UIColor.whiteColor;
        }
    }
    else {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
        style = UIActivityIndicatorViewStyleGray;
        if ([FLTip isGrayColor:backgroundColor]) {
            style = UIActivityIndicatorViewStyleWhite;
            color = UIColor.whiteColor;
        }
#pragma clang diagnostic pop
    }
    UIActivityIndicatorView *indicatorView = [UIActivityIndicatorView.alloc initWithActivityIndicatorStyle:style];
    indicatorView.translatesAutoresizingMaskIntoConstraints = NO;
    indicatorView.color = color;
    [self addSubview:indicatorView];
    
    [NSLayoutConstraint activateConstraints:@[
        [NSLayoutConstraint constraintWithItem:indicatorView attribute:NSLayoutAttributeCenterX relatedBy:NSLayoutRelationEqual toItem:self attribute:NSLayoutAttributeCenterX multiplier:1 constant:0],
        [NSLayoutConstraint constraintWithItem:indicatorView attribute:NSLayoutAttributeCenterY relatedBy:NSLayoutRelationEqual toItem:self attribute:NSLayoutAttributeCenterY multiplier:1 constant:0]
    ]];
    [indicatorView startAnimating];
}

+ (BOOL)isGrayColor:(UIColor *)color {
    CGFloat r = 0.f;
    CGFloat g = 0.f;
    CGFloat b = 0.f;
    CGFloat a = 0.f;
    [color getRed:&r green:&g blue:&b alpha:&a];
    CGFloat value = (r * 255.f * 299 + g * 255.f * 578 + b * 255.f * 114) / 1000.f;
    return value < 192;
}

+ (FLTip *)showTipToView:(UIView *)view
                    text:(NSAttributedString *)text
              buttonText:(nullable NSAttributedString *)buttonText
                  action:(nullable dispatch_block_t)action {
    [view.fl_currentTip removeFromSuperview];
    view.fl_currentTip = nil;
    FLTip *tip = FLTip.alloc.init;
    [view addSubview:tip];
    [tip addLayoutConstraint];
    [tip addText:text buttonText:buttonText action:action];
    return tip;
}

- (void)addText:(NSAttributedString *)text
     buttonText:(nullable NSAttributedString *)buttonText
         action:(nullable dispatch_block_t)action {
    UILabel *label = UILabel.alloc.init;
    label.translatesAutoresizingMaskIntoConstraints = NO;
    label.numberOfLines = 0;
    label.textAlignment = NSTextAlignmentCenter;
    label.attributedText = text;
    [self addSubview:label];
    
    [NSLayoutConstraint activateConstraints:@[
        [NSLayoutConstraint constraintWithItem:label attribute:NSLayoutAttributeCenterX relatedBy:NSLayoutRelationEqual toItem:self attribute:NSLayoutAttributeCenterX multiplier:1 constant:0],
        [NSLayoutConstraint constraintWithItem:label attribute:NSLayoutAttributeWidth relatedBy:NSLayoutRelationLessThanOrEqual toItem:self attribute:NSLayoutAttributeWidth multiplier:0.9 constant:0]
    ]];
    
    if (buttonText && buttonText.length) {
        self.action = action;
        UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
        button.translatesAutoresizingMaskIntoConstraints = NO;
        [button setAttributedTitle:buttonText forState:UIControlStateNormal];
        [button addTarget:self action:@selector(action_button) forControlEvents:UIControlEventTouchUpInside];
        [self addSubview:button];
        [NSLayoutConstraint activateConstraints:@[
            [NSLayoutConstraint constraintWithItem:label attribute:NSLayoutAttributeCenterY relatedBy:NSLayoutRelationEqual toItem:self attribute:NSLayoutAttributeCenterY multiplier:1 constant:-10],
            [NSLayoutConstraint constraintWithItem:button attribute:NSLayoutAttributeCenterX relatedBy:NSLayoutRelationEqual toItem:self attribute:NSLayoutAttributeCenterX multiplier:1 constant:0],
            [NSLayoutConstraint constraintWithItem:button attribute:NSLayoutAttributeTop relatedBy:NSLayoutRelationEqual toItem:label attribute:NSLayoutAttributeBottom multiplier:1 constant:5],
        ]];
    }
    else {
        [self addConstraint:[NSLayoutConstraint constraintWithItem:label attribute:NSLayoutAttributeCenterY relatedBy:NSLayoutRelationEqual toItem:self attribute:NSLayoutAttributeCenterY multiplier:1 constant:0]];
    }
}

- (void)action_button {
    !self.action ?: self.action();
}

@end

@implementation UIView (FLTip)

- (void)fl_showLoading {
    [self fl_showLoadingWithColor:UIColor.clearColor];
}

- (void)fl_showLoadingWithColor:(UIColor *)color {
    [self fl_dismiss];
    self.fl_currentTip = [FLTip loadToView:self color:color];
}

- (void)fl_showTip:(NSAttributedString *)text {
    [self fl_showTip:text buttonText:nil action:nil];
}

- (void)fl_showTip:(NSAttributedString *)text
        buttonText:(nullable NSAttributedString *)buttonText
            action:(nullable dispatch_block_t)action {
    self.fl_currentTip = [FLTip showTipToView:self text:text buttonText:buttonText action:action];
}

- (void)fl_dismiss {
    [self.fl_currentTip removeFromSuperview];
}

@end

@interface FLTips ()
@property (nonatomic, strong) UIWindow *tipWindow;
@property (nonatomic, weak) UIView *hasTipView;
+ (instancetype)tips;
@end
@implementation FLTips

+ (instancetype)tips {
    static FLTips *tips;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        tips = FLTips.alloc.init;
    });
    return tips;
}

+ (void)showLoading {
    [FLTips.tips.hasTipView removeFromSuperview];
    UIWindow *window = FLTips.tips.tipWindow;
    CGSize size = UIScreen.mainScreen.bounds.size;
    CGFloat statusHeight = UIApplication.sharedApplication.statusBarFrame.size.height;
    window.frame = CGRectMake(0, statusHeight, size.width, size.height - statusHeight);
    window.userInteractionEnabled = YES;
    window.hidden = NO;
    
    CGSize tipSize = CGSizeMake(90, 70);
    UIView *tipView = UIView.alloc.init;;
    tipView.layer.cornerRadius = 7;
    tipView.backgroundColor = [UIColor colorWithWhite:0 alpha:0.8];
    tipView.clipsToBounds = YES;
    tipView.alpha = 0;
    tipView.transform = CGAffineTransformMakeScale(0.5, 0.5);
    tipView.translatesAutoresizingMaskIntoConstraints = NO;
    [window addSubview:tipView];
    UIActivityIndicatorView *loadingView = [UIActivityIndicatorView.alloc initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhite];
    loadingView.translatesAutoresizingMaskIntoConstraints = NO;
    [loadingView startAnimating];
    [tipView addSubview:loadingView];
    
    FLTips.tips.hasTipView = tipView;
    [NSLayoutConstraint activateConstraints:@[
        [NSLayoutConstraint constraintWithItem:tipView attribute:NSLayoutAttributeCenterX relatedBy:NSLayoutRelationEqual toItem:window attribute:NSLayoutAttributeCenterX multiplier:1 constant:0],
        [NSLayoutConstraint constraintWithItem:tipView attribute:NSLayoutAttributeCenterY relatedBy:NSLayoutRelationEqual toItem:window attribute:NSLayoutAttributeCenterY multiplier:1 constant:0],
        [NSLayoutConstraint constraintWithItem:tipView attribute:NSLayoutAttributeWidth relatedBy:NSLayoutRelationEqual toItem:nil attribute:NSLayoutAttributeNotAnAttribute multiplier:1 constant:tipSize.width],
        [NSLayoutConstraint constraintWithItem:tipView attribute:NSLayoutAttributeHeight relatedBy:NSLayoutRelationEqual toItem:nil attribute:NSLayoutAttributeNotAnAttribute multiplier:1 constant:tipSize.height],
        [NSLayoutConstraint constraintWithItem:loadingView attribute:NSLayoutAttributeCenterX relatedBy:NSLayoutRelationEqual toItem:tipView attribute:NSLayoutAttributeCenterX multiplier:1 constant:0],
        [NSLayoutConstraint constraintWithItem:loadingView attribute:NSLayoutAttributeCenterY relatedBy:NSLayoutRelationEqual toItem:tipView attribute:NSLayoutAttributeCenterY multiplier:1 constant:0],
    ]];
    
    [UIView animateWithDuration:0.3 animations:^{
        tipView.alpha = 1;
        tipView.transform = CGAffineTransformIdentity;
    }];
}

+ (void)dismiss {
    UIWindow *window = FLTips.tips.tipWindow;
    UIView *tipsView = FLTips.tips.hasTipView;
    [UIView animateWithDuration:0.3 animations:^{
        tipsView.alpha = 0;
        tipsView.transform = CGAffineTransformMakeScale(0.6, 0.6);
    } completion:^(BOOL finished) {
        [tipsView removeFromSuperview];
        if (FLTips.tips.hasTipView &&
            FLTips.tips.hasTipView == tipsView) {
            window.hidden = YES;
        }
    }];
}

+ (void)tip:(NSString *)tip {
    [FLTips.tips tip:tip];
}

- (void)tip:(NSString *)tip {
    [self.hasTipView removeFromSuperview];
    
    CGSize size = UIScreen.mainScreen.bounds.size;
    CGFloat statusHeight = UIApplication.sharedApplication.statusBarFrame.size.height;
    self.tipWindow.frame = CGRectMake(0, statusHeight, size.width, size.height - statusHeight);
    self.tipWindow.userInteractionEnabled = NO;
    self.tipWindow.hidden = NO;
    
    UIView *tipView = UIView.alloc.init;
    tipView.translatesAutoresizingMaskIntoConstraints = NO;
    tipView.backgroundColor = [UIColor colorWithWhite:0 alpha:0.7];
    tipView.layer.cornerRadius = 10;
    tipView.alpha = 0;
    tipView.transform = CGAffineTransformMakeScale(0.7, 0.7);
    [self.tipWindow addSubview:tipView];
    self.hasTipView = tipView;
    
    UILabel *tipLabel = UILabel.alloc.init;
    tipLabel.translatesAutoresizingMaskIntoConstraints = NO;
    tipLabel.font = [UIFont systemFontOfSize:14];
    tipLabel.textColor = UIColor.whiteColor;
    tipLabel.textAlignment = NSTextAlignmentCenter;
    tipLabel.numberOfLines = 0;
    tipLabel.text = tip;
    [tipView addSubview:tipLabel];
    
    [NSLayoutConstraint activateConstraints:@[
        [NSLayoutConstraint constraintWithItem:tipView attribute:NSLayoutAttributeCenterX relatedBy:NSLayoutRelationEqual toItem:self.tipWindow attribute:NSLayoutAttributeCenterX multiplier:1 constant:0],
        [NSLayoutConstraint constraintWithItem:tipView attribute:NSLayoutAttributeBottom relatedBy:NSLayoutRelationEqual toItem:self.tipWindow attribute:NSLayoutAttributeBottom multiplier:1 constant:-100 - self.tipWindow.safeAreaInsets.bottom],
        [NSLayoutConstraint constraintWithItem:tipView attribute:NSLayoutAttributeWidth relatedBy:NSLayoutRelationLessThanOrEqual toItem:self.tipWindow attribute:NSLayoutAttributeWidth multiplier:0.9 constant:0],
        [NSLayoutConstraint constraintWithItem:tipLabel attribute:NSLayoutAttributeLeft relatedBy:NSLayoutRelationEqual toItem:tipView attribute:NSLayoutAttributeLeft multiplier:1 constant:10],
        [NSLayoutConstraint constraintWithItem:tipLabel attribute:NSLayoutAttributeTop relatedBy:NSLayoutRelationEqual toItem:tipView attribute:NSLayoutAttributeTop multiplier:1 constant:10],
        [NSLayoutConstraint constraintWithItem:tipLabel attribute:NSLayoutAttributeRight relatedBy:NSLayoutRelationEqual toItem:tipView attribute:NSLayoutAttributeRight multiplier:1 constant:-10],
        [NSLayoutConstraint constraintWithItem:tipLabel attribute:NSLayoutAttributeBottom relatedBy:NSLayoutRelationEqual toItem:tipView attribute:NSLayoutAttributeBottom multiplier:1 constant:-10],
    ]];
    
    [UIView animateWithDuration:0.3 animations:^{
        tipView.alpha = 1;
        tipView.transform = CGAffineTransformIdentity;
    }];
    NSTimeInterval duration = 1.5 + tip.length % 5 * 0.5;
    if (duration > 5) {
        duration = 5;
    }
    __weak typeof(tipView) weak_tipView = tipView;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(duration * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if (weak_tipView) {
            [UIView animateWithDuration:0.3 animations:^{
                weak_tipView.alpha = 0;
                weak_tipView.transform = CGAffineTransformMakeScale(0.7, 0.7);
            } completion:^(BOOL finished) {
                if (self.hasTipView == weak_tipView) {
                    self.tipWindow.userInteractionEnabled = NO;
                    self.tipWindow.hidden = NO;
                }
                [weak_tipView removeFromSuperview];
            }];
        }
    });
}

- (UIWindow *)tipWindow {
    if (!_tipWindow) {
        CGFloat statusHeight = UIApplication.sharedApplication.statusBarFrame.size.height;
        CGSize size = UIScreen.mainScreen.bounds.size;
        _tipWindow = [UIWindow.alloc initWithFrame:CGRectMake(0, statusHeight, size.width, size.height - statusHeight)];
        _tipWindow.backgroundColor = UIColor.clearColor;
        _tipWindow.windowLevel = UIWindowLevelAlert - 1;
        _tipWindow.rootViewController = UIViewController.alloc.init;
        _tipWindow.rootViewController.view.backgroundColor = UIColor.clearColor;
    }
    return _tipWindow;
}

@end
