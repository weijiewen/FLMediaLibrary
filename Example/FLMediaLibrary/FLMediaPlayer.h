//
//  FLMediaPlayer.h
//  FLMediaLibrary_Example
//
//  Created by tckj on 2022/3/14.
//  Copyright © 2022 weijiwen. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class FLMediaPlayer;
@protocol FLMediaPlayerDelegate <NSObject>
@optional
/// 缓存不足以继续播放，此处加载loading
- (void)playerLoadData:(FLMediaPlayer *)player;

/// 开始播放、或重新开始播放、或暂停后开始播放回调该方法
- (void)playerPlaying:(FLMediaPlayer *)player;

/// 播放结束，如果loop为YES 该方法不会回调
- (void)playerFinish:(FLMediaPlayer *)player;

/// 播放失败
- (void)playerFailure:(FLMediaPlayer *)player error:(NSError *)error;

/// 播放时间改变
- (void)playerTimeChange:(FLMediaPlayer *)player currentSeconds:(NSTimeInterval)currentSeconds duration:(NSTimeInterval)duration;

/// 缓冲进度改变
- (void)playerCacheRangeChange:(FLMediaPlayer *)player cacheSeconds:(NSTimeInterval)cacheSeconds duration:(NSTimeInterval)duration;
@end

@protocol FLMediaPlayerDataSource <NSObject>
@required

/// 自己处理下载返回YES，返回NO 使用内部NSURLSessionDataTask http下载
/// @param player player description
/// @param key 原传入的key
- (BOOL)playerIsCustom:(FLMediaPlayer *)player
                   key:(NSString *)key;

/// 播放器需要请求视频数据
/// @param player player description
/// @param identifier 请求标识符，取消请求使用
/// @param key 原传入的key
/// @param start 开始下标
/// @param end 结束下标
/// @param response 返回响应头
/// @param appendData 填充数据
/// @param completion 请求失败或成功
- (void)playerWillRequest:(FLMediaPlayer *)player
               identifier:(NSString *)identifier
                      key:(NSString *)key
                    start:(long long)start
                      end:(long long)end
                 response:(void(^)(NSURLResponse *response))response
               appendData:(void(^)(NSData *data))appendData
               completion:(void(^)(NSError *error))completion;

/// 播放器已取消请求
/// @param player player description
/// @param request request description
- (void)playerCancelRequest:(FLMediaPlayer *)player
                 identifier:(NSString *)identifier;
@end

@interface FLMediaPlayer : NSObject
@property (nonatomic, weak) id <FLMediaPlayerDelegate> delegate;
/// 播放器下载代理，不设置该代理则使用NSURLSession http下载，   如视频资源在阿里云OSS私有空间时使用该代理
@property (nonatomic, weak) id <FLMediaPlayerDataSource> dataSource;
/// 是否加载后自动开始播放，默认YES
@property (nonatomic, assign) BOOL autoPlay;
/// 是否循环播放，默认NO
@property (nonatomic, assign) BOOL loop;
/// 视频时长
@property (nonatomic, assign) CMTime duration;

+ (instancetype)player;

/// 本地filePath  http  传入阿里云oss objectKey前设置dataSource自定义下载数据
/// @param key key description
- (void)loadKey:(NSString *)key;

/// 播放
- (void)play;

/// 暂停
- (void)pause;

/// 跳转
/// @param time time description
/// @param completion completion description
- (void)seekTime:(CMTime)time completion:(void(^)(BOOL finished))completion;

@end

NS_ASSUME_NONNULL_END
