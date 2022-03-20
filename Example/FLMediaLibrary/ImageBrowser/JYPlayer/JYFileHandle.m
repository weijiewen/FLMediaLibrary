//
//  DDMediaFileHandle.m
//  gx_dxka
//
//  Created by Haoxing on 2020/9/7.
//  Copyright © 2020 haoxing. All rights reserved.
//

#import "JYFileHandle.h"

@interface JYFileHandle () {
    NSDictionary *_header;
}
@property (nonatomic, strong) NSURL *URL;
@property (nonatomic, strong) NSMutableArray <NSString *> *hasDataRanges;
@property (nonatomic, strong) dispatch_semaphore_t mediaIOLock;
@end
@implementation JYFileHandle

+ (instancetype)creatFileHandleWithURL:(NSURL *)URL {
    return [[JYFileHandle alloc] initURL:URL];
}

- (void)dealloc {
    
}

- (instancetype)initURL:(NSURL *)URL 
{
    self = [super init];
    if (self) {
        self.mediaIOLock = dispatch_semaphore_create(1);
        self.URL = URL;
        
        self.hasDataRanges = [NSMutableArray arrayWithContentsOfFile:[JYFileHandle getCacheRangePlistPathWithURL:self.URL]];
        if (!self.hasDataRanges) {
            self.hasDataRanges = [NSMutableArray array];
        }
    }
    return self;
}

- (NSMutableArray<NSString *> *)hasDataRanges {
    if (!_hasDataRanges) {
        _hasDataRanges = [NSMutableArray arrayWithContentsOfFile:[JYFileHandle getCacheRangePlistPathWithURL:self.URL]];
        if (!_hasDataRanges) {
            _hasDataRanges = [NSMutableArray array];
        }
    }
    return _hasDataRanges;
}

- (void)setHeader:(NSDictionary *)header {
    _header = header;
    NSString *headerPath = [JYFileHandle getCacheRangesHeaderWithURL:self.URL];
    if ([NSFileManager.defaultManager fileExistsAtPath:headerPath]) {
        [NSFileManager.defaultManager removeItemAtPath:headerPath error:nil];
    }
    [header writeToFile:headerPath atomically:YES];
}

- (NSDictionary *)header {
    if (!_header) {
        NSString *headerPath = [JYFileHandle getCacheRangesHeaderWithURL:self.URL];
        if ([NSFileManager.defaultManager fileExistsAtPath:headerPath]) {
            _header = [NSDictionary dictionaryWithContentsOfFile:headerPath];
        }
    }
    return _header;
}

- (long long)contentLength {
    if (_contentLength == 0) {
        NSString *rangeValue = self.header[@"Content-Range"];
        if (rangeValue) {
            NSArray *rangeItems = [rangeValue componentsSeparatedByString:@"/"];
            if (rangeItems.count > 1) {
                _contentLength = [rangeItems[1] longLongValue];
            }
        }
    }
    return _contentLength;
}

+ (NSString *)getCachePathWithURL:(NSURL *)URL {
    return [JYConfig publicVideoPathWithName:[NSString stringWithFormat:@"%@.mp4", URL.absoluteString.jy_md5]];
}

+ (NSString *)getCacheRangesPathWithURL:(NSURL *)URL {
    NSString *path = [JYConfig publicVideoPathWithName:[NSString stringWithFormat:@"/videoCachePath/%@", URL.absoluteString.jy_md5]];
    if (![NSFileManager.defaultManager fileExistsAtPath:path]) {
        [NSFileManager.defaultManager createDirectoryAtPath:path withIntermediateDirectories:true attributes:@{} error:nil];
    }
    return path;
}

+ (NSString *)getCacheRangePlistPathWithURL:(NSURL *)URL {
    NSString *path = [self getCacheRangesPathWithURL:URL];
    path = [path stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.plist", URL.absoluteString.jy_md5]];
    return path;
}



+ (NSString *)getCacheRangesHeaderWithURL:(NSURL *)URL {
    NSString *path = [self getCacheRangesPathWithURL:URL];
    path = [path stringByAppendingPathComponent:[NSString stringWithFormat:@"%@_h", URL.absoluteString.jy_md5]];
    return path;
}

+ (NSString *)getCacheRangesPathWithURL:(NSURL *)URL location:(long)location length:(long)length {
    NSString *path = [self getCacheRangesPathWithURL:URL];
    path = [path stringByAppendingPathComponent:[NSString stringWithFormat:@"%@-%ld-%ld", URL.absoluteString.jy_md5, location, length]];
    return path;
}


- (void)readWithLocation:(long)location length:(long)length finish:(void(^)(NSData *data))finish {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        dispatch_semaphore_wait(self.mediaIOLock, DISPATCH_TIME_FOREVER);
        dispatch_async(dispatch_get_main_queue(), ^{
            if (!self.hasDataRanges.count) {
                !finish ?: finish(nil);
                dispatch_semaphore_signal(self.mediaIOLock);
                return;
            }
            else {
                NSArray *ranges = self.hasDataRanges;
                dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                    NSData *data;
                    for (NSInteger i = 0; i < ranges.count; i ++) {
                        NSRange range = NSRangeFromString(ranges[i]);
                        if (range.location <= location && range.location + range.length >= location + length) {
                            data = [NSData dataWithContentsOfFile:[JYFileHandle getCacheRangesPathWithURL:self.URL location:range.location length:range.length]];
                            data = [data subdataWithRange:NSMakeRange(location - range.location, length)];
                            break;
                        }
                    }
                    dispatch_async(dispatch_get_main_queue(), ^{
                        !finish ?: finish(data);
                        dispatch_semaphore_signal(self.mediaIOLock);
                    });
                });
            }
        });
    });
}

