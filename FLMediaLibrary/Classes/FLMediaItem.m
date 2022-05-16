//
//  AVPlayerItem+FLMediaItem.m
//  FLMediaLibrary_Example
//
//  Created by weijiewen on 2022/3/28.
//  Copyright © 2022 weijiwen. All rights reserved.
//

#import <objc/runtime.h>
#import <MobileCoreServices/MobileCoreServices.h>
#import "FLMediaItem.h"

static NSString *const kFLMediaPlayerScheme = @"TCKJPlay://";

@interface FLMediaWeakObject : NSObject
@property (nonatomic, weak) id object;
@end
@implementation FLMediaWeakObject
@end

@interface FLMediaDataCache : NSObject
+ (NSString *)directoryPath;
+ (instancetype)cacheWithURL:(NSURL *)URL;
- (void)saveResponse:(NSURLResponse *)response;
- (void)cacheData:(NSData *)data start:(NSUInteger)start;
- (void)dataWithStart:(NSUInteger)start length:(NSUInteger)length completion:(void(^)(NSURLResponse * _Nullable response, NSData * _Nullable data))completion;
- (void)deleteCache;
@end

@interface FLMediaTask : NSObject
@property (nonatomic, readonly) id <FLMediaPlayerCancel> dataTask;
+ (instancetype)taskWithDataSource:(id <FLMediaPlayerDataSource>)dataSource
                              path:(NSString *)path
                             start:(NSUInteger)start
                               end:(NSUInteger)end
                       didResponse:(void(^)(NSURLResponse *response))didResponse
                        appendData:(void(^)(NSData *data))appendData
                        completion:(void(^)(NSError *error))completion;
@end

@interface FLMediaSession : NSObject <AVAssetResourceLoaderDelegate>
@property (nonatomic, weak) FLMediaItem *playItem;
@property (nonatomic, readonly) dispatch_queue_t queue;
@end

#pragma mark --------------------------------- FLMediaItem ---------------------------------

@interface FLMediaItem () <AVAssetResourceLoaderDelegate>
@property (nonatomic, copy) NSString *originPath;
@property (nonatomic, weak) id <FLMediaPlayerDataSource> dataSource;
@property (nonatomic, strong) FLMediaSession *session;
@end
@implementation FLMediaItem

+ (NSString *)directoryPath {
    return FLMediaDataCache.directoryPath;
}

+ (NSURL *)URLFromPath:(NSString *)path {
    path = [[path dataUsingEncoding:NSUTF8StringEncoding] base64EncodedStringWithOptions:0];
    return [NSURL URLWithString:[kFLMediaPlayerScheme stringByAppendingString:path]];
}

+ (NSString *)pathFromURL:(NSURL *)URL {
    NSString *urlString = URL.absoluteString;
    if ([urlString hasPrefix:kFLMediaPlayerScheme]) {
        urlString = [urlString stringByReplacingOccurrencesOfString:kFLMediaPlayerScheme withString:@""];
        NSData *data = [NSData.alloc initWithBase64EncodedString:urlString options:0];
        return [NSString.alloc initWithData:data encoding:NSUTF8StringEncoding];
    }
    return nil;
}

+ (instancetype)mediaItemWithPath:(NSString *)path {
    return [self mediaItemWithPath:path dataSource:nil];
}

+ (instancetype)mediaItemWithPath:(NSString *)path dataSource:(nullable id<FLMediaPlayerDataSource>)dataSource {
    NSURL *URL = [FLMediaItem URLFromPath:path];
    FLMediaSession *session = FLMediaSession.alloc.init;
    AVURLAsset *asset = [AVURLAsset assetWithURL:URL];
    [asset.resourceLoader setDelegate:session queue:session.queue];
    FLMediaItem *item = [FLMediaItem playerItemWithAsset:asset];
    item.dataSource = dataSource;
    item.originPath = path;
    item.session = session;
    return item;
}

- (void)deleteCache {
    NSURL *URL = [FLMediaItem URLFromPath:self.originPath];
    FLMediaDataCache *cache = [FLMediaDataCache cacheWithURL:URL];
    [cache deleteCache];
}

