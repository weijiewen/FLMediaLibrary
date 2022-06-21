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

@interface FLMediaDataCache : NSObject
+ (instancetype)cacheWithURL:(NSURL *)URL;
- (void)saveResponse:(NSURLResponse *)response;
- (void)cacheData:(NSData *)data start:(NSUInteger)start;
- (void)dataWithStart:(NSUInteger)start length:(NSUInteger)length completion:(void(^)(NSURLResponse * _Nullable response, NSData * _Nullable data))completion;
- (void)deleteCache;
@end

@interface FLMediaSession : NSObject <AVAssetResourceLoaderDelegate>
@property (nonatomic, readonly) dispatch_queue_t queue;
@property (nonatomic, readonly) FLMediaDataCache *cache;
- (instancetype)initWithURL:(NSURL *)URL dataSource:(nullable id<FLMediaPlayerDataSource>)dataSource;
@end

#pragma mark --------------------------------- FLMediaItem ---------------------------------

@interface FLMediaItem () <AVAssetResourceLoaderDelegate>
@property (nonatomic, copy) NSString *originPath;
@property (nonatomic, strong) FLMediaSession *session;
+ (NSString *)directoryPath;
@end
@implementation FLMediaItem

+ (instancetype)mediaItemWithPath:(NSString *)path {
    return [self mediaItemWithPath:path dataSource:nil];
}

+ (instancetype)mediaItemWithPath:(NSString *)path dataSource:(nullable id<FLMediaPlayerDataSource>)dataSource {
    NSURL *URL = [FLMediaItem URLFromPath:path];
    FLMediaSession *session = [FLMediaSession.alloc initWithURL:URL dataSource:dataSource];
    AVURLAsset *asset = [AVURLAsset assetWithURL:URL];
    [asset.resourceLoader setDelegate:session queue:session.queue];
    FLMediaItem *item = [FLMediaItem playerItemWithAsset:asset];
    item.originPath = path;
    item.session = session;
    return item;
}

- (void)deleteCache {
    NSURL *URL = [FLMediaItem URLFromPath:self.originPath];
    FLMediaDataCache *cache = [FLMediaDataCache cacheWithURL:URL];
    [self.session.cache deleteCache];
}

- (id)copy {
    NSURL *URL = [FLMediaItem URLFromPath:self.originPath];
    AVURLAsset *asset = [AVURLAsset assetWithURL:URL];
    [asset.resourceLoader setDelegate:self.session queue:self.session.queue];
    FLMediaItem *item = [FLMediaItem playerItemWithAsset:asset];
    item.originPath = self.originPath;
    item.session = self.session;
    return item;
}

