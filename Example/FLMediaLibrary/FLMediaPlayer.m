//
//  FLMediaPlayer.m
//  FLMediaLibrary_Example
//
//  Created by tckj on 2022/3/14.
//  Copyright © 2022 weijiwen. All rights reserved.
//

#import <objc/runtime.h>
#import <AVFoundation/AVFoundation.h>
#import <MobileCoreServices/MobileCoreServices.h>
#import "FLMediaPlayer.h"

@interface FLMediaDownloadCache : NSObject {
    NSURLResponse *_response;
}
@property (nonatomic, strong) dispatch_semaphore_t dataLock;
@property (nonatomic, strong) NSURL *URL;
@property (nonatomic, strong) NSURLResponse *response;
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
        cache.dataLock = dispatch_semaphore_create(1);
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

+ (NSString *)responsePathWithURL:(NSURL *)URL {
    return [[self directoryPathWithURL:URL] stringByAppendingPathComponent:@"response"];
}

- (void)setResponse:(NSURLResponse *)response {
    [NSKeyedArchiver archiveRootObject:response toFile:[FLMediaDownloadCache responsePathWithURL:self.URL]];
}

- (NSURLResponse *)response {
    if (!_response) {
        _response = [NSKeyedUnarchiver unarchiveObjectWithFile:[FLMediaDownloadCache responsePathWithURL:self.URL]];
    }
    return _response;
}

- (void)writeData:(NSMutableData *)data start:(long)start URL:(NSURL *)URL {
    if (![data isKindOfClass:NSMutableData.class]) {
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
        dispatch_semaphore_wait(strong_self.dataLock, DISPATCH_TIME_FOREVER);
        [strong_self writeData:data.mutableCopy start:start URL:strong_self.URL];
        dispatch_semaphore_signal(strong_self.dataLock);
    });
}

- (void)dataWithStart:(long)start length:(long)length completion:(void(^)(NSURLResponse * _Nullable response, NSData * _Nullable data))completion {
    __weak typeof(self) weak_self = self;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        __strong typeof(weak_self) strong_self = weak_self;
        dispatch_semaphore_wait(strong_self.dataLock, DISPATCH_TIME_FOREVER);
        NSURLResponse *response;
        NSData *data;
        NSArray *cacheList = [FLMediaDownloadCache listWithURL:strong_self.URL];
        for (NSString *rangeString in cacheList) {
            NSRange range = NSRangeFromString(rangeString);
            if (range.location <= start && range.location + range.length >= start + length) {
                NSString *dataPath = [FLMediaDownloadCache dataPathWithURL:strong_self.URL range:range];
                data = [[NSData dataWithContentsOfFile:dataPath] subdataWithRange:NSMakeRange(start - range.location, length)];
                response = strong_self.response;
                break;
            }
        }
        dispatch_semaphore_signal(strong_self.dataLock);
        dispatch_async(dispatch_get_main_queue(), ^{
            !completion ?: completion(response, data);
        });
    });
}

@end

@interface FLMediaWeakObject : NSObject
@property (nonatomic, weak) id object;
@end
@implementation FLMediaWeakObject
@end

