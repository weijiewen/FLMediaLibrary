//
//  FLImageBrowser.m
//  FLMediaLibrary_Example
//
//  Created by weijiewen on 2022/4/12.
//  Copyright © 2022 weijiwen. All rights reserved.
//

#import "FLImageBrowser.h"

@class FLImageBrowserCell;
@protocol FLImageBrowserCellDelegate <NSObject>
@required
@optional
- (void)browserCell:(FLImageBrowserCell *)cell didLongPressWithImage:(UIImage *)image;
- (void)browserCell:(FLImageBrowserCell *)cell dissmissProgress:(CGFloat)progress;
- (void)browserCellDissmiss;
- (void)browserRemoveFromWindow;
@end


@interface FLImageBrowserCell : UICollectionViewCell <UIScrollViewDelegate, UIGestureRecognizerDelegate>
@property (nonatomic, strong) id <FLImageBrowserPlayer> player;
@property (nonatomic, assign) BOOL panBeganIsPause;
@property (nonatomic, strong) UIScrollView *scrollView;
@property (nonatomic, strong) UIImageView *imageView;
@property (nonatomic, weak) id <FLImageBrowserCellDelegate> delegate;
@property (nonatomic, assign) CGFloat panStartZoomScale;
@property (nonatomic, strong) UIPanGestureRecognizer *pan;
@end
@implementation FLImageBrowserCell

- (void)dealloc {
    [self.imageView removeObserver:self forKeyPath:@"image"];
}

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        self.clipsToBounds = YES;
        self.scrollView = [[UIScrollView alloc] initWithFrame:self.bounds];
        self.scrollView.minimumZoomScale = 1;
        self.scrollView.maximumZoomScale = 8;
        self.scrollView.delegate = self;
        self.scrollView.showsHorizontalScrollIndicator = NO;
        self.scrollView.showsVerticalScrollIndicator = NO;
        self.scrollView.bounces = NO;
        self.scrollView.clipsToBounds = NO;
        [self.contentView addSubview:self.scrollView];
        
        self.imageView = [UIImageView.alloc initWithFrame:CGRectMake(1, 0, self.scrollView.bounds.size.width - 2, self.scrollView.bounds.size.height)];
        self.imageView.contentMode = UIViewContentModeScaleAspectFit;
        self.imageView.clipsToBounds = NO;
        self.imageView.userInteractionEnabled = NO;
        [self.imageView addObserver:self forKeyPath:@"image" options:NSKeyValueObservingOptionNew context:nil];
        [self.scrollView addSubview:self.imageView];
        
        self.pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(action_pan:)];
        self.pan.delegate = self;
        self.imageView.userInteractionEnabled = YES;
        [self.imageView addGestureRecognizer:self.pan];
        
        UITapGestureRecognizer *twoTouchTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(action_twoTap)];
        twoTouchTap.numberOfTapsRequired = 2;
        twoTouchTap.numberOfTouchesRequired = 1;
        [self.scrollView addGestureRecognizer:twoTouchTap];
        
        UITapGestureRecognizer *onceTouchTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(action_onceTap)];
        onceTouchTap.numberOfTapsRequired = 1;
        onceTouchTap.numberOfTouchesRequired = 1;
        [self.scrollView addGestureRecognizer:onceTouchTap];
        [onceTouchTap requireGestureRecognizerToFail:twoTouchTap];
        
        [self.scrollView addGestureRecognizer:[[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(action_longPress:)]];
    }
    return self;
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSKeyValueChangeKey,id> *)change context:(void *)context {
    if ([keyPath isEqualToString:@"image"]) {
        self.scrollView.contentOffset = CGPointMake(0, self.scrollView.contentSize.height / 2 - self.scrollView.bounds.size.height / 2);
        if (self.imageView.image) {
            CGFloat imageHeight = self.imageView.image.size.height / self.imageView.image.size.width * self.scrollView.bounds.size.width;
            CGFloat y = imageHeight > self.scrollView.bounds.size.height ? 0 : self.scrollView.bounds.size.height / 2 - imageHeight / 2;
            self.imageView.frame = CGRectMake(0, y, self.scrollView.bounds.size.width, imageHeight);
            CGFloat scrollHeight = imageHeight > self.scrollView.bounds.size.height ? imageHeight : self.scrollView.bounds.size.height;
            self.scrollView.contentSize = CGSizeMake(self.scrollView.bounds.size.width, scrollHeight);
        }
    }
}