- (id)copy {
    NSURL *URL = [FLMediaItem URLFromPath:self.originPath];
    FLMediaSession *session = FLMediaSession.alloc.init;
    AVURLAsset *asset = [AVURLAsset assetWithURL:URL];
    [asset.resourceLoader setDelegate:session queue:session.queue];
    FLMediaItem *item = [FLMediaItem playerItemWithAsset:asset];
    item.dataSource = self.dataSource;
    item.originPath = self.originPath;
    item.session = self.session;
    return item;
}

@end

#pragma mark --------------------------------- AVAssetResourceLoadingRequest (FLMediaTaks) ---------------------------------

@interface AVAssetResourceLoadingRequest (FLMediaTaks)
@property (nonatomic, strong) FLMediaTask *task;
@end
@implementation AVAssetResourceLoadingRequest (FLMediaTaks)
- (void)setTask:(FLMediaTask *)task {
    objc_setAssociatedObject(self, @selector(dataTask), task, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}
- (FLMediaTask *)task {
    return objc_getAssociatedObject(self, _cmd);
}
@end

#pragma mark --------------------------------- FLMediaSession ---------------------------------
@interface FLMediaSession ()
@property (nonatomic, strong) dispatch_queue_t queue;
@property (nonatomic, strong) NSPointerArray *requests;
@end
@implementation FLMediaSession

- (void)dealloc {
    [self.requests addPointer:NULL];
    [self.requests compact];
    for (AVAssetResourceLoadingRequest *request in self.requests.allObjects) {
        [request.task.dataTask cancel];
    }
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        self.queue = dispatch_queue_create("FLMediaItemQueue", NULL);
        self.requests = NSPointerArray.weakObjectsPointerArray;
    }
    return self;
}

+ (void)fillRequest:(AVAssetResourceLoadingRequest *)loadingRequest response:(NSHTTPURLResponse *)response {
    if (![response isKindOfClass:NSHTTPURLResponse.class]) {
        response = [NSHTTPURLResponse.alloc initWithURL:loadingRequest.request.URL statusCode:206 HTTPVersion:nil headerFields:nil];
    }
    NSUInteger contentLength = response.expectedContentLength;
    NSString *rangeValue = response.allHeaderFields[@"Content-Range"];
    if (rangeValue) {
        NSArray *rangeItems = [rangeValue componentsSeparatedByString:@"/"];
        if (rangeItems.count > 1) {
            contentLength = [rangeItems[1] longLongValue];
        }
    }
    CFStringRef mimeContentType = UTTypeCreatePreferredIdentifierForTag(kUTTagClassMIMEType, (__bridge CFStringRef)(response.MIMEType), NULL);
    NSString *contentType = (__bridge NSString * _Nullable)(mimeContentType);
    loadingRequest.contentInformationRequest.contentType = contentType;
    loadingRequest.contentInformationRequest.contentLength = contentLength;
    loadingRequest.contentInformationRequest.byteRangeAccessSupported = YES;
}

- (void)requetsDataWithPath:(NSString *)path loadingRequest:(AVAssetResourceLoadingRequest *)loadingRequest times:(NSInteger)times {
    FLMediaDataCache *cache = [FLMediaDataCache cacheWithURL:loadingRequest.request.URL];
    NSUInteger location = loadingRequest.dataRequest.currentOffset;
    NSUInteger length = loadingRequest.dataRequest.requestedLength;
    NSUInteger end = location + length - 1;
    __weak typeof(self) weak_self = self;
//    __weak typeof(cache) weak_cache = cache;
    [cache dataWithStart:(NSUInteger)location length:(NSUInteger)length completion:^(NSURLResponse * _Nullable response, NSData * _Nullable data) {
//        __strong typeof(weak_cache) strong_cache = weak_cache;
        if (response && data) {
            [FLMediaSession fillRequest:loadingRequest response:(NSHTTPURLResponse *)response];
            [loadingRequest.dataRequest respondWithData:data];
            if (data.length < length - (loadingRequest.dataRequest.currentOffset - loadingRequest.dataRequest.requestedOffset)) {
                [weak_self requetsDataWithPath:path loadingRequest:loadingRequest times:0];
            }
            else {
                [loadingRequest finishLoading];
            }
        }
        else {
            [weak_self.requests addPointer:(__bridge void * _Nullable)(loadingRequest)];
            loadingRequest.task = [FLMediaTask taskWithDataSource:self.playItem.dataSource path:path start:location end:end didResponse:^(NSURLResponse *response) {
                [cache saveResponse:response];
                [FLMediaSession fillRequest:loadingRequest response:(NSHTTPURLResponse *)response];
            } appendData:^(NSData *data) {
                [cache cacheData:data start:(NSUInteger)loadingRequest.dataRequest.currentOffset];
                [loadingRequest.dataRequest respondWithData:data];
            } completion:^(NSError *error) {
                if (error) {
                    if (times < 3) {
                        [weak_self requetsDataWithPath:path loadingRequest:loadingRequest times:times + 1];
                    }
                    else {
                        [loadingRequest finishLoadingWithError:error];
                    }
                }
                else {
                    [loadingRequest finishLoading];
                }
            }];
        }
    }];
}

