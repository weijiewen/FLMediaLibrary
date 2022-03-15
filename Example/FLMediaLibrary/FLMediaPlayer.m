//
//  FLMediaPlayer.m
//  FLMediaLibrary_Example
//
//  Created by tckj on 2022/3/14.
//  Copyright © 2022 weijiwen. All rights reserved.
//

#import <objc/runtime.h>
#import <AVFoundation/AVFoundation.h>
#import "FLMediaPlayer.h"

static NSString *const kFLMediaPlayerScheme = @"TCKJPlay";

@interface NSURLSessionDataTask (FLMediaDownloader)
@property (nonatomic, strong) AVAssetResourceLoadingRequest *fl_loadingRequest;
@property (nonatomic, strong) NSMutableData *fl_cacheData;
@end
@implementation NSURLSessionDataTask (FLMediaDownloader)
- (void)setFl_loadingRequest:(AVAssetResourceLoadingRequest *)fl_loadingRequest {
    objc_setAssociatedObject(self, @selector(fl_loadingRequest), fl_loadingRequest, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}
- (AVAssetResourceLoadingRequest *)fl_loadingRequest {
    return objc_getAssociatedObject(self, _cmd);
}
- (void)setFl_cacheData:(NSMutableData *)fl_cacheData {
    objc_setAssociatedObject(self, @selector(fl_cacheData), fl_cacheData, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}
- (NSMutableData *)fl_cacheData {
    return objc_getAssociatedObject(self, _cmd);
}
@end


@interface FLMediaDownloadCache : NSObject
@property (nonatomic, strong) dispatch_semaphore_t fileLock;
@property (nonatomic, strong) NSURL *URL;
- (NSString *)directoryPath;
- (NSString *)listPath;
- (NSString *)dataPathWithStart:(long)start end:(long)end;
- (NSMutableArray *)list;
@end

@implementation FLMediaDownloadCache

- (void)dealloc {
    while (dispatch_semaphore_signal(self.fileLock)) {}
}

+ (instancetype)cacheWithURL:(NSURL *)URL {
    FLMediaDownloadCache *cache = FLMediaDownloadCache.alloc.init;
    cache.fileLock = dispatch_semaphore_create(1);
    cache.URL = URL;
    return cache;
}

- (NSString *)directoryPath {
    NSString *path = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject stringByAppendingPathComponent:@"FLMediaPlayerVideo"];
    NSString *base64String = [[self.URL.absoluteString dataUsingEncoding:NSUTF8StringEncoding] base64EncodedStringWithOptions:0];
    path = [path stringByAppendingPathComponent:base64String];
    BOOL isDirectory = NO;
    BOOL exists = [NSFileManager.defaultManager fileExistsAtPath:path isDirectory:&isDirectory];
    if (!exists || !isDirectory) {
        [NSFileManager.defaultManager createDirectoryAtPath:path withIntermediateDirectories:YES attributes:@{} error:nil];
    }
    return path;
}

- (NSString *)listPath {
    return [self.directoryPath stringByAppendingPathComponent:@"caches"];
}

- (NSString *)dataPathWithStart:(long)start end:(long)end {
    return [self.directoryPath stringByAppendingPathComponent:[NSString stringWithFormat:@"%ld-%ld", start, end]];
}

- (NSMutableArray *)list {
    NSMutableArray *cacheList = NSMutableArray.array;
    NSString *base64String = [NSString stringWithContentsOfFile:self.listPath encoding:NSUTF8StringEncoding error:nil];
    if (base64String.length) {
        NSData *data = [NSData.alloc initWithBase64EncodedString:base64String options:0];
        NSArray *json = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableContainers error:nil];
        if (json) {
            cacheList = json.mutableCopy;
        }
    }
    return cacheList;
}

// 1.
//新：  |-----|
//旧：     |-----|
//
//
// 2.
//新：     |-----|
//旧：  |-----|
//
//
// 3.
//新：      |-----|
//旧：  |-----|
//
//
// 4.
//新：       |----------|
//旧：  |-----|  ...  |-----|

- (void)cacheData:(NSData *)data start:(long)start {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        dispatch_semaphore_wait(self.fileLock, DISPATCH_TIME_FOREVER);
        NSMutableData *mutableData = [NSMutableData dataWithData:data];
        long end = start + mutableData.length - 1;
        NSString *dataPath = [self dataPathWithStart:start end:end];
        NSMutableArray *cacheList = self.list;
        if (!cacheList.count) {
            [mutableData writeToFile:dataPath atomically:YES];
            [cacheList addObject:NSStringFromRange(NSMakeRange(start, mutableData.length))];
            if ([NSFileManager.defaultManager fileExistsAtPath:self.listPath]) {
                [NSFileManager.defaultManager removeItemAtPath:self.listPath error:nil];
            }
            [cacheList writeToFile:self.listPath atomically:YES];
        }
        else {
            NSMutableArray *<>
        }
        dispatch_semaphore_signal(self.fileLock);
    });
}

@end


@interface FLMediaDownloader : NSObject <NSURLSessionDataDelegate>
@property (nonatomic, weak) FLMediaPlayer *player;
@property (nonatomic, strong) NSMutableDictionary <NSString *, NSURLSessionDataTask *> *tasks;
@property (nonatomic, strong) NSURLSession *session;
@end

@implementation FLMediaDownloader

