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

@interface FLMediaDownloadCache : NSObject
@property (nonatomic, strong) dispatch_semaphore_t writeDataLock;
@property (nonatomic, strong) NSURL *URL;
+ (NSMapTable *)cachesPool;
@end

@implementation FLMediaDownloadCache

+ (NSMapTable *)cachesPool {
    static NSMapTable *table;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        table = [NSMapTable mapTableWithKeyOptions:NSMapTableCopyIn valueOptions:NSMapTableWeakMemory];
    });
    return table;
}

+ (instancetype)cacheWithURL:(NSURL *)URL {
    FLMediaDownloadCache *cache = [FLMediaDownloadCache.cachesPool objectForKey:URL.absoluteString];
    if (!cache) {
        cache = FLMediaDownloadCache.alloc.init;
        cache.writeDataLock = dispatch_semaphore_create(1);
        cache.URL = URL;
        [FLMediaDownloadCache.cachesPool setObject:cache forKey:URL.absoluteString];
    }
    return cache;
}

+ (NSString *)directoryPathWithURL:(NSURL *)URL {
    NSString *path = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject stringByAppendingPathComponent:@"FLMediaPlayerVideo"];
    NSString *base64String = [[URL.absoluteString dataUsingEncoding:NSUTF8StringEncoding] base64EncodedStringWithOptions:0];
    path = [path stringByAppendingPathComponent:base64String];
    BOOL isDirectory = NO;
    BOOL exists = [NSFileManager.defaultManager fileExistsAtPath:path isDirectory:&isDirectory];
    if (!exists || !isDirectory) {
        [NSFileManager.defaultManager createDirectoryAtPath:path withIntermediateDirectories:YES attributes:@{} error:nil];
    }
    return path;
}

+ (NSString *)dataPathWithURL:(NSURL *)URL range:(NSRange)range {
    long end = range.location + range.length - 1;
    return [[self directoryPathWithURL:URL] stringByAppendingPathComponent:[NSString stringWithFormat:@"%ld-%ld", (long)range.location, end]];
}

+ (NSMutableArray *)listWithURL:(NSURL *)URL {
    NSString *listPath = [[self directoryPathWithURL:URL] stringByAppendingPathComponent:@"caches"];
    NSMutableArray *cacheList = NSMutableArray.array;
    NSData *base64Data = [NSData dataWithContentsOfFile:listPath];
    if (base64Data.length) {
        NSData *data = [NSData.alloc initWithBase64EncodedData:base64Data options:0];
        NSArray *json = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableContainers error:nil];
        if (json) {
            cacheList = json.mutableCopy;
        }
    }
    return cacheList;
}

+ (void)saveList:(NSArray *)list URL:(NSURL *)URL {
    NSString *listPath = [[self directoryPathWithURL:URL] stringByAppendingPathComponent:@"caches"];
    if ([NSFileManager.defaultManager fileExistsAtPath:listPath]) {
        [NSFileManager.defaultManager removeItemAtPath:listPath error:nil];
    }
    [[[NSJSONSerialization dataWithJSONObject:list options:NSJSONWritingFragmentsAllowed error:nil] base64EncodedDataWithOptions:0] writeToFile:listPath atomically:YES];
}