- (BOOL)resourceLoader:(AVAssetResourceLoader *)resourceLoader shouldWaitForLoadingOfRequestedResource:(AVAssetResourceLoadingRequest *)loadingRequest {
    NSString *path = [FLMediaItem pathFromURL:loadingRequest.request.URL];
    if (!path) {
        return NO;
    }
    [self requetsDataWithPath:path loadingRequest:loadingRequest times:0];
    return YES;
}

- (void)resourceLoader:(AVAssetResourceLoader *)resourceLoader didCancelLoadingRequest:(AVAssetResourceLoadingRequest *)loadingRequest {
    [loadingRequest.task.dataTask cancel];
}

@end

#pragma mark --------------------------------- FLMediaTask ---------------------------------

@interface FLMediaTaskDelegate : NSObject <NSURLSessionDataDelegate>
@property (nonatomic, weak) FLMediaTask *task;
@end

@interface FLMediaTask ()
@property (nonatomic, strong) NSURLSession *session;
@property (nonatomic, strong) id <FLMediaPlayerCancel> dataTask;
@property (nonatomic, copy) void(^didResponse)(NSURLResponse *response);
@property (nonatomic, copy) void(^appendData)(NSData *data);
@property (nonatomic, copy) void(^completion)(NSError *error);
@end

@implementation FLMediaTaskDelegate

+ (instancetype)delegateWithTask:(FLMediaTask *)task {
    static FLMediaTaskDelegate *delegate;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        delegate = FLMediaTaskDelegate.alloc.init;
    });
    delegate.task = task;
    return delegate;
}

- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveResponse:(NSURLResponse *)response completionHandler:(void (^)(NSURLSessionResponseDisposition))completionHandler {
    !self.task.didResponse ?: self.task.didResponse(response);
    !completionHandler ?: completionHandler(NSURLSessionResponseAllow);
}

- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveData:(NSData *)data {
    !self.task.appendData ?: self.task.appendData(data);
}

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(nullable NSError *)error {
    !self.task.completion ?: self.task.completion(error);
    self.task.didResponse = nil;
    self.task.appendData = nil;
    self.task.completion = nil;
}
@end

@implementation FLMediaTask

+ (instancetype)taskWithDataSource:(id <FLMediaPlayerDataSource>)dataSource
                              path:(NSString *)path
                             start:(NSUInteger)start
                               end:(NSUInteger)end
                       didResponse:(void(^)(NSURLResponse *response))didResponse
                        appendData:(void(^)(NSData *data))appendData
                        completion:(void(^)(NSError *error))completion {
    FLMediaTask *task = FLMediaTask.alloc.init;
    if ([dataSource mediaDataWillRequestPath:path]) {
        task.dataTask = [dataSource mediaDataRequestPath:path start:start end:end didResponse:didResponse appendData:appendData completion:completion];
    }
    else {
        NSURL *URLObject = [NSURL URLWithString:path];
        if (URLObject) {
            task.didResponse = didResponse;
            task.appendData = appendData;
            task.completion = completion;
            task.session = [NSURLSession sessionWithConfiguration:NSURLSessionConfiguration.defaultSessionConfiguration delegate:[FLMediaTaskDelegate delegateWithTask:task] delegateQueue:nil];
            NSMutableURLRequest *mutableRequest = [NSMutableURLRequest requestWithURL:URLObject];
            NSString *range = [NSString stringWithFormat:@"bytes=%@-%@", [NSNumber numberWithUnsignedLongLong:start], [NSNumber numberWithUnsignedLongLong:end]];
            [mutableRequest setValue:range forHTTPHeaderField:@"Range"];
            NSURLSessionDataTask *dataTask = [task.session dataTaskWithRequest:mutableRequest];
            task.dataTask = (id <FLMediaPlayerCancel>)dataTask;
            [dataTask resume];
        }
        else {
            !completion ?: completion([NSError.alloc initWithDomain:path code:10010 userInfo:@{@"message": @"无效的URL"}]);
        }
    }
    return task;
}

