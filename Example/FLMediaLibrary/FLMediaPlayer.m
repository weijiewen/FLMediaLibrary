//
//  FLMediaPlayer.m
//  FLMediaLibrary_Example
//
//  Created by tckj on 2022/3/14.
//  Copyright © 2022 weijiwen. All rights reserved.
//

#import <AVFoundation/AVFoundation.h>
#import "FLMediaPlayer.h"

@interface FLMediaPlayer ()
@property (nonatomic, strong) AVPlayerItem *item;
@property (nonatomic, strong) AVPlayer *player;
@property (nonatomic, strong) AVPlayerLayer *playerLayer;
@property (nonatomic, strong) id timeObserver;
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