- (UIView *)viewForZoomingInScrollView:(UIScrollView *)scrollView {
    if (self.player) {
        return nil;
    }
    return self.imageView;
}

- (void)scrollViewDidZoom:(UIScrollView *)scrollView {
    if (self.player) {
        return;
    }
    CGFloat imageX = (scrollView.bounds.size.width - self.imageView.frame.size.width) / 2.0;
    CGFloat imageY = (scrollView.bounds.size.height - self.imageView.frame.size.height) / 2.0;
    CGRect imageViewFrame = self.imageView.frame;
    if (imageX > 0) {
        imageViewFrame.origin.x = imageX;
    }
    else {
        imageViewFrame.origin.x = 0;
    }
    if (imageY > 0) {
        imageViewFrame.origin.y = imageY;
    }
    else {
        imageViewFrame.origin.y = 0;
    }
    self.imageView.frame = imageViewFrame;
}

- (void)action_twoTap {
    if (self.player) {
        return;
    }
    if (self.scrollView.zoomScale == 2) {
        [self.scrollView setZoomScale:1 animated:YES];
    }
    else {
        [self.scrollView setZoomScale:2 animated:YES];
    }
}

- (void)action_longPress:(UILongPressGestureRecognizer *)longPress {
    if (longPress.state == UIGestureRecognizerStateBegan && self.delegate && [self.delegate respondsToSelector:@selector(browserCell:didLongPressWithImage:)]) {
        [self.delegate browserCell:self didLongPressWithImage:self.imageView.image];
    }
}

- (void)action_onceTap {
    if (self.player) {
        if (self.player.isPause) {
            [self.player play];
        }
        else {
            [self.player pause];
        }
        return;
    }
    if (self.delegate && [self.delegate respondsToSelector:@selector(browserCellDissmiss)]) {
        [self.delegate browserCellDissmiss];
    }
}

- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)gestureRecognizer {
    if (![gestureRecognizer isKindOfClass:[UIPanGestureRecognizer class]]) {
        return YES;
    }
    UIPanGestureRecognizer *pan = (UIPanGestureRecognizer *)gestureRecognizer;
    if (pan == self.pan) {
        CGPoint point = [pan translationInView:pan.view];
        BOOL isBottom = (self.scrollView.contentOffset.y <= 0 && point.y > 0);
        BOOL isTop = (self.scrollView.contentOffset.y >= self.scrollView.contentSize.height - self.scrollView.bounds.size.height && point.y < 0);
        if (isBottom || isTop) {
            self.scrollView.scrollEnabled = NO;
            return YES;
        }
        return NO;
    }
    return YES;
}

- (void)action_pan:(UIPanGestureRecognizer *)pan {
    if (pan.state == UIGestureRecognizerStateBegan) {
        self.panStartZoomScale = self.scrollView.zoomScale;
        self.panBeganIsPause = self.player.isPause;
        if (!self.player.isPause) {
            [self.player pause];
        }
    } else if (pan.state == UIGestureRecognizerStateChanged) {
        CGPoint point = [pan translationInView:self.window];
        CGFloat progress = fabs(point.y) / 300.f;
        if (progress < 0) {
            progress = 0;
        }
        else if (progress > 1) {
            progress = 1;
        }
        [self.delegate browserCell:self dissmissProgress:progress];
    } else if (pan.state == UIGestureRecognizerStateEnded) {
        CGPoint point = [pan translationInView:self.window];
        if (fabs(point.y) > 200 || fabs([pan velocityInView:self.window].y) > 500) {
            [UIView animateWithDuration:0.3 animations:^{
                [self.delegate browserCell:self dissmissProgress:1];
            } completion:^(BOOL finished) {
                [self.delegate browserRemoveFromWindow];
            }];
        }
        else {
            [UIView animateWithDuration:0.3 animations:^{
                [self.delegate browserCell:self dissmissProgress:0];
            } completion:^(BOOL finished) {
                if (!self.panBeganIsPause) {
                    [self.player play];
                }
                self.scrollView.scrollEnabled = YES;
            }];
        }
    }
}

