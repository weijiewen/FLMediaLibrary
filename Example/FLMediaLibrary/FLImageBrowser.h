//
//  FLImageBrowser.h
//  FLMediaLibrary_Example
//
//  Created by weijiewen on 2022/4/12.
//  Copyright © 2022 weijiwen. All rights reserved.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@protocol FLImageBrowserPlayer <NSObject>
@required
- (void)play;
- (void)pause;
- (BOOL)isPause;
@end

@interface FLImageBrowser : NSObject

+ (void)showWithCount:(NSInteger)count
           startIndex:(NSInteger)startIndex
         requestImage:(void(^)(UIImageView *imageView, NSInteger index, UIImage * _Nullable placeholder))requestImage;

+ (void)showWithCount:(NSInteger)count
           startIndex:(NSInteger)startIndex
         requestImage:(void(^)(UIImageView *imageView, NSInteger index, UIImage * _Nullable placeholder))requestImage
      sourceImageView:(nullable UIImageView * _Nullable (^)(NSInteger index))sourceImageView;

+ (void)showWithCount:(NSInteger)count
           startIndex:(NSInteger)startIndex
         requestImage:(void(^)(UIImageView *imageView, NSInteger index, UIImage * _Nullable placeholder))requestImage
      sourceImageView:(nullable UIImageView * _Nullable (^)(NSInteger index))sourceImageView
             willShow:(nullable id <FLImageBrowserPlayer> _Nullable (^)(UIView *contentView, UIImageView *imageView, NSInteger index))willShow;

+ (void)showWithCount:(NSInteger)count
           startIndex:(NSInteger)startIndex
         requestImage:(void(^)(UIImageView *imageView, NSInteger index, UIImage * _Nullable placeholder))requestImage
      sourceImageView:(nullable UIImageView * _Nullable (^)(NSInteger index))sourceImageView
             willShow:(nullable id <FLImageBrowserPlayer> _Nullable (^)(UIView *contentView, UIImageView *imageView, NSInteger index))willShow
           didDismiss:(nullable dispatch_block_t)didDismiss;

+ (void)showWithCount:(NSInteger)count
           startIndex:(NSInteger)startIndex
         requestImage:(void(^)(UIImageView *imageView, NSInteger index, UIImage * _Nullable placeholder))requestImage
      sourceImageView:(nullable UIImageView * _Nullable (^)(NSInteger index))sourceImageView
             willShow:(nullable id <FLImageBrowserPlayer> _Nullable (^)(UIView *contentView, UIImageView *imageView, NSInteger index))willShow
            longPress:(nullable void(^)(NSInteger index, UIImage *image))longPress
           didDismiss:(nullable dispatch_block_t)didDismiss;

@end

NS_ASSUME_NONNULL_END
