//
//  FLMediaPlayer.h
//  FLMediaLibrary_Example
//
//  Created by tckj on 2022/3/14.
//  Copyright © 2022 weijiwen. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "FLMediaItem.h"
#import "FLImageBrowserDelegate.h"

NS_ASSUME_NONNULL_BEGIN

@class FLMediaPlayer;
@protocol FLMediaPlayerDelegate <NSObject>
@optional

/// 需要加载loading
- (void)playerStartLoading:(FLMediaPlayer *)player;

/// 需要停止loading
- (void)playerStopLoading:(FLMediaPlayer *)player;

/// 播放结束，如果loop为YES 该方法不会回调
- (void)playerFinish:(FLMediaPlayer *)player;

/// 播放失败
- (void)playerFailure:(FLMediaPlayer *)player error:(NSError *)error;

/// 播放时间改变
- (void)playerTimeChange:(FLMediaPlayer *)player currentSeconds:(NSTimeInterval)currentSeconds duration:(NSTimeInterval)duration;

/// 缓冲进度改变
- (void)playerCacheRangeChange:(FLMediaPlayer *)player cacheSeconds:(NSTimeInterval)cacheSeconds duration:(NSTimeInterval)duration;
@end

typedef NS_ENUM(NSUInteger, FLMediaPlayContentMode) {
    /// 保持宽高比最长边充满视图
    FLMediaPlayContentModeAspectFit,
    
    /// 保持宽高比最短边充满视图
    FLMediaPlayContentModeAspectFill,
    
    /// 按照视图尺寸拉伸
    FLMediaPlayContentModeResize,
};

@interface FLMediaPlayView : UIView
@property (nonatomic, assign) FLMediaPlayContentMode playMode;
@end

@interface FLMediaPlayer : NSObject <FLImageBrowserPlayer>

@property (nonatomic, readonly) FLMediaPlayView *playView;
/// 是否已暂停
@property (nonatomic, readonly) BOOL isPause;
/// 是否加载后自动开始播放，默认YES
@property (nonatomic, assign) BOOL autoPlay;
/// 是否循环播放，默认NO
@property (nonatomic, assign) BOOL loop;
/// 视频时长
@property (nonatomic, readonly) NSTimeInterval duration;

+ (instancetype)playerItem:(FLMediaItem *)item;

+ (instancetype)playerItem:(FLMediaItem *)item delegate:(nullable id <FLMediaPlayerDelegate>)delegate;

/// 重新加载
- (void)reloadPlayer;

/// 播放
- (void)play;

/// 暂停
- (void)pause;

/// 跳转
/// @param seconds seconds description
/// @param completion completion description
- (void)seekToSeconds:(NSTimeInterval)seconds completion:(void(^)(BOOL finished))completion;

@end

NS_ASSUME_NONNULL_END