+ (NSString *)identifier {
    return NSStringFromClass(self);
}

- (void)reloadCell {
    [self.scrollView setZoomScale:1 animated:YES];
    for (UIView *subView in self.contentView.subviews) {
        if (subView != self.scrollView) {
            [subView removeFromSuperview];
        }
    }
}

@end

#import <objc/runtime.h>
@interface UIApplication (ImageBrowser)
@property (nonatomic, strong) NSMutableArray <FLImageBrowser *> *fl_imageBrowsers;
@end
@implementation UIApplication (ImageBrowser)
- (void)setFl_imageBrowsers:(NSMutableArray<FLImageBrowser *> *)fl_imageBrowsers {
    objc_setAssociatedObject(self, @selector(fl_imageBrowsers), fl_imageBrowsers, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}
- (NSMutableArray<FLImageBrowser *> *)fl_imageBrowsers {
    NSMutableArray<FLImageBrowser *> *fl_imageBrowsers = objc_getAssociatedObject(self, _cmd);
    if (!fl_imageBrowsers) {
        fl_imageBrowsers = NSMutableArray.array;
        [self setFl_imageBrowsers:fl_imageBrowsers];
    }
    return fl_imageBrowsers;
}
@end

@interface FLImageBrowserController : UIViewController
@end
@implementation FLImageBrowserController
- (UIStatusBarStyle)preferredStatusBarStyle {
    return UIStatusBarStyleLightContent;
}
- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = UIColor.blackColor;
}
@end

@interface FLImageBrowser () <UIScrollViewDelegate, UICollectionViewDelegate, UICollectionViewDataSource, FLImageBrowserCellDelegate>
@property (nonatomic, assign) NSInteger imageCount;
@property (nonatomic, assign) NSInteger currentIndex;
@property (nonatomic, copy) void(^requestImage)(UIImageView *imageView, NSInteger index, UIImage * _Nullable placeholder);
@property (nonatomic, copy) UIImageView * _Nullable (^sourceImageView)(NSInteger index);
@property (nonatomic, copy) id <FLImageBrowserPlayer> _Nullable (^willShow)(UIView *contentView, UIImageView *imageView, NSInteger index);
@property (nonatomic, copy) void(^longPress)(NSInteger index, UIImage *image, UIViewController *browserController);
@property (nonatomic, copy) dispatch_block_t dismiss;

@property (nonatomic, weak) UIWindow *sourceWindow;
@property (nonatomic, strong) UIWindow *window;
@property (nonatomic, strong) UICollectionView *collectionView;

@end

@implementation FLImageBrowser

+ (void)showWithCount:(NSInteger)count
           startIndex:(NSInteger)startIndex
         requestImage:(void(^)(UIImageView *imageView, NSInteger index, UIImage * _Nullable placeholder))requestImage {
    [self showWithCount:count startIndex:startIndex requestImage:requestImage sourceImageView:nil];
}

+ (void)showWithCount:(NSInteger)count
           startIndex:(NSInteger)startIndex
         requestImage:(void(^)(UIImageView *imageView, NSInteger index, UIImage * _Nullable placeholder))requestImage
      sourceImageView:(nullable UIImageView * _Nullable (^)(NSInteger index))sourceImageView {
    [self showWithCount:count startIndex:startIndex requestImage:requestImage sourceImageView:sourceImageView didDismiss:nil];
}

