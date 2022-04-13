//
//  FLViewController.m
//  FLMediaLibrary
//
//  Created by weijiwen on 03/14/2022.
//  Copyright (c) 2022 weijiwen. All rights reserved.
//

#import <objc/runtime.h>
#import "FLPlayerController.h"
#import "FLProgressView.h"
#import "FLMediaPlayer.h"
#import "FLTips.h"

@interface FLPlayerController () <FLMediaPlayerDelegate, UITableViewDelegate, UITableViewDataSource>
@property (nonatomic, copy) NSArray *datas;
@property (nonatomic, copy) NSString *url;
@property (nonatomic, strong) FLMediaPlayer *player;
@property (nonatomic, strong) UIButton *controlButton;
@property (nonatomic, strong) UILabel *timeLabel;
@property (nonatomic, strong) FLProgressView *progressView;
@end

@implementation FLPlayerController

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    if (self.url.length) {
        [self dismissViewControllerAnimated:YES completion:nil];
    }
}

- (void)viewDidLoad
{
    [super viewDidLoad];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    if (self != UIApplication.sharedApplication.keyWindow.rootViewController && self.url.length) {
        self.player = [FLMediaPlayer playerItem:[FLMediaItem mediaItemWithPath:self.url] delegate:self];
        self.player.playView.frame = self.view.bounds;
        self.player.playView.backgroundColor = UIColor.blackColor;
        [self.view addSubview:self.player.playView];
        
        self.controlButton = [UIButton buttonWithType:UIButtonTypeCustom];
        self.controlButton.frame = CGRectMake(10, self.view.bounds.size.height - 34 - 10 - 30, 30, 30);
        self.controlButton.backgroundColor = UIColor.whiteColor;
        self.controlButton.titleLabel.font = [UIFont systemFontOfSize:15];
        [self.controlButton setTitle:@"播" forState:UIControlStateNormal];
        [self.controlButton setTitle:@"停" forState:UIControlStateSelected];
        [self.controlButton setTitleColor:UIColor.blackColor forState:UIControlStateNormal];
        [self.controlButton addTarget:self action:@selector(action_play) forControlEvents:UIControlEventTouchUpInside];
        self.controlButton.selected = YES;
        [self.view addSubview:self.controlButton];
        
        self.timeLabel = [UILabel.alloc initWithFrame:CGRectMake(self.view.bounds.size.width - 10 - 100, CGRectGetMidY(self.controlButton.frame) - 15, 100, 30)];
        self.timeLabel.font = [UIFont systemFontOfSize:13];
        self.timeLabel.textAlignment = NSTextAlignmentRight;
        self.timeLabel.textColor = UIColor.whiteColor;
        self.timeLabel.text = @"00:00/00:00";
        [self.view addSubview:self.timeLabel];
        
        self.progressView = [FLProgressView.alloc initWithFrame:CGRectMake(50, self.view.bounds.size.height - 34 - 10 - 15 - 2, CGRectGetMinX(self.timeLabel.frame) - 10 - 50, 4)];
        [self.view addSubview:self.progressView];
        
    }
    else {
        UIButton *backButton = [UIButton buttonWithType:UIButtonTypeCustom];
        backButton.frame = CGRectMake(15, UIApplication.sharedApplication.statusBarFrame.size.height, 60, 44);
        backButton.titleLabel.font = [UIFont systemFontOfSize:15];
        [backButton setTitle:@"返回" forState:UIControlStateNormal];
        [backButton setTitleColor:UIColor.blackColor forState:UIControlStateNormal];
        [backButton addTarget:self action:@selector(action_back) forControlEvents:UIControlEventTouchUpInside];
        [self.view addSubview:backButton];
        self.view.backgroundColor = UIColor.whiteColor;
        self.datas = @[
            @"http://vfx.mtime.cn/Video/2019/02/04/mp4/190204084208765161.mp4",

            @"http://vfx.mtime.cn/Video/2019/03/21/mp4/190321153853126488.mp4",

            @"http://vfx.mtime.cn/Video/2019/03/19/mp4/190319222227698228.mp4",

            @"http://vfx.mtime.cn/Video/2019/03/19/mp4/190319212559089721.mp4",

            @"http://vfx.mtime.cn/Video/2019/03/18/mp4/190318231014076505.mp4",

            @"http://vfx.mtime.cn/Video/2019/03/18/mp4/190318214226685784.mp4",

            @"http://vfx.mtime.cn/Video/2019/03/19/mp4/190319104618910544.mp4",

            @"http://vfx.mtime.cn/Video/2019/03/19/mp4/190319125415785691.mp4",

            @"http://vfx.mtime.cn/Video/2019/03/17/mp4/190317150237409904.mp4",

            @"http://vfx.mtime.cn/Video/2019/03/14/mp4/190314223540373995.mp4",

            @"http://vfx.mtime.cn/Video/2019/03/14/mp4/190314102306987969.mp4",

            @"http://vfx.mtime.cn/Video/2019/03/13/mp4/190313094901111138.mp4",

            @"http://vfx.mtime.cn/Video/2019/03/12/mp4/190312143927981075.mp4",

            @"http://vfx.mtime.cn/Video/2019/03/12/mp4/190312083533415853.mp4",

            @"http://vfx.mtime.cn/Video/2019/03/09/mp4/190309153658147087.mp4",

            @"清除缓存"
        ];
        UITableView *tableView = [[UITableView alloc] initWithFrame:CGRectMake(0, UIApplication.sharedApplication.statusBarFrame.size.height + 44, self.view.bounds.size.width, self.view.bounds.size.height - UIApplication.sharedApplication.statusBarFrame.size.height - 24 - 44) style:UITableViewStylePlain];
        tableView.estimatedRowHeight = 0;
        tableView.estimatedSectionHeaderHeight = 0;
        tableView.estimatedSectionFooterHeight = 0;
        if (@available(iOS 15.0, *)) {
            tableView.sectionHeaderTopPadding = 0;
        }
        tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
        tableView.showsVerticalScrollIndicator = NO;
        tableView.tableFooterView = UIView.alloc.init;
        tableView.delegate = self;
        tableView.dataSource = self;
        if (@available(iOS 11.0, *)) {
            tableView.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentAlways;
        }
        [self.view addSubview:tableView];
    }
}

