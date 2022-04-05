//
//  FLTips.h
//  FLKit_Example
//
//  Created by tckj on 2022/3/11.
//  Copyright © 2022 weijiwen. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface FLTips : NSObject
+ (void)tip:(NSString *)tip;
+ (void)showLoading;
+ (void)dismiss;
@end

@interface UIView (FLTip)

- (void)fl_showLoading;

- (void)fl_showLoadingWithColor:(UIColor *)color;

- (void)fl_showTip:(NSAttributedString *)text;

- (void)fl_showTip:(NSAttributedString *)text
        buttonText:(nullable NSAttributedString *)buttonText
            action:(nullable dispatch_block_t)action;

- (void)fl_dismiss;

@end

NS_ASSUME_NONNULL_END