+ (NSString *)directoryPath {
    return [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject stringByAppendingPathComponent:@"FLMediaPlayerVideo"];
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

@end

@interface FLMediaTask : NSObject
@property (nonatomic, readonly) NSMutableData *downloadData;
- (id <FLMediaPlayerCancel>)downloadWithDataSource:(id <FLMediaPlayerDataSource>)dataSource
                                              path:(NSString *)path
                                             start:(NSUInteger)start
                                               end:(NSUInteger)end
                                       didResponse:(void(^)(NSURLResponse *response))didResponse
                                        appendData:(void(^)(NSData *data))appendData
                                        completion:(void(^)(NSData *downloadData, NSError *error, BOOL isCancel))completion;
- (void)cancel;
@end

#pragma mark --------------------------------- AVAssetResourceLoadingRequest (FLMediaTaks) ---------------------------------

@interface AVAssetResourceLoadingRequest (FLMediaTaks)
@property (nonatomic, strong) FLMediaTask *task;
@end

@implementation AVAssetResourceLoadingRequest (FLMediaTaks)
- (void)setTask:(FLMediaTask *)task {
    objc_setAssociatedObject(self, @selector(task), task, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}
- (FLMediaTask *)task {
    return objc_getAssociatedObject(self, _cmd);
}
@end

#pragma mark --------------------------------- FLMediaSession ---------------------------------

@interface FLMediaSession () <NSURLSessionDelegate>
@property (nonatomic, weak) id<FLMediaPlayerDataSource> dataSource;
@property (nonatomic, strong) dispatch_queue_t queue;
@property (nonatomic, strong) NSURLSession *urlSession;
@property (nonatomic, strong) NSMapTable *requestTable;
@property (nonatomic, strong) FLMediaDataCache *cache;
@end
@implementation FLMediaSession

- (void)dealloc {
    NSArray *keys = self.requestTable.keyEnumerator.allObjects;
    for (id <FLMediaPlayerCancel> dataTask in keys) {
        AVAssetResourceLoadingRequest *request = [self.requestTable objectForKey:dataTask];
        [request finishLoading];
        [request.task cancel];
    }
}

- (instancetype)initWithURL:(NSURL *)URL dataSource:(nullable id<FLMediaPlayerDataSource>)dataSource
{
    self = [super init];
    if (self) {
        self.dataSource = dataSource;
        self.queue = dispatch_queue_create("com.wjw.FLMediaSession", NULL);
        self.requestTable = NSMapTable.weakToWeakObjectsMapTable;
        self.cache = [FLMediaDataCache cacheWithURL:URL];
    }
    return self;
}

- (void)requetsDataWithPath:(NSString *)path loadingRequest:(AVAssetResourceLoadingRequest *)loadingRequest {
    long location = loadingRequest.dataRequest.currentOffset;
    long length = loadingRequest.dataRequest.requestedLength;
    long end = location + length - 1;
    __weak typeof(self) weak_self = self;
    [self.cache dataWithStart:(NSUInteger)location length:(NSUInteger)length completion:^(NSURLResponse * _Nullable response, NSData * _Nullable data) {
        if (weak_self && !loadingRequest.isCancelled && !loadingRequest.isFinished) {
            if (response && data) {
                [FLMediaSession fillRequest:loadingRequest response:(NSHTTPURLResponse *)response];
                [loadingRequest.dataRequest respondWithData:data];
                if (data.length < length - (loadingRequest.dataRequest.currentOffset - loadingRequest.dataRequest.requestedOffset)) {
                    [weak_self requetsDataWithPath:path loadingRequest:loadingRequest];
                }
                else {
                    [loadingRequest finishLoading];
                }
            }
            else {
                FLMediaTask *task = FLMediaTask.alloc.init;
                loadingRequest.task = task;
                id <FLMediaPlayerCancel> dataTask = [task downloadWithDataSource:weak_self.dataSource path:path start:location end:end didResponse:^(NSURLResponse *response) {
                    [weak_self.cache saveResponse:response];
                    [FLMediaSession fillRequest:loadingRequest response:(NSHTTPURLResponse *)response];
                } appendData:^(NSData *data) {
                    [loadingRequest.dataRequest respondWithData:data];
                } completion:^(NSData *downloadData, NSError *error, BOOL isCancel) {
                    if (downloadData.length) {
                        [weak_self.cache cacheData:downloadData start:location];
                    }
                    if (!isCancel) {
                        if (error) {
                            [weak_self requetsDataWithPath:path loadingRequest:loadingRequest];
                        }
                        else {
                            [loadingRequest finishLoading];
                        }
                    }
                }];
                [weak_self.requestTable setObject:loadingRequest forKey:dataTask];
            }
        }
    }];
}

- (BOOL)resourceLoader:(AVAssetResourceLoader *)resourceLoader shouldWaitForLoadingOfRequestedResource:(AVAssetResourceLoadingRequest *)loadingRequest {
    NSString *path = [FLMediaItem pathFromURL:loadingRequest.request.URL];
    if (!path) {
        return NO;
    }
    [self requetsDataWithPath:path loadingRequest:loadingRequest];
    return YES;
}

- (void)resourceLoader:(AVAssetResourceLoader *)resourceLoader didCancelLoadingRequest:(AVAssetResourceLoadingRequest *)loadingRequest {
    [loadingRequest.task cancel];
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

@end

#pragma mark --------------------------------- FLMediaTask ---------------------------------
@interface FLMediaDownloadManager : NSObject
+ (instancetype)manager;
- (id <FLMediaPlayerDataSource>)taskWithPath:(NSString *)path
                                       start:(NSUInteger)start
                                         end:(NSUInteger)end
                                 didResponse:(void(^)(NSURLResponse *response))didResponse
                                  appendData:(void(^)(NSData *data))appendData
                                  completion:(void(^)(NSError *error))completion;
@end

@interface FLMediaTask ()
@property (nonatomic, strong) NSMutableData *downloadData;
@property (nonatomic, strong) id <FLMediaPlayerCancel> dataTask;
@end
@implementation FLMediaTask

- (id <FLMediaPlayerCancel>)downloadWithDataSource:(id <FLMediaPlayerDataSource>)dataSource
                                              path:(NSString *)path
                                             start:(NSUInteger)start
                                               end:(NSUInteger)end
                                       didResponse:(void(^)(NSURLResponse *response))didResponse
                                        appendData:(void(^)(NSData *data))appendData
                                        completion:(void(^)(NSData *downloadData, NSError *error, BOOL isCancel))completion {
    __weak typeof(self) weak_self = self;
    if ([dataSource mediaDataWillRequestPath:path]) {
        self.dataTask = [dataSource mediaDataRequestPath:path start:start end:end didResponse:^(NSURLResponse * _Nonnull response) {
            !didResponse ?: didResponse(response);
        } appendData:^(NSData * _Nonnull data) {
            [weak_self.downloadData appendData:data];
            !appendData ?: appendData(data);
        } completion:^(NSError * _Nonnull error, BOOL isCancel) {
            !completion ?: completion(weak_self.downloadData, error, isCancel);
        }];
    }
    else {
        self.dataTask = [FLMediaDownloadManager.manager taskWithPath:path start:start end:end didResponse:^(NSURLResponse *response) {
            !didResponse ?: didResponse(response);
        } appendData:^(NSData *data) {
            [weak_self.downloadData appendData:data];
            !appendData ?: appendData(data);
        } completion:^(NSError *error) {
            !completion ?: completion(weak_self.downloadData, error, error.code == NSURLErrorCancelled);
        }];
    }
    return self.dataTask;
}

- (NSMutableData *)downloadData {
    if (!_downloadData) {
        _downloadData = NSMutableData.data;
    }
    return _downloadData;
}

- (void)cancel {
    [self.dataTask cancel];
}

@end

#pragma mark --------------------------------- FLMediaDataCache ---------------------------------

@interface FLMediaDataCache () {
    NSURLResponse *_response;
}
@property (nonatomic, strong) dispatch_semaphore_t dataLock;
@property (nonatomic, strong) NSURL *URL;
@property (nonatomic, strong) NSURLResponse *response;
@property (nonatomic, strong) dispatch_queue_t dataQueue;
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
        cache = [FLMediaDataCache.alloc initWithURL:URL];
        [FLMediaDataCache.cachesPool setObject:cache forKey:URL.absoluteString];
    }
    return cache;
}

- (instancetype)initWithURL:(NSURL *)URL
{
    self = [super init];
    if (self) {
        self.dataQueue = dispatch_queue_create("com.wjw.FLMediaCacheDataQuque", NULL);
        self.dataLock = dispatch_semaphore_create(1);
        self.URL = URL;
    }
    return self;
}

+ (NSString *)directoryPathWithURL:(NSURL *)URL {
    NSString *path = FLMediaItem.directoryPath;
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

- (NSArray *)writeData:(NSData *)data start:(NSUInteger)start URL:(NSURL *)URL {
    if (![data isKindOfClass:NSMutableData.class]) {
        data = data.mutableCopy;
    }
    NSMutableArray *cacheList = [FLMediaDataCache listWithURL:URL];
    NSInteger index = 0;
    NSMutableArray *removeDataPaths = NSMutableArray.array;
    while (index < cacheList.count) {
        NSRange range = NSRangeFromString(cacheList[index]);
        if (start >= range.location) {
            if (start <= range.location + range.length) {
                if (start + data.length <= range.location + range.length) {
                    //      | -------- |
                    // | ----------------- |
                    return removeDataPaths;
                }
                else {
                    //      | -------- |
                    // | -------- |
                    [cacheList removeObjectAtIndex:index];
                    NSString *indexDataPath = [FLMediaDataCache dataPathWithURL:self.URL range:range];
                    [removeDataPaths addObject:indexDataPath];
                    NSData *indexData = [NSData dataWithContentsOfFile:indexDataPath];
                    NSMutableData *replaceData = [indexData subdataWithRange:NSMakeRange(0, start - range.location)].mutableCopy;
                    [replaceData appendData:data];
                    data = replaceData.copy;
                    start = range.location;
                }
            }
            index += 1;
        }
        else {
            if (start + data.length < range.location) {
                // | -------- |
                //               | -------- |
                NSString *dataPath = [FLMediaDataCache dataPathWithURL:URL range:NSMakeRange(start, data.length)];
                [data writeToFile:dataPath atomically:YES];
                if (index == cacheList.count - 1) {
                    [cacheList addObject:NSStringFromRange(NSMakeRange(start, data.length))];
                }
                else {
                    [cacheList insertObject:NSStringFromRange(NSMakeRange(start, data.length)) atIndex:index];
                }
                [FLMediaDataCache saveList:cacheList URL:URL];
                NSLog(@"写入数据 %@", NSStringFromRange(NSMakeRange(start, data.length)));
                return removeDataPaths;
            }
            else if (start + data.length <= range.location + range.length) {
                // | -------- |
                //        | -------- |
                NSString *indexDataPath = [FLMediaDataCache dataPathWithURL:self.URL range:range];
                [removeDataPaths addObject:indexDataPath];
                NSData *indexData = [NSData dataWithContentsOfFile:indexDataPath];
                NSMutableData *replaceData = [data subdataWithRange:NSMakeRange(0, range.location - start)].mutableCopy;
                [replaceData appendData:indexData];
                data = replaceData.copy;
                NSString *dataPath = [FLMediaDataCache dataPathWithURL:URL range:NSMakeRange(start, data.length)];
                [data writeToFile:dataPath atomically:YES];
                cacheList[index] = NSStringFromRange(NSMakeRange(start, data.length));
                [FLMediaDataCache saveList:cacheList URL:URL];
                NSLog(@"写入数据 %@", NSStringFromRange(NSMakeRange(start, data.length)));
                return removeDataPaths;
            }
            else {
                // | ----------------- |
                //      | -------- |
                NSString *indexDataPath = [FLMediaDataCache dataPathWithURL:self.URL range:range];
                [removeDataPaths addObject:indexDataPath];
                [cacheList removeObjectAtIndex:index];
            }
        }
    }
    NSString *dataPath = [FLMediaDataCache dataPathWithURL:URL range:NSMakeRange(start, data.length)];
    [data writeToFile:dataPath atomically:YES];
    if (index >= cacheList.count) {
        [cacheList addObject:NSStringFromRange(NSMakeRange(start, data.length))];
    }
    else {
        [cacheList insertObject:NSStringFromRange(NSMakeRange(start, data.length)) atIndex:index];
    }
    NSLog(@"写入数据 %@", NSStringFromRange(NSMakeRange(start, data.length)));
    [FLMediaDataCache saveList:cacheList URL:URL];
    return removeDataPaths;
}

- (void)saveResponse:(NSURLResponse *)response {
    self.response = response;
}

- (void)cacheData:(NSData *)data start:(NSUInteger)start {
    dispatch_semaphore_t lock = self.dataLock;
    NSURL *URL = self.URL;
    dispatch_async(self.dataQueue, ^{
        dispatch_semaphore_wait(lock, DISPATCH_TIME_FOREVER);
        NSArray *removeDataPaths = [self writeData:data start:start URL:URL];
        for (NSString *removeDataPath in removeDataPaths) {
            [NSFileManager.defaultManager removeItemAtPath:removeDataPath error:nil];
        }
        dispatch_semaphore_signal(lock);
    });
}

- (void)dataWithStart:(NSUInteger)start length:(NSUInteger)length completion:(void(^)(NSURLResponse * _Nullable response, NSData * _Nullable data))completion {
    if (self.response) {
        __weak typeof(self) weak_self = self;
        
        dispatch_async(self.dataQueue, ^{
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

@interface FLMediaDownloadBlock : NSObject
@property (nonatomic, copy) void(^didResponse)(NSURLResponse *response);
@property (nonatomic, copy) void(^appendData)(NSData *data);
@property (nonatomic, copy) void(^completion)(NSError *error);
@end
@implementation FLMediaDownloadBlock
@end
@interface FLMediaDownloadManager () <NSURLSessionDelegate>
@property (nonatomic, strong) NSURLSession *session;
@property (nonatomic, strong) NSMapTable *taskMap;
@end

@implementation FLMediaDownloadManager

+ (instancetype)manager {
    static FLMediaDownloadManager *manager;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        manager = FLMediaDownloadManager.alloc.init;
        manager.session = [NSURLSession sessionWithConfiguration:NSURLSessionConfiguration.defaultSessionConfiguration delegate:manager delegateQueue:nil];
        manager.taskMap = NSMapTable.strongToStrongObjectsMapTable;
    });
    return manager;
}

- (id <FLMediaPlayerDataSource>)taskWithPath:(NSString *)path
                                       start:(NSUInteger)start
                                         end:(NSUInteger)end
                                 didResponse:(void(^)(NSURLResponse *response))didResponse
                                  appendData:(void(^)(NSData *data))appendData
                                  completion:(void(^)(NSError *error))completion {
    FLMediaDownloadBlock *block = FLMediaDownloadBlock.alloc.init;
    block.didResponse = didResponse;
    block.appendData = appendData;
    block.completion = completion;
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:path]];
    NSString *range = [NSString stringWithFormat:@"bytes=%@-%@", [NSNumber numberWithUnsignedLongLong:start], [NSNumber numberWithUnsignedLongLong:end]];
    [request setValue:range forHTTPHeaderField:@"Range"];
    NSURLSessionDataTask *dataTask = [self.session dataTaskWithRequest:request];
    [self.taskMap setObject:block forKey:dataTask];
    [dataTask resume];
    return dataTask;
}

- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveResponse:(NSURLResponse *)response completionHandler:(void (^)(NSURLSessionResponseDisposition))completionHandler {
    FLMediaDownloadBlock *block = [self.taskMap objectForKey:dataTask];
    !block.didResponse ?: block.didResponse(response);
    !completionHandler ?: completionHandler(NSURLSessionResponseAllow);
}

- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveData:(NSData *)data {
    FLMediaDownloadBlock *block = [self.taskMap objectForKey:dataTask];
    block.appendData(data);
}

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(nullable NSError *)error {
    FLMediaDownloadBlock *block = [self.taskMap objectForKey:task];
    block.completion(error);
    [self.taskMap removeObjectForKey:task];
}

@end