+ (void)showWithCount:(NSInteger)count
           startIndex:(NSInteger)startIndex
         requestImage:(void(^)(UIImageView *imageView, NSInteger index, UIImage * _Nullable placeholder))requestImage
           didDismiss:(nullable dispatch_block_t)didDismiss {
    [self showWithCount:count startIndex:startIndex requestImage:requestImage sourceImageView:nil didDismiss:didDismiss];
}

+ (void)showWithCount:(NSInteger)count
           startIndex:(NSInteger)startIndex
         requestImage:(void(^)(UIImageView *imageView, NSInteger index, UIImage * _Nullable placeholder))requestImage
      sourceImageView:(nullable UIImageView * _Nullable (^)(NSInteger index))sourceImageView
           didDismiss:(nullable dispatch_block_t)didDismiss {
    [self showWithCount:count startIndex:startIndex requestImage:requestImage sourceImageView:sourceImageView willShow:nil didDismiss:didDismiss];
}

+ (void)showWithCount:(NSInteger)count
           startIndex:(NSInteger)startIndex
         requestImage:(void(^)(UIImageView *imageView, NSInteger index, UIImage * _Nullable placeholder))requestImage
      sourceImageView:(nullable UIImageView * _Nullable (^)(NSInteger index))sourceImageView
             willShow:(nullable id <FLImageBrowserPlayer> _Nullable (^)(UIView *contentView, UIImageView *imageView, NSInteger index))willShow {
    [self showWithCount:count startIndex:startIndex requestImage:requestImage sourceImageView:sourceImageView willShow:willShow didDismiss:nil];
}

+ (void)showWithCount:(NSInteger)count
           startIndex:(NSInteger)startIndex
         requestImage:(void(^)(UIImageView *imageView, NSInteger index, UIImage * _Nullable placeholder))requestImage
      sourceImageView:(nullable UIImageView * _Nullable (^)(NSInteger index))sourceImageView
             willShow:(nullable id <FLImageBrowserPlayer> _Nullable (^)(UIView *contentView, UIImageView *imageView, NSInteger index))willShow
           didDismiss:(nullable dispatch_block_t)didDismiss {
    [self showWithCount:count startIndex:startIndex requestImage:requestImage sourceImageView:sourceImageView willShow:willShow longPress:nil didDismiss:didDismiss];
}

+ (void)showWithCount:(NSInteger)count
           startIndex:(NSInteger)startIndex
         requestImage:(void(^)(UIImageView *imageView, NSInteger index, UIImage * _Nullable placeholder))requestImage
      sourceImageView:(nullable UIImageView * _Nullable (^)(NSInteger index))sourceImageView
             willShow:(nullable id <FLImageBrowserPlayer> _Nullable (^)(UIView *contentView, UIImageView *imageView, NSInteger index))willShow
            longPress:(nullable void(^)(NSInteger index, UIImage *image, UIViewController *browserController))longPress
           didDismiss:(nullable dispatch_block_t)didDismiss {
    FLImageBrowser *imageBrowser = FLImageBrowser.alloc.init;
    imageBrowser.imageCount = count;
    imageBrowser.currentIndex = startIndex < count ? startIndex : 0;
    imageBrowser.sourceImageView = sourceImageView;
    imageBrowser.requestImage = requestImage;
    imageBrowser.willShow = willShow;
    imageBrowser.longPress = longPress;
    imageBrowser.dismiss = didDismiss;
    [UIApplication.sharedApplication.fl_imageBrowsers addObject:imageBrowser];
    [imageBrowser createLayout];
}