@end

#pragma mark --------------------------------- FLMediaDataCache ---------------------------------

@interface FLMediaDataCache () {
    NSURLResponse *_response;
}
@property (nonatomic, strong) dispatch_semaphore_t dataLock;
@property (nonatomic, strong) NSURL *URL;
@property (nonatomic, strong) NSURLResponse *response;
+ (NSMapTable *)cachesPool;
@end

@implementation FLMediaDataCache

+ (NSMapTable *)cachesPool {
    static NSMapTable *table;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        table = [NSMapTable mapTableWithKeyOptions:NSMapTableCopyIn valueOptions:NSMapTableWeakMemory];
    });
    return table;
}

+ (instancetype)cacheWithURL:(NSURL *)URL {
    FLMediaDataCache *cache = [FLMediaDataCache.cachesPool objectForKey:URL.absoluteString];
    if (!cache) {
        cache = FLMediaDataCache.alloc.init;
        cache.dataLock = dispatch_semaphore_create(1);
        cache.URL = URL;
        [FLMediaDataCache.cachesPool setObject:cache forKey:URL.absoluteString];
    }
    return cache;
}

+ (NSString *)directoryPath {
    return [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject stringByAppendingPathComponent:@"FLMediaPlayerVideo"];
}

+ (NSString *)directoryPathWithURL:(NSURL *)URL {
    NSString *path = self.directoryPath;
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
    NSUInteger end = range.location + range.length - 1;
    return [[self directoryPathWithURL:URL] stringByAppendingPathComponent:[NSString stringWithFormat:@"%ld-%ld", (NSUInteger)range.location, end]];
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
    [NSKeyedArchiver archiveRootObject:response toFile:[FLMediaDataCache responsePathWithURL:self.URL]];
}

- (NSURLResponse *)response {
    if (!_response) {
        _response = [NSKeyedUnarchiver unarchiveObjectWithFile:[FLMediaDataCache responsePathWithURL:self.URL]];
    }
    return _response;
}

