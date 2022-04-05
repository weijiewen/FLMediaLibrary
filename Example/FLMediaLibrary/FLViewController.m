//
//  FLViewController.m
//  FLMediaLibrary
//
//  Created by weijiwen on 03/14/2022.
//  Copyright (c) 2022 weijiwen. All rights reserved.
//

#import <objc/runtime.h>
#import "FLViewController.h"
#import "FLMediaPlayer.h"
#import "FLTips.h"

@interface FLViewController () <FLMediaPlayerDelegate, UITableViewDelegate, UITableViewDataSource>
@property (nonatomic, copy) NSString *url;
@property (nonatomic, strong) FLMediaPlayer *player;
@property (nonatomic, copy) NSArray *datas;
@end

@implementation FLViewController

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
    if (self != UIApplication.sharedApplication.keyWindow.rootViewController) {
        self.player = [FLMediaPlayer playerItem:[FLMediaItem mediaItemWithPath:self.url] delegate:self];
        self.player.playView.frame = self.view.bounds;
        self.player.playView.backgroundColor = UIColor.blackColor;
        [self.view addSubview:self.player.playView];
    }
    else {
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
        UITableView *tableView = [[UITableView alloc] initWithFrame:CGRectMake(0, UIApplication.sharedApplication.statusBarFrame.size.height, self.view.bounds.size.width, self.view.bounds.size.height - UIApplication.sharedApplication.statusBarFrame.size.height - 24) style:UITableViewStylePlain];
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
    
}

/// 缓冲进度改变
- (void)playerCacheRangeChange:(FLMediaPlayer *)player cacheSeconds:(NSTimeInterval)cacheSeconds duration:(NSTimeInterval)duration {
    
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
        FLViewController *controller = FLViewController.alloc.init;
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

@end