- (void)createLayout {
    UIImageView *sourceImageView = self.sourceImageView ? self.sourceImageView(self.currentIndex) : nil;
    self.sourceWindow = sourceImageView.window;
    self.sourceWindow.userInteractionEnabled = YES;
    CGRect screenFame = UIScreen.mainScreen.bounds;
    self.window = [UIWindow.alloc initWithFrame:sourceImageView ? screenFame : CGRectMake(0, screenFame.size.height, screenFame.size.width, screenFame.size.height)];
    self.window.backgroundColor = UIColor.blackColor;
    self.window.rootViewController = FLImageBrowserController.alloc.init;
    self.window.hidden = NO;
    self.window.alpha = 0;
    if (@available(iOS 13.0, *)) {
        for (UIWindowScene *scene in UIApplication.sharedApplication.connectedScenes) {
            if ([scene isKindOfClass:UIWindowScene.class] && scene.activationState == UISceneActivationStateForegroundActive) {
                self.window.windowScene = scene;
                break;
            }
        }
    }
    UIView *view = self.window.rootViewController.view;
    view.frame = self.window.bounds;
    
    UICollectionViewFlowLayout *layout = [[UICollectionViewFlowLayout alloc] init];
    layout.scrollDirection = UICollectionViewScrollDirectionHorizontal;
    layout.itemSize = CGSizeMake(view.bounds.size.width, view.bounds.size.height);
    layout.minimumLineSpacing = 0;
    layout.minimumInteritemSpacing = 0;
    
    self.collectionView = [[UICollectionView alloc] initWithFrame:view.bounds collectionViewLayout:layout];
    self.collectionView.backgroundColor = UIColor.clearColor;
    self.collectionView.delegate = self;
    self.collectionView.dataSource = self;
    self.collectionView.pagingEnabled = YES;
    self.collectionView.showsVerticalScrollIndicator = NO;
    self.collectionView.showsHorizontalScrollIndicator = NO;
    [self.collectionView registerClass:FLImageBrowserCell.class forCellWithReuseIdentifier:NSStringFromClass(FLImageBrowserCell.class)];
    [view addSubview:self.collectionView];
    self.window.userInteractionEnabled = NO;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        dispatch_async(dispatch_get_main_queue(), ^{
            
            [self.collectionView layoutIfNeeded];
            NSIndexPath *indexPath = [NSIndexPath indexPathForRow:self.currentIndex inSection:0];
            [self.collectionView scrollToItemAtIndexPath:indexPath atScrollPosition:UICollectionViewScrollPositionLeft animated:NO];
            [self.collectionView layoutIfNeeded];
            FLImageBrowserCell *cell = (FLImageBrowserCell *)[self.collectionView cellForItemAtIndexPath:indexPath];
            cell.imageView.image = sourceImageView.image;
            if (sourceImageView && self.sourceWindow) {
                CGSize size = self.window.bounds.size;
                
                BOOL hasImage = sourceImageView.image;
                CGRect sourceOnWindowRect = [sourceImageView convertRect:sourceImageView.bounds toView:self.sourceWindow];
                CGFloat fromWidth = sourceImageView.bounds.size.width;
                CGSize maskSize = CGSizeMake(size.width, sourceImageView.bounds.size.height / fromWidth * size.width);
                if (hasImage) {
                    CGFloat sourceScale = sourceImageView.bounds.size.width / sourceImageView.bounds.size.height;
                    CGFloat imageScale = sourceImageView.image.size.width / sourceImageView.image.size.height;
                    if (sourceImageView.contentMode == UIViewContentModeScaleAspectFill) {
                        if (sourceScale < imageScale) {
                            fromWidth = imageScale * sourceImageView.bounds.size.height;
                            maskSize.width = sourceImageView.bounds.size.width / fromWidth * size.width;
                            maskSize.height = sourceImageView.image.size.height / sourceImageView.image.size.width * size.width;
                        }
                    }
                    else if (sourceImageView.contentMode == UIViewContentModeScaleAspectFit) {
                        if (sourceScale > imageScale) {
                            fromWidth = imageScale * sourceImageView.bounds.size.height;
                        }
                        maskSize.height = sourceImageView.image.size.height / sourceImageView.image.size.width * maskSize.width;
                    }
                }
                else {
                    !self.requestImage ?: self.requestImage(cell.imageView, self.currentIndex, sourceImageView.image);
                    cell.player = self.willShow ? self.willShow(cell.contentView, cell.imageView, self.currentIndex) : nil;
                }
                CGFloat scale = fromWidth / self.window.bounds.size.width;
                self.window.center = CGPointMake(CGRectGetMidX(sourceOnWindowRect), CGRectGetMidY(sourceOnWindowRect));
                self.window.maskView = [[UIView alloc] initWithFrame:CGRectMake(size.width / 2 - maskSize.width / 2,
                                                                                size.height / 2 - maskSize.height / 2,
                                                                                maskSize.width,
                                                                                maskSize.height)];
                self.window.maskView.backgroundColor = UIColor.blackColor;
                self.window.maskView.clipsToBounds = YES;
                self.window.transform = CGAffineTransformMakeScale(scale, scale);
                self.window.alpha = 1;
                [UIView animateWithDuration:0.3 animations:^{
                    self.window.transform = CGAffineTransformIdentity;
                    self.window.center = CGPointMake(self.window.bounds.size.width / 2, self.window.bounds.size.height / 2);
                    self.window.maskView.bounds = self.window.bounds;
                    self.window.maskView.center = self.window.center;
                } completion:^(BOOL finished) {
                    if (hasImage) {
                        !self.requestImage ?: self.requestImage(cell.imageView, self.currentIndex, sourceImageView.image);
                        cell.player = self.willShow ? self.willShow(cell.contentView, cell.imageView, self.currentIndex) : nil;
                    }
                    self.window.userInteractionEnabled = YES;
                }];
            }
            else {
                self.window.alpha = 1;
                !self.requestImage ?: self.requestImage(cell.imageView, self.currentIndex, sourceImageView.image);
                cell.player = self.willShow ? self.willShow(cell.contentView, cell.imageView, self.currentIndex) : nil;
                [UIView animateWithDuration:0.3 animations:^{
                    self.window.frame = UIScreen.mainScreen.bounds;
                } completion:^(BOOL finished) {
                    self.window.userInteractionEnabled = YES;
                }];
            }
        });
    });
}


- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
    if ([scrollView isEqual:self.collectionView]) {
        NSInteger index = scrollView.contentOffset.x / scrollView.bounds.size.width;
        NSInteger loseWidth = (NSInteger)scrollView.contentOffset.x % (NSInteger)scrollView.bounds.size.width;
        if (loseWidth > scrollView.bounds.size.width / 2) {
            index += 1;
        }
        if (index != self.currentIndex) {
            FLImageBrowserCell *cell = (FLImageBrowserCell *)[self.collectionView cellForItemAtIndexPath:[NSIndexPath indexPathForItem:self.currentIndex inSection:0]];
            [cell.player pause];
            cell.player = nil;
            [cell reloadCell];
            self.currentIndex = index;
            if (self.willShow) {
                cell = (FLImageBrowserCell *)[self.collectionView cellForItemAtIndexPath:[NSIndexPath indexPathForItem:self.currentIndex inSection:0]];
                cell.player = self.willShow ? self.willShow(cell.contentView, cell.imageView, self.currentIndex) : nil;
            }
        }
    }
}

- (nonnull __kindof UICollectionViewCell *)collectionView:(nonnull UICollectionView *)collectionView cellForItemAtIndexPath:(nonnull NSIndexPath *)indexPath {
    FLImageBrowserCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:NSStringFromClass(FLImageBrowserCell.class) forIndexPath:indexPath];
    cell.delegate = self;
    [cell reloadCell];
    UIImageView *sourceImageView = self.sourceImageView ? self.sourceImageView(indexPath.item) : nil;
    !self.requestImage ?: self.requestImage(cell.imageView, indexPath.item, sourceImageView.image);
    return cell;
}

- (NSInteger)collectionView:(nonnull UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
    return self.imageCount;
}