/// 缓存不足以继续播放，此处加载loading
- (void)playerStartLoading:(FLMediaPlayer *)player {
    [player.playView fl_showLoadingWithColor:[UIColor colorWithWhite:0 alpha:0.3]];
}

/// 开始播放、或重新开始播放、或暂停后开始播放回调该方法
- (void)playerStopLoading:(FLMediaPlayer *)player {
    [player.playView fl_dismiss];
}

/// 播放结束，如果loop为YES 该方法不会回调
- (void)playerFinish:(FLMediaPlayer *)player {
    NSAttributedString *tipText = [NSAttributedString.alloc initWithString:@"播放结束" attributes:@{NSFontAttributeName: [UIFont systemFontOfSize:15], NSForegroundColorAttributeName: UIColor.whiteColor}];
    NSAttributedString *buttonText = [NSAttributedString.alloc initWithString:@"重播" attributes:@{NSFontAttributeName: [UIFont systemFontOfSize:13], NSForegroundColorAttributeName: UIColor.blueColor}];
    __weak typeof(player) weak_player = player;
    [player.playView fl_showTip:tipText buttonText:buttonText action:^{
        [weak_player seekToSeconds:0 completion:^(BOOL finished) {
            [weak_player.playView fl_dismiss];
            [weak_player play];
        }];
    }];
}

/// 播放失败
- (void)playerFailure:(FLMediaPlayer *)player error:(NSError *)error {
    NSAttributedString *tipText = [NSAttributedString.alloc initWithString:@"播放失败" attributes:@{NSFontAttributeName: [UIFont systemFontOfSize:15], NSForegroundColorAttributeName: UIColor.whiteColor}];
    NSAttributedString *buttonText = [NSAttributedString.alloc initWithString:@"重试" attributes:@{NSFontAttributeName: [UIFont systemFontOfSize:13], NSForegroundColorAttributeName: UIColor.blueColor}];
    __weak typeof(self) weak_self = self;
    [player.playView fl_showTip:tipText buttonText:buttonText action:^{
        weak_self.player = [FLMediaPlayer playerItem:[FLMediaItem mediaItemWithPath:weak_self.url] delegate:weak_self];
        weak_self.player.playView.frame = self.view.bounds;
        weak_self.player.playView.backgroundColor = UIColor.blackColor;
        [weak_self.view addSubview:weak_self.player.playView];
    }];
}

/// 播放时间改变
- (void)playerTimeChange:(FLMediaPlayer *)player currentSeconds:(NSTimeInterval)currentSeconds duration:(NSTimeInterval)duration {
    NSInteger c = currentSeconds;
    NSInteger d = duration;
    self.timeLabel.text = [NSString stringWithFormat:@"%02ld:%02ld/%02ld:%02ld", c / 60, c % 60, d / 60, d % 60];
    self.progressView.progress = currentSeconds / duration;
}

/// 缓冲进度改变
- (void)playerCacheRangeChange:(FLMediaPlayer *)player cacheSeconds:(NSTimeInterval)cacheSeconds duration:(NSTimeInterval)duration {
    self.progressView.cache = cacheSeconds / duration;
}

- (void)action_play {
    self.controlButton.selected = !self.controlButton.selected;
    if (self.controlButton.selected) {
        [self.player play];
    }
    else {
        [self.player pause];
    }
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.datas.count;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return 50;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"cell"];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"cell"];
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
        cell.textLabel.textColor = UIColor.blackColor;
    }
    cell.textLabel.text = self.datas[indexPath.row];
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    NSString *url = self.datas[indexPath.row];
    if ([url hasPrefix:@"http"]) {
        FLPlayerController *controller = FLPlayerController.alloc.init;
        controller.modalPresentationStyle = UIModalPresentationFullScreen;
        controller.url = url;
        [self presentViewController:controller animated:YES completion:nil];
    }
    else {
        [FLTips showLoading];
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            [NSFileManager.defaultManager removeItemAtPath:FLMediaItem.directoryPath error:nil];
            dispatch_async(dispatch_get_main_queue(), ^{
                [FLTips dismiss];
            });
        });
    }
}

- (void)action_back {
    [self dismissViewControllerAnimated:YES completion:nil];
}

@end
