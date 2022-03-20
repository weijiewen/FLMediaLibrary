//
//  DDMediaFileHandle.h
//  gx_dxka
//
//  Created by Haoxing on 2020/9/7.
//  Copyright © 2020 haoxing. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface JYFileHandle : NSObject

@property (nonatomic, assign) long long contentLength;

@property (nonatomic, copy) NSDictionary *header;

+ (instancetype)creatFileHandleWithURL:(NSURL *)URL;

+ (NSString *)getCachePathWithURL:(NSURL *)URL;

+ (NSString *)getCacheRangesPathWithURL:(NSURL *)URL;

- (void)readWithLocation:(long)location length:(long)length finish:(void(^)(NSData *data))finish;

- (void)writeData:(NSData *)data Location:(long)locaiton;

@end

NS_ASSUME_NONNULL_END
