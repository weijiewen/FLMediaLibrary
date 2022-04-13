//
//  FLImagesController.m
//  FLMediaLibrary_Example
//
//  Created by weijiewen on 2022/4/12.
//  Copyright © 2022 weijiwen. All rights reserved.
//

#import <UIImageView+WebCache.h>
#import "FLImagesController.h"
#import "FLImageBrowser.h"

@interface FLImagesController ()
@property (nonatomic, copy) NSArray *images;
@property (nonatomic, copy) NSArray <UIImageView *> *imageViews;
@end

@implementation FLImagesController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = UIColor.whiteColor;
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    UIButton *backButton = [UIButton buttonWithType:UIButtonTypeCustom];
    backButton.frame = CGRectMake(15, UIApplication.sharedApplication.statusBarFrame.size.height, 60, 44);
    backButton.titleLabel.font = [UIFont systemFontOfSize:15];
    [backButton setTitle:@"返回" forState:UIControlStateNormal];
    [backButton setTitleColor:UIColor.blackColor forState:UIControlStateNormal];
    [backButton addTarget:self action:@selector(action_back) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:backButton];
    
    CGSize imageSize = CGSizeMake(self.view.bounds.size.width - 30 - 30, 0);
    imageSize.width = imageSize.width / 3;
    imageSize.height = imageSize.width * 0.75;
    CGPoint startPoint = CGPointMake(15, self.view.bounds.size.height / 2 - imageSize.height / 2 - 10 - imageSize.height);
    NSMutableArray *imageViews = NSMutableArray.array;
    self.images = @[
        @"https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcTjtwM55YqrFczsQS5wPFLzUzI6K4N8_gnPtg&usqp=CAU",
        @"https://hbimg.huabanimg.com/0d949285b1ba152837bb8172c2893201fa5324e095c6c-Lvqu8r_fw658/format/webp",
        @"https://hbimg.huabanimg.com/09bef6db07b28a22b80f7defac6f292e80547cfc536d7-dv73w0_fw658/format/webp",
        @"https://hbimg.huabanimg.com/864b43b7fa1b5eb55a806a6d57912c85ba5e343c19dcb-MC5xUJ_fw658/format/webp",
        @"https://nimg.ws.126.net/?url=http%3A%2F%2Fdingyue.ws.126.net%2F2021%2F1022%2Fb334015dj00r1dtzg000mc000hs00bvc.jpg&thumbnail=750x2147483647&quality=85&type=jpg",
        @"https://hbimg.huabanimg.com/3b094a98741f2b8360ae4cf7c2fa84e34f0ce17c5a6d3-9UrG73_fw658/format/webp",
        @"https://img.alicdn.com/i3/3107963978/O1CN013f4rfd1fFyGKR2L7J_!!0-item_pic.jpg_q50s50.jpg",
        @"https://img.alicdn.com/bao/uploaded/i3/701227026/O1CN01e5oueC21lxUsFOPZ8_!!701227026.jpg_300x300q90.jpg",
        @"https://img.alicdn.com/i4/3862285568/O1CN01Rtr7qU1r0C2IqNrnt_!!0-item_pic.jpg_q50s50.jpg",
        @"https://gw.alicdn.com/i3/2696514443/O1CN01ekgjio1igwPNl2UpB_!!2696514443.jpg_300x300Q75.jpg_.webp"
    ];
    for (NSInteger i = 0; i < 9; i ++) {
        UIImageView *imageView = [UIImageView.alloc initWithFrame:CGRectMake(startPoint.x + i % 3 * (imageSize.width + 15), startPoint.y + i / 3 * (imageSize.height + 10), imageSize.width, imageSize.height)];
        imageView.backgroundColor = UIColor.yellowColor;
        imageView.contentMode = UIViewContentModeScaleAspectFit;
        imageView.clipsToBounds = YES;
        imageView.layer.cornerRadius = 6;
        imageView.userInteractionEnabled = YES;
        [imageView sd_setImageWithURL:[NSURL URLWithString:self.images[i]]];
        [imageView addGestureRecognizer:[UITapGestureRecognizer.alloc initWithTarget:self action:@selector(action_tap:)]];
        [self.view addSubview:imageView];
        [imageViews addObject:imageView];
    }
    self.imageViews = imageViews.copy;
}

- (void)action_back {
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)action_tap:(UITapGestureRecognizer *)sender {
    NSInteger index = [self.imageViews indexOfObject:sender.view];
    [FLImageBrowser showWithCount:self.imageViews.count startIndex:index requestImage:^(UIImageView * _Nonnull imageView, NSInteger index, UIImage * _Nullable placeholder) {
        [imageView sd_setImageWithURL:[NSURL URLWithString:self.images[index]]];
    } sourceImageView:^UIImageView * _Nullable(NSInteger index) {
        return self.imageViews[index];
    } willShow:^id<FLImageBrowserPlayer> _Nullable(UIView * _Nonnull contentView, UIImageView * _Nonnull imageView, NSInteger index) {
        return nil;
    } longPress:^(NSInteger index, UIImage * _Nonnull image) {
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:nil message:nil preferredStyle:UIAlertControllerStyleActionSheet];
        [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
        [alert addAction:[UIAlertAction actionWithTitle:@"保存" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
            
        }]];
        dispatch_async(dispatch_get_main_queue(), ^{
            [self presentViewController:alert animated:YES completion:nil];
        });
    } didDismiss:^{
        
    }];
}

@end
