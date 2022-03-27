//
//  FLViewController.m
//  FLMediaLibrary
//
//  Created by weijiwen on 03/14/2022.
//  Copyright (c) 2022 weijiwen. All rights reserved.
//

#import "FLViewController.h"
#import "FLMediaPlayer.h"

@interface FLViewController () <FLMediaPlayerDelegate
//, FLMediaPlayerDataSource
>
@property (nonatomic, strong) FLMediaPlayer *player;
@end

@implementation FLViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.player = FLMediaPlayer.player;
    self.player.delegate = self;
    self.player.playView.frame = self.view.bounds;
    self.player.playView.backgroundColor = UIColor.blueColor;
    [self.view addSubview:self.player.playView];
    [self.player loadKey:@"http://vfx.mtime.cn/Video/2019/03/19/mp4/190319125415785691.mp4"];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