@interface NSURLSessionDataTask (FLMediaDownloader)
@property (nonatomic, strong) AVAssetResourceLoadingRequest *fl_loadingRequest;
@end
@implementation NSURLSessionDataTask (FLMediaDownloader)
- (void)setFl_loadingRequest:(AVAssetResourceLoadingRequest *)fl_loadingRequest {
    objc_setAssociatedObject(self, @selector(fl_loadingRequest), fl_loadingRequest, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}
- (AVAssetResourceLoadingRequest *)fl_loadingRequest {
    return objc_getAssociatedObject(self, _cmd);
}
@end

static NSString *const kFLMediaPlayerScheme = @"TCKJPlay://";

@interface FLMediaDownloader : NSObject <NSURLSessionDataDelegate>
@property (nonatomic, weak) FLMediaPlayer *player;
@property (nonatomic, strong) FLMediaDownloadCache *cache;
@property (nonatomic, strong) NSMutableDictionary <NSString *, NSURLSessionDataTask *> *tasks;
@property (nonatomic, strong) NSMutableArray <AVAssetResourceLoadingRequest *> *requests;
@property (nonatomic, strong) NSURLSession *session;
@end

@implementation FLMediaDownloader

- (void)dealloc {
    NSArray *keys = self.tasks.allKeys;
    for (NSString *key in keys) {
        [self.tasks[key] cancel];
    }
    for (AVAssetResourceLoadingRequest *request in self.requests) {
        if ([self.player.dataSource respondsToSelector:@selector(playerCancelRequest:identifier:)]) {
            [self.player.dataSource playerCancelRequest:self.player identifier:[self identifierFromRequest:request]];
        }
    }
    [self.requests removeAllObjects];
}

+ (instancetype)downloaderWithPlayer:(FLMediaPlayer *)player {
    FLMediaDownloader *downloader = FLMediaDownloader.alloc.init;
    downloader.tasks = NSMutableDictionary.dictionary;
    downloader.requests = NSMutableArray.array;
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

- (NSString *)identifierFromRequest:(AVAssetResourceLoadingRequest *)request {
    NSString *string = [NSString stringWithFormat:@"%@_%ld_%ld", request.request.URL.absoluteString, (long)request.dataRequest.requestedOffset, (long)request.dataRequest.requestedLength];
    NSData *data = [string dataUsingEncoding:NSUTF8StringEncoding];
    return [data base64EncodedStringWithOptions:0];
}

- (NSURL *)URLFromKey:(NSString *)key {
    key = [[key dataUsingEncoding:NSUTF8StringEncoding] base64EncodedStringWithOptions:0];
    return [NSURL URLWithString:[kFLMediaPlayerScheme stringByAppendingString:key]];
}

- (NSString *)keyFromURL:(NSURL *)URL {
    NSString *urlString = URL.absoluteString;
    if ([urlString hasPrefix:kFLMediaPlayerScheme]) {
        urlString = [urlString stringByReplacingOccurrencesOfString:kFLMediaPlayerScheme withString:@""];
        NSData *data = [NSData.alloc initWithBase64EncodedString:urlString options:0];
        return [NSString.alloc initWithData:data encoding:NSUTF8StringEncoding];
    }
    return nil;
}

- (BOOL)downloadWithRequest:(AVAssetResourceLoadingRequest *)request {
    NSString *key = [self keyFromURL:request.request.URL];
    if (!key) {
        return NO;
    }
    if (!self.cache) {
        self.cache = [FLMediaDownloadCache cacheWithURL:request.request.URL];
    }
    long long location = (long long)request.dataRequest.requestedOffset;
    long long length = (long long)request.dataRequest.requestedLength;
    long long end = location + length - 1;
    __weak typeof(self) weak_self = self;
    [self.cache dataWithStart:(long)location length:(long)length completion:^(NSURLResponse * _Nullable response, NSData * _Nullable data) {
        if (weak_self) {
            if (response && data) {
                if (!request.response) {
                    request.response = response;
                }
                [request.dataRequest respondWithData:data];
                [request finishLoading];
            }
            else {
                if ([weak_self.player.dataSource respondsToSelector:@selector(playerIsCustom:key:)]) {
                    [weak_self.requests addObject:request];
                    [weak_self.player.dataSource playerWillRequest:weak_self.player identifier:[weak_self identifierFromRequest:request] key:key start:location end:end response:^(NSURLResponse * _Nonnull response) {
                        weak_self.cache.response = response;
                        request.response = response;
                        CFStringRef mimeContentType = UTTypeCreatePreferredIdentifierForTag(kUTTagClassMIMEType, (__bridge CFStringRef)(response.MIMEType), NULL);
                        request.contentInformationRequest.contentType = (__bridge NSString * _Nullable)(mimeContentType);
                        request.contentInformationRequest.contentLength = response.expectedContentLength;
                        request.contentInformationRequest.byteRangeAccessSupported = YES;
                    } appendData:^(NSData * _Nonnull data) {
                        [weak_self.cache writeData:data.mutableCopy start:(long)request.dataRequest.currentOffset URL:request.request.URL];
                        [request.dataRequest respondWithData:data];
                    } completion:^(NSError * _Nonnull error) {
                        [weak_self.requests removeObject:request];
                        if (error) {
                            [request finishLoadingWithError:error];
                        }
                        else {
                            [request finishLoading];
                        }
                    }];
                }
                else if ([key hasPrefix:@"http"]) {
                    NSMutableURLRequest *mutableRequest = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:key]];
                    mutableRequest.allHTTPHeaderFields = request.request.allHTTPHeaderFields;
                    NSString *range = [NSString stringWithFormat:@"bytes=%lld-%lld", location, end];
                    [mutableRequest setValue:range forHTTPHeaderField:@"Range"];
                    
                    NSURLSessionDataTask *task = [weak_self.session dataTaskWithRequest:mutableRequest];
                    task.fl_loadingRequest = request;
                    [weak_self.tasks setObject:task forKey:[weak_self identifierFromRequest:request]];
                    [task resume];
                }
                else {
                    [request finishLoadingWithError:[NSError.alloc initWithDomain:key code:404 userInfo:@{@"message": @"地址无法解析"}]];
                }
            }
        }
    }];
    return YES;
}