- (void)writeData:(NSMutableData *)data start:(long)start URL:(NSURL *)URL {
    if ([data isKindOfClass:NSMutableData.class]) {
        data = data.mutableCopy;
    }
    NSMutableArray *cacheList = [FLMediaDownloadCache listWithURL:URL];
    NSInteger index = 0;
    while (index < cacheList.count) {
        NSRange range = NSRangeFromString(cacheList[index]);
        if (start > range.location) {
            if (start < range.location + range.length) {
                if (start + data.length <= range.location + range.length) {
                    ///新数据被包含
                    //新：    |-----|
                    //旧：  |-----------|
                    return;
                }
                else {
                    ///新数据前部相交旧数据后部
                    //新：      |--------|
                    //旧：  |------|
                    NSString *indexDataPath = [FLMediaDownloadCache dataPathWithURL:URL range:range];
                    NSMutableData *indexData = [NSMutableData dataWithContentsOfFile:indexDataPath];
                    [NSFileManager.defaultManager removeItemAtPath:indexDataPath error:nil];
                    [indexData replaceBytesInRange:NSMakeRange(start - range.location, data.length) withBytes:data.bytes];
                    data = indexData;
                    start = range.location;
                    [cacheList removeObjectAtIndex:index];
                    if (index < cacheList.count) {
                        continue;
                    }
                    else {
                        NSString *dataPath = [FLMediaDownloadCache dataPathWithURL:URL range:NSMakeRange(start, data.length)];
                        [data writeToFile:dataPath atomically:YES];
                        [cacheList addObject:NSStringFromRange(NSMakeRange(start, data.length))];
                        [FLMediaDownloadCache saveList:cacheList URL:URL];
                        return;
                    }
                }
            }
            else {
                ///新数据超出旧数据范围
                //新：            |-----|
                //旧：  |------|
                if (cacheList[index] == cacheList.lastObject) {
                    NSString *dataPath = [FLMediaDownloadCache dataPathWithURL:URL range:NSMakeRange(start, data.length)];
                    [data writeToFile:dataPath atomically:YES];
                    [cacheList addObject:NSStringFromRange(NSMakeRange(start, data.length))];
                    [FLMediaDownloadCache saveList:cacheList URL:URL];
                    return;
                }
                else {
                    continue;
                }
            }
        }
        else {
            if (start + data.length < range.location) {
                ///新数据在前
                //新：  |-----|
                //旧：            |-----|
                NSString *dataPath = [FLMediaDownloadCache dataPathWithURL:URL range:NSMakeRange(start, data.length)];
                [data writeToFile:dataPath atomically:YES];
                [cacheList insertObject:NSStringFromRange(NSMakeRange(start, data.length)) atIndex:index];
                [FLMediaDownloadCache saveList:cacheList URL:URL];
                return;
            }
            else {
                BOOL intersect = YES;
                while (start + data.length >= range.location + range.length) {
                    ///新数据包含旧数据
                    //新：  |----------------|
                    //旧：       |-------|
                    NSString *indexDataPath = [FLMediaDownloadCache dataPathWithURL:URL range:range];
                    [NSFileManager.defaultManager removeItemAtPath:indexDataPath error:nil];
                    [cacheList removeObjectAtIndex:index];
                    if (index < cacheList.count) {
                        range = NSRangeFromString(cacheList[index]);
                    }
                    else {
                        intersect = NO;
                        break;
                    }
                }
                if (intersect) {
                    ///新数据相交旧数据前部
                    //新：  |--------|
                    //旧：       |-------|
                    NSString *indexDataPath = [FLMediaDownloadCache dataPathWithURL:URL range:range];
                    NSData *indexData = [NSData dataWithContentsOfFile:indexDataPath];
                    [NSFileManager.defaultManager removeItemAtPath:indexDataPath error:nil];
                    [data replaceBytesInRange:NSMakeRange(range.location - start, range.length) withBytes:indexData.bytes];
                    cacheList[index] = NSStringFromRange(NSMakeRange(start, data.length));
                }
                else {
                    [cacheList addObject:NSStringFromRange(NSMakeRange(start, data.length))];
                }
                NSString *savePath = [FLMediaDownloadCache dataPathWithURL:URL range:NSMakeRange(start, data.length)];
                [data writeToFile:savePath atomically:YES];
                [FLMediaDownloadCache saveList:cacheList URL:URL];
                return;
            }
        }
        index += 1;
    }
    NSString *dataPath = [FLMediaDownloadCache dataPathWithURL:URL range:NSMakeRange(start, data.length)];
    [data writeToFile:dataPath atomically:YES];
    [cacheList addObject:NSStringFromRange(NSMakeRange(start, data.length))];
    [FLMediaDownloadCache saveList:cacheList URL:URL];
}

- (void)cacheData:(NSData *)data start:(long)start {
    __weak typeof(self) weak_self = self;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        __strong typeof(weak_self) strong_self = weak_self;
        dispatch_semaphore_wait(strong_self.writeDataLock, DISPATCH_TIME_FOREVER);
        [strong_self writeData:data.mutableCopy start:start URL:strong_self.URL];
        dispatch_semaphore_signal(strong_self.writeDataLock);
    });
}

@end

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

static NSString *const kFLMediaPlayerScheme = @"TCKJPlay";

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
