//
//  JYPlayer.m
//  gx_dxka
//
//  Created by Haoxing on 2020/9/4.
//  Copyright © 2020 haoxing. All rights reserved.
//

#import <MobileCoreServices/MobileCoreServices.h>
#import "JYPlayer.h"
#import "JYFileHandle.h"

static NSString * const JYCutsomURLScheme = @"JYPlayer";

@interface JYPlayerAssetDelegate : NSObject <AVAssetResourceLoaderDelegate, NSURLSessionDataDelegate>
@property (nonatomic, strong) NSMutableDictionary <NSURL *, JYFileHandle *> *dataFileHandles;
+ (instancetype)delegate;
@end

@implementation JYPlayerAssetDelegate

+ (instancetype)delegate {
    static JYPlayerAssetDelegate *delegate;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        delegate = JYPlayerAssetDelegate.alloc.init;
    });
    return delegate;
}

+ (NSString *)encodeObjectKey:(NSString *)objectKey {
    return [NSString stringWithFormat:@"%@://%@", JYCutsomURLScheme, [objectKey dataUsingEncoding:NSUTF8StringEncoding].jy_base64Encode];
}

+ (void)decodeWithURL:(NSURL *)URL completion:(void(^)(NSString *objectKey))completion {
    NSString *string = URL.absoluteString;
    string = URL.host;
    completion([NSString.alloc initWithData:string.jy_base64Decode encoding:NSUTF8StringEncoding]);
}

+ (void)load {
    if (![NSUserDefaults.standardUserDefaults boolForKey:@"JY_DID_CLEAR_MEDIA_CACHE_RANGE"]) {
        [NSUserDefaults.standardUserDefaults setBool:true forKey:@"JY_DID_CLEAR_MEDIA_CACHE_RANGE"];
        NSString *path = [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES).firstObject stringByAppendingFormat:@"/mt_mediaCache/mt_mediaPathCache"];
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            [NSFileManager.defaultManager removeItemAtPath:path error:nil];
        });
    }
}

- (BOOL)resourceLoader:(AVAssetResourceLoader *)resourceLoader shouldWaitForLoadingOfRequestedResource:(AVAssetResourceLoadingRequest *)loadingRequest {
    NSURL *URL = loadingRequest.request.URL;
    if ([URL.absoluteString hasPrefix:JYCutsomURLScheme]) {
        if (!self.dataFileHandles) {
            self.dataFileHandles = NSMutableDictionary.dictionary;
        }
        if (!self.dataFileHandles[URL]) {
            self.dataFileHandles[URL] = [JYFileHandle creatFileHandleWithURL:URL];
        }
        long location = (long)loadingRequest.dataRequest.requestedOffset;
        long length = (long)loadingRequest.dataRequest.requestedLength;

        [self.dataFileHandles[URL] readWithLocation:location length:length finish:^(NSData * _Nonnull data) {
            if (data && self.dataFileHandles[URL].header) {
                [self fillRequest:loadingRequest header:self.dataFileHandles[URL].header];
                [loadingRequest.dataRequest respondWithData:data];
                
                [loadingRequest finishLoading];
            }
            else {
                [self requestWithResource:loadingRequest location:location length:length];
            }
        }];
        return true;
    }
    return false;
}

- (void)resourceLoader:(AVAssetResourceLoader *)resourceLoader didCancelLoadingRequest:(AVAssetResourceLoadingRequest *)loadingRequest {
    
}

- (void)requestWithResource:(AVAssetResourceLoadingRequest *)loadingRequest location:(long)location length:(long)length {
    NSURL *URL = loadingRequest.request.URL;
    [JYPlayerAssetDelegate decodeWithURL:URL completion:^(NSString *objectKey) {
        long long fromOffset = location;
        long long endOffset = location + length - 1;
        if (self.dataFileHandles[URL].header) {
            [self fillRequest:loadingRequest header:self.dataFileHandles[URL].header];
        }
        NSMutableData *currentData = NSMutableData.data;
        JYFileHandle *dataFileHandle = self.dataFileHandles[URL];
        if (dataFileHandle.header) {
            [self fillRequest:loadingRequest header:dataFileHandle.header];
        }
        [JYIM.fileSession downloadDataWithType:JYFileTypeVideo path:objectKey startOffset:fromOffset endOffset:endOffset recieveData:^(NSData * _Nonnull data) {
            if (dataFileHandle.header && data.length) {
                [loadingRequest.dataRequest respondWithData:data];
            }
            [currentData appendData:data];
        } completion:^(NSError * _Nullable error, NSInteger httpCode, NSDictionary * _Nullable httpResponseHeaders) {
            if (error) {
                [loadingRequest finishLoadingWithError:error];
            }
            else {
                if (!dataFileHandle.header) {
                    dataFileHandle.header = httpResponseHeaders;
                    [self fillRequest:loadingRequest header:httpResponseHeaders];
                    [loadingRequest.dataRequest respondWithData:currentData];
                }
                [loadingRequest finishLoading];
                [dataFileHandle writeData:currentData Location:location];
            }
        }];
    }];
}