- (void)writeData:(NSMutableData *)data start:(NSUInteger)start URL:(NSURL *)URL {
    if (![data isKindOfClass:NSMutableData.class]) {
        data = data.mutableCopy;
    }
    NSMutableArray *cacheList = [FLMediaDataCache listWithURL:URL];
    for (NSInteger index = 0; index < cacheList.count; index ++ ) {
        NSRange range = NSRangeFromString(cacheList[index]);
        if (start > range.location) {
            if (start <= range.location + range.length) {
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
                    NSString *indexDataPath = [FLMediaDataCache dataPathWithURL:URL range:range];
                    NSMutableData *indexData = [NSMutableData dataWithContentsOfFile:indexDataPath];
                    [NSFileManager.defaultManager removeItemAtPath:indexDataPath error:nil];
                    if (start == range.location + range.length) {
                        [indexData appendData:data];
                    }
                    else {
                        [indexData replaceBytesInRange:NSMakeRange(start - range.location, data.length) withBytes:data.bytes];
                    }
                    data = indexData;
                    start = range.location;
                    [cacheList removeObjectAtIndex:index];
                    if (index < cacheList.count) {
                        continue;
                    }
                    else {
                        NSString *dataPath = [FLMediaDataCache dataPathWithURL:URL range:NSMakeRange(start, data.length)];
                        [data writeToFile:dataPath atomically:YES];
                        [cacheList addObject:NSStringFromRange(NSMakeRange(start, data.length))];
                        [FLMediaDataCache saveList:cacheList URL:URL];
                        return;
                    }
                }
            }
            else {
                ///新数据超出旧数据范围
                //新：            |-----|
                //旧：  |------|
                if (cacheList[index] == cacheList.lastObject) {
                    NSString *dataPath = [FLMediaDataCache dataPathWithURL:URL range:NSMakeRange(start, data.length)];
                    [data writeToFile:dataPath atomically:YES];
                    [cacheList addObject:NSStringFromRange(NSMakeRange(start, data.length))];
                    [FLMediaDataCache saveList:cacheList URL:URL];
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
                NSString *dataPath = [FLMediaDataCache dataPathWithURL:URL range:NSMakeRange(start, data.length)];
                [data writeToFile:dataPath atomically:YES];
                [cacheList insertObject:NSStringFromRange(NSMakeRange(start, data.length)) atIndex:index];
                [FLMediaDataCache saveList:cacheList URL:URL];
                return;
            }
            else {
                BOOL intersect = YES;
                while (start + data.length >= range.location + range.length) {
                    ///新数据包含旧数据
                    //新：  |----------------|
                    //旧：       |-------|
                    NSString *indexDataPath = [FLMediaDataCache dataPathWithURL:URL range:range];
                    [NSFileManager.defaultManager removeItemAtPath:indexDataPath error:nil];
                    [cacheList removeObjectAtIndex:index];
                    if (index < cacheList.count) {
                        [FLMediaDataCache saveList:cacheList URL:URL];
                        [self writeData:data start:start URL:URL];
                        return;
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
                    NSString *indexDataPath = [FLMediaDataCache dataPathWithURL:URL range:range];
                    NSData *indexData = [NSData dataWithContentsOfFile:indexDataPath];
                    [NSFileManager.defaultManager removeItemAtPath:indexDataPath error:nil];
                    [data replaceBytesInRange:NSMakeRange(range.location - start, range.length) withBytes:indexData.bytes];
                    cacheList[index] = NSStringFromRange(NSMakeRange(start, data.length));
                }
                else {
                    [cacheList addObject:NSStringFromRange(NSMakeRange(start, data.length))];
                }
                NSString *savePath = [FLMediaDataCache dataPathWithURL:URL range:NSMakeRange(start, data.length)];
                [data writeToFile:savePath atomically:YES];
                [FLMediaDataCache saveList:cacheList URL:URL];
                return;
            }
        }
    }
    NSString *dataPath = [FLMediaDataCache dataPathWithURL:URL range:NSMakeRange(start, data.length)];
    [data writeToFile:dataPath atomically:YES];
    [cacheList addObject:NSStringFromRange(NSMakeRange(start, data.length))];
    [FLMediaDataCache saveList:cacheList URL:URL];
}

- (void)saveResponse:(NSURLResponse *)response {
    self.response = response;
}

- (void)cacheData:(NSData *)data start:(NSUInteger)start {
    dispatch_semaphore_t lock = self.dataLock;
    NSURL *URL = self.URL;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        dispatch_semaphore_wait(lock, DISPATCH_TIME_FOREVER);
        [self writeData:data.mutableCopy start:start URL:URL];
        dispatch_semaphore_signal(lock);
    });
}

- (void)dataWithStart:(NSUInteger)start length:(NSUInteger)length completion:(void(^)(NSURLResponse * _Nullable response, NSData * _Nullable data))completion {
    if (self.response) {
        __weak typeof(self) weak_self = self;
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            __strong typeof(weak_self) strong_self = weak_self;
            dispatch_semaphore_wait(strong_self.dataLock, DISPATCH_TIME_FOREVER);
            NSURLResponse *response;
            NSData *data;
            NSArray *cacheList = [FLMediaDataCache listWithURL:strong_self.URL];
            for (NSString *rangeString in cacheList) {
                NSRange range = NSRangeFromString(rangeString);
                if (range.location <= start && range.location + range.length - 1 > start) {
                    NSString *path = [FLMediaDataCache dataPathWithURL:strong_self.URL range:range];
                    data = [NSData dataWithContentsOfFile:path];
                    NSUInteger subdataStart = start - range.location;
                    NSUInteger subdataLength = data.length - subdataStart > length ? length : data.length - subdataStart;
                    data = [data subdataWithRange:NSMakeRange(subdataStart, subdataLength)];
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
    else {
        !completion ?: completion(nil, nil);
    }
}

- (void)deleteCache {
    NSString *path = [FLMediaDataCache directoryPathWithURL:self.URL];
    [NSFileManager.defaultManager removeItemAtPath:path error:nil];
}

@end