- (void)cancelRequest:(AVAssetResourceLoadingRequest *)request {
    NSString *identifier = [self identifierFromRequest:request];
    if (self.tasks[identifier]) {
        self.tasks[identifier].fl_loadingRequest = nil;
        [self.tasks[identifier] cancel];
        [self.tasks removeObjectForKey:identifier];
    }
    else if ([self.player.dataSource respondsToSelector:@selector(playerCancelRequest:identifier:)]) {
        [self.player.dataSource playerCancelRequest:self.player identifier:identifier];
    }
}

- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveResponse:(NSURLResponse *)response completionHandler:(void (^)(NSURLSessionResponseDisposition))completionHandler {
    self.cache.response = response;
    dataTask.fl_loadingRequest.response = response;
    CFStringRef mimeContentType = UTTypeCreatePreferredIdentifierForTag(kUTTagClassMIMEType, (__bridge CFStringRef)(response.MIMEType), NULL);
    dataTask.fl_loadingRequest.contentInformationRequest.contentType = (__bridge NSString * _Nullable)(mimeContentType);
    dataTask.fl_loadingRequest.contentInformationRequest.contentLength = response.expectedContentLength;
    dataTask.fl_loadingRequest.contentInformationRequest.byteRangeAccessSupported = YES;
    !completionHandler ?: completionHandler(NSURLSessionResponseAllow);
}

- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveData:(NSData *)data {
    [self.cache writeData:data.mutableCopy start:(long)dataTask.fl_loadingRequest.dataRequest.currentOffset URL:dataTask.fl_loadingRequest.request.URL];
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
        [self.tasks removeObjectForKey:[self identifierFromRequest:dataTask.fl_loadingRequest]];
    }
}

@end

@interface FLMediaPlayer ()
@property (nonatomic, assign) BOOL isPause;
@property (nonatomic, strong) AVPlayerItem *item;
@property (nonatomic, strong) AVPlayer *player;
@property (nonatomic, strong) AVPlayerLayer *playerLayer;
@property (nonatomic, strong) id timeObserver;
@property (nonatomic, strong) FLMediaDownloader *downloader;
@property (nonatomic, strong) NSDate *stopDate;
@property (nonatomic, assign) NSTimeInterval stopTimeInterval;
@end

@interface FLMediaPlayer (AVAssetResourceLoaderDelegate) <AVAssetResourceLoaderDelegate>

@end
@implementation FLMediaPlayer (AVAssetResourceLoaderDelegate)

- (BOOL)resourceLoader:(AVAssetResourceLoader *)resourceLoader shouldWaitForLoadingOfRequestedResource:(AVAssetResourceLoadingRequest *)loadingRequest {
    return [self.downloader downloadWithRequest:loadingRequest];
}

@end

@implementation FLMediaPlayer

- (void)dealloc {
    [self.item removeObserver:self forKeyPath:@"status"];
    [self.item removeObserver:self forKeyPath:@"loadedTimeRanges"];
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
        self.isPause = YES;
        self.downloader = [FLMediaDownloader downloaderWithPlayer:self];
    }
    return self;
}

- (void)loadKey:(NSString *)key {
    if ([NSFileManager.defaultManager fileExistsAtPath:key]) {
        [self loadItem:[AVPlayerItem playerItemWithURL:[NSURL fileURLWithPath:key]]];
    }
    else {
        AVURLAsset *asset = [AVURLAsset assetWithURL:[self.downloader URLFromKey:key]];
        [asset.resourceLoader setDelegate:self queue:dispatch_get_main_queue()];
        [self loadItem:[AVPlayerItem playerItemWithAsset:asset]];
    }
}

