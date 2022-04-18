//
//  AVPlayerItem+FLMediaItem.h
//  FLMediaLibrary_Example
//
//  Created by weijiewen on 2022/3/28.
//  Copyright © 2022 weijiwen. All rights reserved.
//

#import <AVFoundation/AVFoundation.h>

NS_ASSUME_NONNULL_BEGIN

@protocol FLMediaPlayerCancel <NSObject>
@required
- (void)cancel;
@end

@protocol FLMediaPlayerDataSource <NSObject>
@required

/// 自己处理下载返回YES，返回NO 使用内部NSURLSessionDataTask http下载
/// @param path 原传入的path
- (BOOL)mediaDataWillRequestPath:(NSString *)path;

/// 播放器需要视频数据
/// @param path 原传入的path
/// @param start 开始下标
/// @param end 结束下标
/// @param appendData 填充数据
/// @param completion 请求失败或成功
- (id <FLMediaPlayerCancel>)mediaDataRequestPath:(NSString *)path
                                          start:(long long)start
                                            end:(long long)end
                                    didResponse:(void(^)(NSURLResponse *response))didResponse
                                     appendData:(void(^)(NSData *data))appendData
                                     completion:(void(^)(NSError *error))completion;
@end


@interface FLMediaItem : AVPlayerItem
+ (instancetype)mediaItemWithPath:(NSString *)path;
+ (instancetype)mediaItemWithPath:(NSString *)path dataSource:(nullable id<FLMediaPlayerDataSource>)dataSource;
+ (NSString *)directoryPath;
@end

NS_ASSUME_NONNULL_END
