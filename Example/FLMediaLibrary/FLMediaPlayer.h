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

/// 调用pause时执行回调该方法
- (void)playerPause:(FLMediaPlayer *)player;

/// 播放结束，如果loop为YES 该方法不会回调
- (void)playerFinish:(FLMediaPlayer *)player;

/// 播放失败
- (void)playerFailure:(FLMediaPlayer *)player error:(NSError *)error;

/// 播放时间改变，播放中每秒调用一次
- (void)playerTimeChange:(FLMediaPlayer *)player currentSeconds:(NSInteger)currentSeconds duration:(NSInteger)duration;
@end

@protocol FLMediaPlayerDataSource <NSObject>
@optional

/// 播放器需要请求视频数据
/// @param player player description
/// @param request request description
/// @param response 收到返回的response后调用该block
/// @param appendData 收到数据调用该block追加数据
/// @param finish 本次请求结束
- (void)playerWillRequest:(FLMediaPlayer *)player
                  request:(NSURLRequest *)request
                 response:(void(^)(NSURLResponse *response))response
               appendData:(void(^)(NSData *data))appendData
                   finish:(dispatch_block_t)finish;

/// 播放器已取消请求
/// @param player player description
/// @param request request description
- (void)playerCancelRequest:(FLMediaPlayer *)player
                    request:(NSURLRequest *)request;
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

@end

NS_ASSUME_NONNULL_END