- (void)fillRequest:(AVAssetResourceLoadingRequest *)loadingRequest header:(NSDictionary *)header {
    NSHTTPURLResponse *response = [NSHTTPURLResponse.alloc initWithURL:[NSURL URLWithString:[JYCutsomURLScheme stringByAppendingFormat:@"//%@.mp4", loadingRequest.request.URL.host]] statusCode:206 HTTPVersion:nil headerFields:header];
    unsigned long long contentLength = response.expectedContentLength;
    
    NSString *rangeValue = header[@"Content-Range"];
    if (rangeValue) {
        NSArray *rangeItems = [rangeValue componentsSeparatedByString:@"/"];
        if (rangeItems.count > 1) {
            contentLength = [rangeItems[1] longLongValue];
        } else {
            contentLength = [response expectedContentLength];
        }
    }
    CFStringRef mimeContentType = UTTypeCreatePreferredIdentifierForTag(kUTTagClassMIMEType, (__bridge CFStringRef)(response.MIMEType), NULL);
    loadingRequest.contentInformationRequest.contentType = (__bridge NSString * _Nullable)(mimeContentType);
    loadingRequest.contentInformationRequest.contentLength = contentLength;
    loadingRequest.contentInformationRequest.byteRangeAccessSupported = YES;
}

@end


@interface JYPlayer ()
@property (nonatomic, strong) AVPlayerItem *item;
@property (nonatomic, strong) AVPlayer *player;
@property (nonatomic, strong) NSURL *URL;
@property (nonatomic, weak) id <JYPlayerDelegate> delegate;
@property (nonatomic, assign) BOOL isPlaying;
@property (nonatomic, assign) CMTime beforeTime;
@property (nonatomic, assign) NSInteger catonFlag;
@property (nonatomic, assign) NSTimeInterval bufferTimestamp;
@property (nonatomic, strong) dispatch_source_t timer;
@property (nonatomic, strong) AVPlayerLayer *playerLayer;
@end

@implementation JYPlayer

- (void)dealloc {
    [self.player.currentItem removeObserver:self forKeyPath:@"status"];
    [self.player.currentItem removeObserver:self forKeyPath:@"loadedTimeRanges"];
    if (self.timer) {
        dispatch_cancel(self.timer);
        self.timer = nil;
    }
    [NSNotificationCenter.defaultCenter removeObserver:self];
    [self.player pause];
}

- (instancetype)initWithObjectKey:(NSString *)objectKey {
    return [self initWithObjectKey:objectKey delegate:nil];
}

- (instancetype)initWithObjectKey:(NSString *)objectKey delegate:(id <JYPlayerDelegate>)delegate {
    NSURL *URL = [NSURL URLWithString:[JYPlayerAssetDelegate encodeObjectKey:objectKey]];
    NSString *cachePath = [JYFileHandle getCachePathWithURL:URL];
    AVURLAsset *loadAsset;
    if ([NSFileManager.defaultManager fileExistsAtPath:cachePath]) {
        URL = [NSURL fileURLWithPath:cachePath];
        loadAsset = [AVURLAsset assetWithURL:URL];
    }
    else {
        loadAsset = [AVURLAsset assetWithURL:URL];
        [loadAsset.resourceLoader setDelegate:JYPlayerAssetDelegate.delegate queue:dispatch_get_main_queue()];
    }
    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(action_playEnd:) name:AVPlayerItemDidPlayToEndTimeNotification object:nil];
    AVPlayerItem *playerItem = [AVPlayerItem playerItemWithAsset:loadAsset];
    JYPlayer *player = [self initWithItem:playerItem delegate:delegate];
    player.URL = URL;
    return player;
}