- (void)insertLocation:(long)location data:(NSData *)data index:(NSInteger)index {
    NSRange dataRange = NSMakeRange(location, data.length);
    NSString *cachePath = [JYFileHandle getCacheRangesPathWithURL:self.URL location:location length:data.length];
    [data writeToFile:cachePath atomically:true];
    if (index < self.hasDataRanges.count) {
        [self.hasDataRanges insertObject:NSStringFromRange(dataRange) atIndex:index];
    }
    else {
        [self.hasDataRanges addObject:NSStringFromRange(dataRange)];
    }
    [self.hasDataRanges writeToFile:[JYFileHandle getCacheRangePlistPathWithURL:self.URL] atomically:true];
}

- (void)mergeLocation:(long)location data:(NSData *)data currentIndex:(NSInteger)currentIndex otherRange:(NSRange)otherRange {
    NSString *otherPath = [JYFileHandle getCacheRangesPathWithURL:self.URL location:otherRange.location length:otherRange.length];
    NSData *otherData = [NSData dataWithContentsOfFile:otherPath];
    if (!otherData) {
        [NSFileManager.defaultManager removeItemAtPath:[JYFileHandle getCacheRangesPathWithURL:self.URL] error:nil];
        return;
    }
    NSMutableData *mergeData = [NSMutableData data];
    if (location > otherRange.location) {
        [mergeData appendData:otherData];
        [mergeData replaceBytesInRange:NSMakeRange(location - otherRange.location, data.length) withBytes:data.bytes];
        if (self.hasDataRanges.count < currentIndex) {
            [self.hasDataRanges removeObjectAtIndex:currentIndex];
        }
        location = otherRange.location;
    }
    else {
        [mergeData appendData:data];
        if (location + data.length < otherRange.location + otherRange.length) {
            [mergeData replaceBytesInRange:NSMakeRange(otherRange.location - location, otherRange.length) withBytes:otherData.bytes];
        }
        if (currentIndex < self.hasDataRanges.count) {
            [self.hasDataRanges removeObjectAtIndex:currentIndex];
        }
    }
    [NSFileManager.defaultManager removeItemAtPath:otherPath error:nil];
    while (true) {
        if (currentIndex + 1 >= self.hasDataRanges.count) {
            break;
        }
        NSString *rangeString = self.hasDataRanges[currentIndex + 1];
        if (!rangeString || !rangeString.length) {
            break;
        }
        NSRange nextRange = NSRangeFromString(rangeString);
        if (location + mergeData.length < nextRange.location) {
            break;
        }
        NSString *nextPath = [JYFileHandle getCacheRangesPathWithURL:self.URL location:nextRange.location length:nextRange.length];
        NSData *nextData = [NSData dataWithContentsOfFile:nextPath];
        if (location + mergeData.length < nextRange.location + nextRange.length) {
            [mergeData replaceBytesInRange:NSMakeRange(nextRange.location - location, nextRange.length) withBytes:nextData.bytes];
        }
        NSInteger removeIndex = currentIndex + 1;
        if (removeIndex < self.hasDataRanges.count) {
            [self.hasDataRanges removeObjectAtIndex:removeIndex];
        }
        [NSFileManager.defaultManager removeItemAtPath:nextPath error:nil];
    }
    [self insertLocation:location data:mergeData index:currentIndex];
}

- (void)writeData:(NSData *)data Location:(long)location {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        dispatch_semaphore_wait(self.mediaIOLock, DISPATCH_TIME_FOREVER);
        NSArray *ranges = self.hasDataRanges;
        if (!ranges.count) {
            [self insertLocation:location data:data index:0];
            dispatch_semaphore_signal(self.mediaIOLock);
            return;
        }
        for (NSInteger i = 0; i < ranges.count; i ++) {
            NSRange range = NSRangeFromString(ranges[i]);
            if (location + data.length < range.location) {
                [self insertLocation:location data:data index:i];
                [self finishCache];
                dispatch_semaphore_signal(self.mediaIOLock);
                return;
            }
            if (location <= range.location + range.length) {
                [self mergeLocation:location data:data currentIndex:i otherRange:range];
                [self finishCache];
                dispatch_semaphore_signal(self.mediaIOLock);
                return;
            }
            else {
                if (i + 1 < ranges.count) {
                    NSRange nextRange = NSRangeFromString(ranges[i + 1]);
                    if (location < nextRange.location) {
                        if (location + data.length < nextRange.location) {
                            [self insertLocation:location data:data index:i + 1];
                        }
                        else {
                            [self mergeLocation:location data:data currentIndex:i + 1 otherRange:nextRange];
                        }
                        break;
                    }
                    else if (location <= nextRange.location + nextRange.length) {
                        [self mergeLocation:location data:data currentIndex:i + 1 otherRange:nextRange];
                        break;
                    }
                }
                else {
                    [self insertLocation:location data:data index:i + 1];
                }
            }
        }
        [self finishCache];
        dispatch_semaphore_signal(self.mediaIOLock);
    });
}

- (void)finishCache {
    if (self.hasDataRanges.count == 1 && NSRangeFromString(self.hasDataRanges.firstObject).location == 0 && NSRangeFromString(self.hasDataRanges.firstObject).length == self.contentLength) {
        NSRange range = NSRangeFromString(self.hasDataRanges.firstObject);
        NSData *data = [NSData dataWithContentsOfFile:[JYFileHandle getCacheRangesPathWithURL:self.URL location:range.location length:range.length]];
        NSString *savePath = [JYFileHandle getCachePathWithURL:self.URL];
        [data writeToFile:savePath atomically:true];
        [NSFileManager.defaultManager removeItemAtPath:[JYFileHandle getCacheRangesPathWithURL:self.URL] error:nil];
        self.hasDataRanges = nil;
    }
}

@end