- (void)browserCell:(FLImageBrowserCell *)cell didLongPressWithImage:(UIImage *)image {
    !self.longPress ?: self.longPress([self.collectionView indexPathForCell:cell].item, image, self.window.rootViewController);
}

- (void)browserCell:(FLImageBrowserCell *)cell dissmissProgress:(CGFloat)progress {
    UIImageView *sourceImageView = self.sourceImageView ? self.sourceImageView([self.collectionView indexPathForCell:cell].item) : nil;
    if (sourceImageView && self.sourceWindow) {
        CGRect sourceOnWindowRect = [sourceImageView convertRect:sourceImageView.bounds toView:self.sourceWindow];
        CGSize size = self.window.bounds.size;
        CGFloat toWidth = sourceImageView.bounds.size.width;
        CGSize maskSize = CGSizeMake(size.width, sourceImageView.bounds.size.height / toWidth * size.width);
        if (sourceImageView.image) {
            UIImage *image = !CGSizeEqualToSize(sourceImageView.image.size, cell.imageView.image.size) && cell.imageView.image ? cell.imageView.image : sourceImageView.image;
            CGFloat imageScale = image.size.width / image.size.height;
            CGFloat sourceScale = sourceImageView.bounds.size.width / sourceImageView.bounds.size.height;
            if (sourceImageView.contentMode == UIViewContentModeScaleAspectFill) {
                if (sourceScale < imageScale) {
                    toWidth = image.size.width / image.size.height * sourceImageView.bounds.size.height;
                    maskSize.width = sourceImageView.bounds.size.width / toWidth * size.width;
                    maskSize.height = image.size.height / image.size.width * size.width;
                }
            }
            else if (sourceImageView.contentMode == UIViewContentModeScaleAspectFit) {
                if (sourceScale > imageScale) {
                    toWidth = image.size.width / image.size.height * sourceImageView.bounds.size.height;
                }
                maskSize.height = image.size.height / image.size.width * size.width;
            }
        }
        CGFloat scale = toWidth / size.width;
        scale = (1 - scale) * (1 - progress) + scale;
        CGPoint center = CGPointMake(CGRectGetMidX(sourceOnWindowRect), CGRectGetMidY(sourceOnWindowRect));
        center.x = (self.window.bounds.size.width / 2 - center.x) * (1 - progress) + center.x;
        center.y = (self.window.bounds.size.height / 2 - center.y) * (1 - progress) + center.y;
        CGRect maskFrame = CGRectZero;
        maskFrame.origin.x = progress * (size.width / 2 - maskSize.width / 2);
        maskFrame.origin.y = progress * (size.height / 2 - maskSize.height / 2);
        maskFrame.size.width = size.width - (size.width - maskSize.width) * progress;
        maskFrame.size.height = size.height - (size.height - maskSize.height) * progress;
        cell.scrollView.zoomScale = (cell.panStartZoomScale - 1) * (1 - progress) + 1;
        self.window.maskView.frame = maskFrame;
        self.window.transform = CGAffineTransformMakeScale(scale, scale);
        self.window.center = center;
    }
    else {
        CGRect frame = self.window.frame;
        frame.origin.y = frame.size.height * progress;
        self.window.frame = frame;
    }
}

- (void)browserCellDissmiss {
    [self action_back];
}

- (void)browserRemoveFromWindow {
    self.requestImage = nil;
    self.sourceImageView = nil;
    self.willShow = nil;
    self.longPress = nil;
    self.dismiss = nil;
    [UIApplication.sharedApplication.fl_imageBrowsers removeObject:self];
}

- (void)action_back {
    !self.dismiss ?: self.dismiss();
    [UIView animateWithDuration:0.3 animations:^{
        [self browserCell:(FLImageBrowserCell *)[self.collectionView cellForItemAtIndexPath:[NSIndexPath indexPathForItem:self.currentIndex inSection:0]] dissmissProgress:1];
    } completion:^(BOOL finished) {
        [self browserRemoveFromWindow];
    }];
}

@end