- (instancetype)initWithItem:(AVPlayerItem *)item delegate:(id <JYPlayerDelegate>)delegate {
    self = [super init];
    if (self) {
        self.item = item;
        item.canUseNetworkResourcesForLiveStreamingWhilePaused = YES;
        item.preferredForwardBufferDuration = 5;
        [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(action_playEnd:) name:AVPlayerItemDidPlayToEndTimeNotification object:nil];
        self.delegate = delegate;
        [item addObserver:self forKeyPath:@"status" options:NSKeyValueObservingOptionNew context:nil];
        [item addObserver:self forKeyPath:@"loadedTimeRanges" options:NSKeyValueObservingOptionNew context:nil];
        self.player = [[AVPlayer alloc] initWithPlayerItem:item];
        if (@available(iOS 10.0, *)) {
            self.player.automaticallyWaitsToMinimizeStalling = NO;
        }
        __weak typeof(self) weak_self = self;
        if ([self.delegate respondsToSelector:@selector(mediaPlayerStartLoading)]) {
            [self.delegate mediaPlayerStartLoading];
        }
        self.timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, dispatch_get_main_queue());
        dispatch_source_set_timer(self.timer, dispatch_time(DISPATCH_TIME_NOW, 0.1 * NSEC_PER_SEC), 0.1 * NSEC_PER_SEC, 0 * NSEC_PER_SEC);
        dispatch_source_set_event_handler(self.timer, ^{
            if (weak_self) {
                CMTime time = weak_self.player.currentTime;
                if (CMTIME_IS_INVALID(time) || CMTIME_IS_INVALID(weak_self.beforeTime) || CMTimeGetSeconds(time) == CMTimeGetSeconds(weak_self.beforeTime)) {
                    if (weak_self.bufferTimestamp == 0) {
                        weak_self.bufferTimestamp = NSDate.date.timeIntervalSince1970;
                    }
                    else if (NSDate.date.timeIntervalSince1970 - weak_self.bufferTimestamp > 2 && weak_self.isPlaying) {
                        weak_self.bufferTimestamp = 0;
                        [weak_self.player play];
                    }
                    if (weak_self.isPlaying && [weak_self.delegate respondsToSelector:@selector(mediaPlayerStartLoading)]) {
                        [weak_self.delegate mediaPlayerStartLoading];
                    }
                }
                else {
                    weak_self.bufferTimestamp = 0;
                    if (weak_self.isPlaying && [weak_self.delegate respondsToSelector:@selector(mediaPlayerStopLoading)]) {
                        [weak_self.delegate mediaPlayerStopLoading];
                    }
                    if (weak_self.isPlaying && CMTIME_IS_VALID(weak_self.player.currentItem.duration) && [weak_self.delegate respondsToSelector:@selector(mediaPlayerProgress:)]) {
                        [weak_self.delegate mediaPlayerProgress:CMTimeGetSeconds(time) / CMTimeGetSeconds(weak_self.player.currentItem.duration)];
                    }
                }
                weak_self.beforeTime = time;
            }
        });
        dispatch_resume(self.timer);
    }
    return self;
}

- (AVPlayerLayer *)creatPlayerLayer {
    if (!self.playerLayer) {
        self.playerLayer = [AVPlayerLayer playerLayerWithPlayer:self.player];
    }
    return self.playerLayer;
}

- (void)setVolume:(CGFloat)volume {
    self.player.volume = volume;
}

- (CGFloat)volume {
    return self.player.volume;
}

- (void)play {
    if (!self.isPlaying) {
        [self.player play];
        self.isPlaying = YES;
    }
}

- (void)pause {
    if (self.isPlaying) {
        [self.player pause];
        self.isPlaying = NO;
    }
}

- (void)seekToTime:(CMTime)time completionHandler:(void(^)(BOOL finished))completionHandler {
    if (completionHandler) {
        [self.player seekToTime:time completionHandler:completionHandler];
    }
    else {
        [self.player seekToTime:time];
    }

}

- (AVPlayerStatus)status {
    return self.player.status;
}

- (CMTime)currentTime {
    return self.player.currentItem.currentTime;
}

- (CMTime)duration {
    return self.player.currentItem.duration;
}

- (AVAsset *)asset {
    return self.player.currentItem.asset;
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSKeyValueChangeKey,id> *)change context:(void *)context {
    if (object == self.player.currentItem) {
        if ([keyPath isEqualToString:@"status"]) {
            AVPlayerStatus status = [[change objectForKey:NSKeyValueChangeNewKey] integerValue];
            if (status == AVPlayerStatusFailed && self.URL && [self.URL.scheme isEqualToString:@"file"]) {
                if ([self.delegate respondsToSelector:@selector(mediaPlayerReloadItem)]) {
                    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                        [NSFileManager.defaultManager removeItemAtPath:[JYFileHandle getCachePathWithURL:self.URL] error:nil];
                        dispatch_async(dispatch_get_main_queue(), ^{
                            [self.delegate mediaPlayerReloadItem];
                        });
                    });
                }
            }
            else {
                if (self.player.currentItem.error) {
                    NSLog(@"播放失败: %@", self.player.currentItem.error);
                }
                if ([self.delegate respondsToSelector:@selector(mediaPlayerStatusChange:)]) {
                    [self.delegate mediaPlayerStatusChange:status];
                }
            }
        }
        else if ([keyPath isEqualToString:@"loadedTimeRanges"]) {
            
            NSArray *loadedTimeRanges       = [self.player.currentItem loadedTimeRanges];
            CMTimeRange timeRange           = [loadedTimeRanges.firstObject CMTimeRangeValue];// 获取缓冲区域
            NSTimeInterval startSeconds     = CMTimeGetSeconds(timeRange.start);
            NSTimeInterval durationSeconds  = CMTimeGetSeconds(timeRange.duration);
            NSTimeInterval timeInterval     = startSeconds + durationSeconds;// 计算缓冲总进度
            
            if ([self.delegate respondsToSelector:@selector(mediaPlayerLoadedTimeChange:)]) {
                [self.delegate mediaPlayerLoadedTimeChange:timeInterval];
            }
        }
    }
}

- (void)action_playEnd:(NSNotification *)sender {
    if (sender.object == self.player.currentItem) {
        self.isPlaying = NO;
        if ([self.delegate respondsToSelector:@selector(mediaPlayerDidEnd)]) {
            [self.delegate mediaPlayerDidEnd];
        }
    }
}

@end