+ (instancetype)downloaderWithPlayer:(FLMediaPlayer *)player {
    FLMediaDownloader *downloader = FLMediaDownloader.alloc.init;
    downloader.player = player;
    return downloader;
}

- (NSURLSession *)session {
    if (!_session) {
        NSURLSessionConfiguration *config = NSURLSessionConfiguration.defaultSessionConfiguration;
        config.networkServiceType = NSURLNetworkServiceTypeVideo;
        _session = [NSURLSession sessionWithConfiguration:config];
    }
    return _session;
}

- (void)downloadWithRequest:(AVAssetResourceLoadingRequest *)request {
    NSURL *URL = request.request.URL;
    if ([URL.absoluteString hasPrefix:kFLMediaPlayerScheme]) {
        NSString *base64String = [URL.absoluteString stringByReplacingOccurrencesOfString:[NSString stringWithFormat:@"%@://", kFLMediaPlayerScheme] withString:@""];
        NSData *data = [NSData.alloc initWithBase64EncodedString:base64String options:0];
        NSString *urlString = [NSString.alloc initWithData:data encoding:NSUTF8StringEncoding];
        URL = [NSURL URLWithString:urlString];
    }
    
    NSMutableDictionary *allHTTPHeaderFields = request.request.allHTTPHeaderFields.mutableCopy;
    NSMutableURLRequest *mutableRequest = [NSMutableURLRequest requestWithURL:URL];
    
    NSURLSessionDataTask *task = [self.session dataTaskWithRequest:mutableRequest];
    task.fl_cacheData = NSMutableData.data;
    task.fl_loadingRequest = request;
    [self.tasks setObject:task forKey:request.request.URL.absoluteString];
    [task resume];
}

- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveResponse:(NSURLResponse *)response completionHandler:(void (^)(NSURLSessionResponseDisposition))completionHandler {
    dataTask.fl_loadingRequest.response = response;
    !completionHandler ?: completionHandler(NSURLSessionResponseAllow);
}

- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveData:(NSData *)data {
    [dataTask.fl_cacheData appendData:data];
    [dataTask.fl_loadingRequest.dataRequest respondWithData:data];
}

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(nullable NSError *)error {
    if ([task isKindOfClass:NSURLSessionDataTask.class]) {
        NSURLSessionDataTask *dataTask = (NSURLSessionDataTask *)task;
        if (error) {
            [dataTask.fl_loadingRequest finishLoadingWithError:error];
        }
        else {
            [dataTask.fl_loadingRequest finishLoading];
        }
    }
}

@end

@interface FLMediaPlayer ()
@property (nonatomic, strong) AVPlayerItem *item;
@property (nonatomic, strong) AVPlayer *player;
@property (nonatomic, strong) AVPlayerLayer *playerLayer;
@property (nonatomic, strong) id timeObserver;
@end

@interface FLMediaPlayer (AVAssetResourceLoaderDelegate) <AVAssetResourceLoaderDelegate>

@end
@implementation FLMediaPlayer (AVAssetResourceLoaderDelegate)

- (BOOL)resourceLoader:(AVAssetResourceLoader *)resourceLoader shouldWaitForLoadingOfRequestedResource:(AVAssetResourceLoadingRequest *)loadingRequest {
    NSURL *URL = loadingRequest.request.URL;
    if ([URL.scheme isEqualToString:kFLMediaPlayerScheme]) {
        
    }
    return YES;
}

@end

@implementation FLMediaPlayer

- (void)dealloc {
    [self.item removeObserver:self forKeyPath:@"status"];
    if (self.timeObserver) {
        [self.player removeTimeObserver:self.timeObserver];
    }
}

+ (instancetype)player {
    return FLMediaPlayer.alloc.init;
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        self.autoPlay = YES;
    }
    return self;
}

- (void)loadItem:(AVPlayerItem *)item
{
    if (self.timeObserver && self.player) {
        [self.player removeTimeObserver:self.timeObserver];
    }
    self.item = item;
    self.player = [AVPlayer playerWithPlayerItem:self.item];
    __weak typeof(self) weak_self = self;
    self.timeObserver = [self.player addPeriodicTimeObserverForInterval:CMTimeMake(1, 1) queue:NULL usingBlock:^(CMTime time) {
        if ([weak_self.delegate respondsToSelector:@selector(playerTimeChange:currentSeconds:duration:)]) {
            [weak_self.delegate playerTimeChange:weak_self currentSeconds:CMTimeGetSeconds(weak_self.item.currentTime) duration:CMTimeGetSeconds(weak_self.item.duration)];
        }
    }];
    [self.item addObserver:self forKeyPath:@"status" options:NSKeyValueObservingOptionNew context:nil];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSKeyValueChangeKey,id> *)change context:(void *)context {
    if (object == self.item && [keyPath isEqual:@"status"]) {
        switch (self.item.status) {
            case AVPlayerItemStatusReadyToPlay: {
                if (self.autoPlay) {
                    [self.player play];
                }
            }
                break;
            default: {
                if ([self.delegate respondsToSelector:@selector(playerFailure:error:)]) {
                    [self.delegate playerFailure:self error:self.player.error];
                }
            }
                break;
        }
    }
    else {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}

- (void)play {
    [self.player play];
}

- (void)pause {
    [self.player pause];
}

- (void)seekTime:(CMTime)time completion:(void(^)(BOOL finished))completion {
    [self.player seekToTime:time completionHandler:completion];
}

@end