- (void)loadItem:(AVPlayerItem *)item
{
    if (self.timeObserver && self.player) {
        [self.player removeTimeObserver:self.timeObserver];
    }
    [self.item removeObserver:self forKeyPath:@"status"];
    [self.item removeObserver:self forKeyPath:@"loadedTimeRanges"];
    self.item = item;
    self.player = [AVPlayer playerWithPlayerItem:self.item];
    self.player.automaticallyWaitsToMinimizeStalling = NO;
    __weak typeof(self) weak_self = self;
    self.timeObserver = [self.player addPeriodicTimeObserverForInterval:CMTimeMake(1, 2) queue:NULL usingBlock:^(CMTime time) {
        if (!weak_self.isPause) {
            NSTimeInterval seconds = CMTimeGetSeconds(weak_self.item.currentTime);
            NSTimeInterval duration = CMTimeGetSeconds(weak_self.item.duration);
            if (seconds == duration &&
                duration != 0) {
                if (weak_self.loop) {
                    [weak_self seekTime:kCMTimeZero completion:^(BOOL finished) {
                        [weak_self play];
                    }];
                }
                else if ([weak_self.delegate respondsToSelector:@selector(playerFinish:)]) {
                    [weak_self.delegate playerFinish:weak_self];
                }
            }
            else if (seconds == weak_self.stopTimeInterval &&
                weak_self.stopDate &&
                NSDate.date.timeIntervalSince1970 - weak_self.stopDate.timeIntervalSince1970 > 1.f) {
                if ([weak_self.delegate respondsToSelector:@selector(playerLoadData:)]) {
                    [weak_self.delegate playerLoadData:weak_self];
                }
            }
            else {
                if ((!weak_self.stopDate ||
                    NSDate.date.timeIntervalSince1970 - weak_self.stopDate.timeIntervalSince1970 > 1.f) &&
                    [weak_self.delegate respondsToSelector:@selector(playerPlaying:)]) {
                    [weak_self.delegate playerPlaying:weak_self];
                }
                weak_self.stopTimeInterval = seconds;
                weak_self.stopDate = NSDate.date;
                if ([weak_self.delegate respondsToSelector:@selector(playerTimeChange:currentSeconds:duration:)]) {
                    [weak_self.delegate playerTimeChange:weak_self currentSeconds:seconds duration:duration];
                }
            }
        }
    }];
    [self.item addObserver:self forKeyPath:@"status" options:NSKeyValueObservingOptionNew context:nil];
    [self.item addObserver:self forKeyPath:@"loadedTimeRanges" options:NSKeyValueObservingOptionNew context:nil];
    if ([self.delegate respondsToSelector:@selector(playerLoadData:)]) {
        [self.delegate playerLoadData:self];
    }
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSKeyValueChangeKey,id> *)change context:(void *)context {
    if (object == self.item && [keyPath isEqual:@"status"]) {
        switch (self.item.status) {
            case AVPlayerItemStatusReadyToPlay: {
                if (self.autoPlay) {
                    [self play];
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
    else if ([keyPath isEqualToString:@"loadedTimeRanges"]) {
        
        NSArray *loadedTimeRanges       = [self.player.currentItem loadedTimeRanges];
        CMTimeRange timeRange           = [loadedTimeRanges.firstObject CMTimeRangeValue];// 获取缓冲区域
        NSTimeInterval startSeconds     = CMTimeGetSeconds(timeRange.start);
        NSTimeInterval durationSeconds  = CMTimeGetSeconds(timeRange.duration);
        NSTimeInterval timeInterval     = startSeconds + durationSeconds;// 计算缓冲总进度
        
        if ([self.delegate respondsToSelector:@selector(playerCacheRangeChange:cacheSeconds:duration:)]) {
            [self.delegate playerCacheRangeChange:self cacheSeconds:timeInterval duration:CMTimeGetSeconds(self.duration)];
        }
    }
    else {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}

- (void)play {
    self.isPause = NO;
    self.stopDate = NSDate.date;
    self.stopTimeInterval = CMTimeGetSeconds(self.player.currentTime);
    [self.player play];
}

- (void)pause {
    self.isPause = YES;
    [self.player pause];
}

- (void)seekTime:(CMTime)time completion:(void(^)(BOOL finished))completion {
    self.stopDate = nil;
    self.stopTimeInterval = 0;
    [self.player seekToTime:time completionHandler:completion];
}

@end
