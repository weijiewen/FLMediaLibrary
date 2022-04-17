//
//  FLMediaPlayer.m
//  FLMediaLibrary_Example
//
//  Created by tckj on 2022/3/14.
//  Copyright © 2022 weijiwen. All rights reserved.
//

#import "FLMediaPlayer.h"

@interface FLMediaPlayView ()
@property (nonatomic, strong) AVPlayerLayer *playerLayer;
@end

#pragma mark --------------------------------- FLMediaPlayer ---------------------------------

@interface FLMediaPlayer ()
@property (nonatomic, weak) id <FLMediaPlayerDelegate> delegate;
@property (nonatomic, assign) BOOL isPause;
@property (nonatomic, assign) BOOL isLoading;
@property (nonatomic, assign) NSTimeInterval duration;
@property (nonatomic, strong) FLMediaPlayView *playView;
@property (nonatomic, strong) AVPlayerItem *item;
@property (nonatomic, strong) AVPlayer *player;
@property (nonatomic, strong) AVPlayerLayer *playerLayer;
@property (nonatomic, strong) id timeObserver;
@property (nonatomic, strong) NSDate *stopDate;
@property (nonatomic, assign) NSTimeInterval stopTimeInterval;
@end

@implementation FLMediaPlayer

- (void)dealloc {
    [self.playView removeFromSuperview];
    [self.item removeObserver:self forKeyPath:@"status"];
    [self.item removeObserver:self forKeyPath:@"loadedTimeRanges"];
    if (self.timeObserver) {
        [self.player removeTimeObserver:self.timeObserver];
    }
}

+ (instancetype)playerItem:(FLMediaItem *)item {
    return [self playerItem:item delegate:nil];
}

+ (instancetype)playerItem:(FLMediaItem *)item delegate:(nullable id <FLMediaPlayerDelegate>)delegate {
    return [FLMediaPlayer.alloc initWithItem:item delegate:delegate];
}

- (instancetype)initWithItem:(FLMediaItem *)item delegate:(id <FLMediaPlayerDelegate>)delegate
{
    self = [super init];
    if (self) {
        self.delegate = delegate;
        self.autoPlay = YES;
        self.isPause = YES;
        self.playView = FLMediaPlayView.alloc.init;
        [self loadItem:item];
    }
    return self;
}

- (NSTimeInterval)duration {
    if (self.item) {
        return CMTimeGetSeconds(self.item.duration);
    }
    return 0;
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
    self.playView.playerLayer = [AVPlayerLayer playerLayerWithPlayer:self.player];
    self.player.automaticallyWaitsToMinimizeStalling = NO;
    __weak typeof(self) weak_self = self;
    self.isLoading = YES;
    if ([self.delegate respondsToSelector:@selector(playerStartLoading:)]) {
        [self.delegate playerStartLoading:self];
    }
    self.timeObserver = [self.player addPeriodicTimeObserverForInterval:CMTimeMake(1, 2) queue:dispatch_get_main_queue() usingBlock:^(CMTime time) {
        if (weak_self.isPause) {
            if (weak_self.isLoading) {
                weak_self.isLoading = NO;
                if ([weak_self.delegate respondsToSelector:@selector(playerStopLoading:)]) {
                    [weak_self.delegate playerStopLoading:weak_self];
                }
            }
        }
        else {
            NSTimeInterval seconds = CMTimeGetSeconds(weak_self.item.currentTime);
            NSTimeInterval duration = CMTimeGetSeconds(weak_self.item.duration);
            if (seconds == duration &&
                duration != 0) {
                if (weak_self.loop) {
                    [weak_self seekToSeconds:0 completion:^(BOOL finished) {
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
                if (!weak_self.isLoading) {
                    weak_self.isLoading = YES;
                    if ([weak_self.delegate respondsToSelector:@selector(playerStartLoading:)]) {
                        [weak_self.delegate playerStartLoading:weak_self];
                    }
                }
            }
            else {
                if (weak_self.isLoading) {
                    weak_self.isLoading = NO;
                    if ([weak_self.delegate respondsToSelector:@selector(playerStopLoading:)]) {
                        [weak_self.delegate playerStopLoading:weak_self];
                    }
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
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSKeyValueChangeKey,id> *)change context:(void *)context {
    if (object == self.item && [keyPath isEqual:@"status"]) {
        switch (self.item.status) {
            case AVPlayerItemStatusReadyToPlay: {
                if (self.autoPlay) {
                    self.playView.backgroundColor = UIColor.blackColor;
                    [self play];
                }
            }
                break;
            default: {
                NSError *error;
                if (self.item.error) {
                    error = self.item.error;
                }
                if (self.player.error) {
                    error = self.player.error;
                }
                if ([self.delegate respondsToSelector:@selector(playerFailure:error:)]) {
                    [self.delegate playerFailure:self error:error];
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
            [self.delegate playerCacheRangeChange:self cacheSeconds:timeInterval duration:CMTimeGetSeconds(self.item.duration)];
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
    if (!self.isLoading) {
        self.isPause = YES;
        [self.player pause];
    }
}

- (void)seekToSeconds:(NSTimeInterval)seconds completion:(void (^)(BOOL))completion {
    self.stopDate = nil;
    self.stopTimeInterval = 0;
    [self.player seekToTime:CMTimeMake(seconds, 1) completionHandler:completion];
}

@end

#pragma mark --------------------------------- FLMediaPlayView ---------------------------------

@implementation FLMediaPlayView

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        self.userInteractionEnabled = NO;
        self.clipsToBounds = YES;
        [super setBackgroundColor:[UIColor colorWithWhite:0 alpha:0.5]];
        UIActivityIndicatorView *loading = [UIActivityIndicatorView.alloc initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhite];
        [loading startAnimating];
        [self addSubview:loading];
    }
    return self;
}

- (void)setBackgroundColor:(UIColor *)backgroundColor {
    [super setBackgroundColor:backgroundColor];
    [self.subviews makeObjectsPerformSelector:@selector(removeFromSuperview)];
}

- (void)setClipsToBounds:(BOOL)clipsToBounds {
    [super setClipsToBounds:YES];
}

- (void)layoutSubviews {
    [super layoutSubviews];
    self.playerLayer.frame = self.bounds;
    for (UIView *view in self.subviews) {
        view.frame = self.bounds;
    }
}

- (void)setPlayerLayer:(AVPlayerLayer *)playerLayer {
    if (_playerLayer.superlayer == self.layer) {
        [_playerLayer removeFromSuperlayer];
    }
    _playerLayer = playerLayer;
    [self.layer addSublayer:playerLayer];
    playerLayer.frame = self.bounds;
    switch (self.playMode) {
        case FLMediaPlayContentModeAspectFit:
            playerLayer.videoGravity = AVLayerVideoGravityResizeAspect;
            break;
        case FLMediaPlayContentModeAspectFill:
            playerLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;
            break;
        case FLMediaPlayContentModeResize:
            playerLayer.videoGravity = AVLayerVideoGravityResize;
            break;
    }
}

- (void)setPlayMode:(FLMediaPlayContentMode)playMode {
    _playMode = playMode;
    switch (playMode) {
        case FLMediaPlayContentModeAspectFit:
            self.playerLayer.videoGravity = AVLayerVideoGravityResizeAspect;
            break;
        case FLMediaPlayContentModeAspectFill:
            self.playerLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;
            break;
        case FLMediaPlayContentModeResize:
            self.playerLayer.videoGravity = AVLayerVideoGravityResize;
            break;
    }
}

@end


