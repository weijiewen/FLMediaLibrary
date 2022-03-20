//
//  MTImageBrowserController.h
//  MTKit_Example
//
//  Created by iMac on 2019/4/20.
//  Copyright © 2019 txyMTw@icloud.com. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "../../Custom/View/JYPhotos/JYPhotos.h"
#import "JYPlayer/JYPlayer.h"

NS_ASSUME_NONNULL_BEGIN

@interface UIView (MediaPlayer)
- (void)playMediaVideoWithObjectKey:(NSString *)objectKey;
- (void)playAssetVideoWithAsset:(JYAsset *)asset;
- (void)stopPlayer;
@end


/**
 图片浏览器
 */
@interface JYImageBrowser : UIViewController


+ (void)showImageCount:(NSInteger)imageCount
          browserIndex:(NSInteger)browserIndex
         fromImageView:(UIImageView *(^)(NSInteger index))fromImageView
              setImage:(void(^)(UIImageView *imageView, NSInteger index, JYImageBrowser *controller))setImage;

+ (void)showImageCount:(NSInteger)imageCount
          browserIndex:(NSInteger)browserIndex
         fromImageView:(UIImageView *(^)(NSInteger index))fromImageView
              setImage:(void(^)(UIImageView *imageView, NSInteger index, JYImageBrowser *controller))setImage
               dismiss:(dispatch_block_t)dismiss;

+ (void)showImageCount:(NSInteger)imageCount
          browserIndex:(NSInteger)browserIndex
         fromImageView:(UIImageView *(^)(NSInteger index))fromImageView
              setImage:(void(^)(UIImageView *imageView, NSInteger index, JYImageBrowser *controller))setImage
              scrollTo:(void(^)(UIView *currentView, NSInteger index, dispatch_block_t disenableScale))scrollTo;

+ (void)showImageCount:(NSInteger)imageCount
          browserIndex:(NSInteger)browserIndex
         fromImageView:(UIImageView *(^)(NSInteger index))fromImageView
              setImage:(void(^)(UIImageView *imageView, NSInteger index, JYImageBrowser *controller))setImage
              scrollTo:(nullable void(^)(UIView *currentView, NSInteger index, dispatch_block_t disenableScale))scrollTo
             longPress:(nullable void(^)(NSInteger index, UIImage *image, JYImageBrowser *controller))longPress;

@end

NS_ASSUME_NONNULL_END
