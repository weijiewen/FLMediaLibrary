//
//  FLViewController.m
//  FLMediaLibrary_Example
//
//  Created by weijiewen on 2022/4/12.
//  Copyright © 2022 weijiwen. All rights reserved.
//

#import "FLViewController.h"
#import "FLPlayerController.h"
#import "FLImagesController.h"

@interface FLViewController () <UITableViewDelegate, UITableViewDataSource>

@end

@implementation FLViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
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


- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return 2;
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
    cell.textLabel.text = indexPath.row == 0 ? @"视频播放器" : @"图片浏览器";
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.row == 0) {
        FLPlayerController *controller = FLPlayerController.alloc.init;
        controller.modalPresentationStyle = UIModalPresentationFullScreen;
        [self presentViewController:controller animated:YES completion:nil];
    }
    else {
        FLImagesController *controller = FLImagesController.alloc.init;
        controller.modalPresentationStyle = UIModalPresentationFullScreen;
        [self presentViewController:controller animated:YES completion:nil];
    }
}


@end
