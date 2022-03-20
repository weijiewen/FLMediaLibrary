//
//  JYPlayer.h
//  gx_dxka
//
//  Created by Haoxing on 2020/9/4.
//  Copyright © 2020 haoxing. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

NS_ASSUME_NONNULL_BEGIN

@protocol JYPlayerDelegate <NSObject>
@optional

/// 播放状态改变
/// @param status status description
- (void)mediaPlayerStatusChange:(AVPlayerStatus)status;

/// 加载本地缓存失败(文件损坏)后会调用该方法，在此方法重新初始化播放器
- (void)mediaPlayerReloadItem;

/// 缓冲进度改变
/// @param loadedTime 当前缓冲的秒数
- (void)mediaPlayerLoadedTimeChange:(NSTimeInterval)loadedTime;

/// 开始加载
- (void)mediaPlayerStartLoading;

/// 加载结束
- (void)mediaPlayerStopLoading;

/// 播放进度回调
/// @param pregress pregress description
- (void)mediaPlayerProgress:(CGFloat)pregress;

/// 播放结束
- (void)mediaPlayerDidEnd;
@end

@interface JYPlayer : NSObject
@property (nonatomic, assign, readonly) BOOL isPlaying;
@property (nonatomic, assign, readonly) AVPlayerStatus status;
@property (nonatomic, assign, readonly) CMTime currentTime;
@property (nonatomic, assign, readonly) CMTime duration;
@property (nonatomic, weak, readonly) AVAsset *asset;
@property (nonatomic, assign) CGFloat volume;

- (instancetype)initWithObjectKey:(NSString *)objectKey;

- (instancetype)initWithObjectKey:(NSString *)objectKey
                         delegate:(nullable id <JYPlayerDelegate>)delegate;

- (instancetype)initWithItem:(AVPlayerItem *)item delegate:(id <JYPlayerDelegate>)delegate;

- (AVPlayerLayer *)creatPlayerLayer;

- (void)play;
- (void)pause;
- (void)seekToTime:(CMTime)time completionHandler:(nullable void(^)(BOOL finished))completionHandler;

@end

NS_ASSUME_NONNULL_END
