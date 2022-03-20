//
//  MTImageBrowserController.m
//  MTKit_Example
//
//  Created by iMac on 2019/4/20.
//  Copyright © 2019 txyMTw@icloud.com. All rights reserved.
//

#import <objc/runtime.h>
#import <AVFoundation/AVFoundation.h>
#import "JYImageBrowser.h"

@interface JYPlayView : UIView
@property (nonatomic, strong) AVPlayer *player;
@property (nonatomic, strong) AVPlayerLayer *playerLayer;
@end
@implementation JYPlayView

- (void)dealloc {
    [NSNotificationCenter.defaultCenter removeObserver:self];
}

- (void)layoutSubviews {
    self.playerLayer.frame = self.bounds;
}

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        self.userInteractionEnabled = NO;
        [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(actionPlayEnd:) name:AVPlayerItemDidPlayToEndTimeNotification object:nil];
    }
    return self;
}

- (void)actionPlayEnd:(NSNotification *)sender {
    if (sender.object == self.player.currentItem) {
        [self.player seekToTime:CMTimeMake(0, 300)];
        [self.player play];
    }
}

- (void)playWithAsset:(JYAsset *)asset {
    __weak typeof(self) weak_self = self;
    [asset requestVideoAssetWithCompletion:^(AVAsset * _Nonnull avasset, AVAudioMix * _Nonnull audioMix, NSDictionary * _Nonnull info) {
        weak_self.player = [AVPlayer playerWithPlayerItem:[AVPlayerItem playerItemWithAsset:avasset]];
        weak_self.playerLayer = [AVPlayerLayer playerLayerWithPlayer:weak_self.player];
        [weak_self.layer addSublayer:weak_self.playerLayer];
        [weak_self.player play];
    }];
}

@end

@interface JYImageBrowser (Player)
@property (nonatomic, strong) JYPlayer *player;
@property (nonatomic, strong) JYPlayView *assetPlayer;
@property (nonatomic, strong) UIImageView *playImageView;
@property (nonatomic, strong) UIView *playLoadingView;
@property (nonatomic, assign) long requestID;
@end
@implementation JYImageBrowser (Player)
- (void)setPlayer:(JYPlayer *)player {
    objc_setAssociatedObject(self, @selector(player), player, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}
- (JYPlayer *)player {
    return objc_getAssociatedObject(self, _cmd);
}
- (void)setAssetPlayer:(JYPlayView *)assetPlayer {
    objc_setAssociatedObject(self, @selector(assetPlayer), assetPlayer, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}
- (JYPlayView *)assetPlayer {
    return objc_getAssociatedObject(self, _cmd);
}
- (void)setPlayImageView:(UIImageView *)playImageView {
    objc_setAssociatedObject(self, @selector(playImageView), playImageView, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}
- (UIImageView *)playImageView {
    return objc_getAssociatedObject(self, _cmd);
}
- (void)setPlayLoadingView:(UIView *)playLoadingView {
    objc_setAssociatedObject(self, @selector(playLoadingView), playLoadingView, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}
- (UIView *)playLoadingView {
    return objc_getAssociatedObject(self, _cmd);
}
- (void)setRequestID:(long)requestID {
    objc_setAssociatedObject(self, @selector(requestID), @(requestID), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}
- (long)requestID {
    return [objc_getAssociatedObject(self, _cmd) longValue];
}
@end


@interface UIView (MediaPlayerProperty) <JYPlayerDelegate>
@property (nonatomic, weak) JYImageBrowser *jy_imageBrowser;
@end
@implementation UIView (MediaPlayerProperty)
- (void)setJy_imageBrowser:(JYImageBrowser *)jy_imageBrowser {
    JYWeakObj *weakObject = objc_getAssociatedObject(self, @selector(jy_imageBrowser));
    if (!weakObject) {
        weakObject = JYWeakObj.alloc.init;
        objc_setAssociatedObject(self, @selector(jy_imageBrowser), weakObject, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    weakObject.jy_weakObject = jy_imageBrowser;
}
- (JYImageBrowser *)jy_imageBrowser {
    JYWeakObj *weakObject = objc_getAssociatedObject(self, _cmd);
    return weakObject.jy_weakObject;
}
@end

@implementation UIView (MediaPlayer)

- (void)playMediaVideoWithObjectKey:(NSString *)objectKey {
    [self stopPlayer];
    self.jy_imageBrowser.player = [JYPlayer.alloc initWithObjectKey:objectKey delegate:self];
    CALayer *layer = self.jy_imageBrowser.player.creatPlayerLayer;
    layer.frame = self.bounds;
    [self.layer addSublayer:layer];
    [self.jy_imageBrowser.player play];
    self.jy_imageBrowser.playImageView = [UIImageView.alloc initWithFrame:CGRectMake(self.bounds.size.width / 2 - 20, self.bounds.size.height / 2 - 24, 60, 60)];
    self.jy_imageBrowser.playImageView.image = [UIImage imageNamed:@"other_play"];
    self.jy_imageBrowser.playImageView.hidden = YES;
    [self addSubview:self.jy_imageBrowser.playImageView];
}

- (void)playAssetVideoWithAsset:(JYAsset *)asset {
    [self stopPlayer];
    self.jy_imageBrowser.assetPlayer = JYPlayView.alloc.init;
    [self addSubview:self.jy_imageBrowser.assetPlayer];
    [self.jy_imageBrowser.assetPlayer mas_makeConstraints:^(MASConstraintMaker *make) {
        make.edges.equalTo(self);
    }];
    [self.jy_imageBrowser.assetPlayer playWithAsset:asset];
    self.jy_imageBrowser.playImageView = [UIImageView.alloc initWithFrame:CGRectMake(self.bounds.size.width / 2 - 20, self.bounds.size.height / 2 - 24, 60, 60)];
    self.jy_imageBrowser.playImageView.image = [UIImage imageNamed:@"other_play"];
    self.jy_imageBrowser.playImageView.hidden = YES;
    [self addSubview:self.jy_imageBrowser.playImageView];
}

- (void)stopPlayer {
    [self.jy_imageBrowser.player pause];
    [self.jy_imageBrowser.player.creatPlayerLayer removeFromSuperlayer];
    self.jy_imageBrowser.player = nil;
    [self.jy_imageBrowser.assetPlayer.player pause];
    [self.jy_imageBrowser.assetPlayer removeFromSuperview];
    self.jy_imageBrowser.assetPlayer = nil;
    [self.jy_imageBrowser.playImageView removeFromSuperview];
    self.jy_imageBrowser.playImageView = nil;
}

- (void)mediaPlayerDidEnd {
    __weak typeof(self) weak_self = self;
    [self.jy_imageBrowser.player seekToTime:CMTimeMake(0, 300) completionHandler:^(BOOL finished) {
        [weak_self.jy_imageBrowser.player play];
    }];
}

- (void)mediaPlayerStartLoading {
    if (!self.jy_imageBrowser.playLoadingView) {
        self.jy_imageBrowser.playLoadingView = [UIView.alloc initWithFrame:self.bounds];
        self.jy_imageBrowser.playLoadingView.userInteractionEnabled = NO;
        [self addSubview:self.jy_imageBrowser.playLoadingView];
    }
    else {
        self.jy_imageBrowser.playLoadingView.frame = self.bounds;
    }
    [JYTip showToView:self.jy_imageBrowser.playLoadingView backgroundColor:[UIColor colorWithWhite:0 alpha:0.2]];
}

- (void)mediaPlayerStopLoading {
    [JYTip hideTipToView:self.jy_imageBrowser.playLoadingView];
}

@end


@protocol JYBrowserImageViewDelegate <NSObject>
@required
@optional
- (void)imageChange:(UIImageView *)imageView;
@end
@interface JYBrowserImageView : UIImageView
@property (nonatomic, weak) id <JYBrowserImageViewDelegate> delegate;
@end
@implementation JYBrowserImageView

- (void)setImage:(UIImage *)image {
    [super setImage:image];
    if (image && self.delegate && [self.delegate respondsToSelector:@selector(imageChange:)]) {
        [self.delegate imageChange:self];
    }
}

@end

@class JYImageBrowserCollectionViewCell;
@protocol JYImageBrowserCollectionViewCellDelegate <NSObject>
@required
@optional
- (void)browserCell:(JYImageBrowserCollectionViewCell *)cell didLongPressWithImage:(UIImage *)image;
- (void)browserCell:(JYImageBrowserCollectionViewCell *)cell dissmissProgress:(CGFloat)progress;
- (void)browserCellDissmiss;
@end
@interface JYImageBrowserCollectionViewCell : UICollectionViewCell <UIScrollViewDelegate, JYBrowserImageViewDelegate, UIGestureRecognizerDelegate>
@property (nonatomic, strong) UIScrollView *scrollView;
@property (nonatomic, strong) JYBrowserImageView *imageView;
@property (nonatomic, weak) id <JYImageBrowserCollectionViewCellDelegate> delegate;
@property (nonatomic, assign) BOOL disenableScale;
@property (nonatomic, assign) CGFloat panStartZoomScale;
@end
@implementation JYImageBrowserCollectionViewCell

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
        
        self.imageView = [[JYBrowserImageView alloc] initWithFrame:self.scrollView.bounds];
        self.imageView.contentMode = UIViewContentModeScaleAspectFit;
        self.imageView.clipsToBounds = NO;
        self.imageView.delegate = self;
        [self.imageView addObserver:self forKeyPath:@"image" options:NSKeyValueObservingOptionNew context:nil];
        [self.scrollView addSubview:self.imageView];
        
        UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(action_pan:)];
        pan.delegate = self;
        self.imageView.userInteractionEnabled = YES;
        [self.imageView addGestureRecognizer:pan];
        
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
    }
}

- (UIView *)viewForZoomingInScrollView:(UIScrollView *)scrollView {
    if (self.disenableScale) {
        return nil;
    }
    return self.imageView;
}

- (void)scrollViewDidZoom:(UIScrollView *)scrollView {
    if (self.disenableScale) {
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

- (void)imageChange:(UIImageView *)imageView {
    if (imageView.image) {
        CGFloat imageHeight = imageView.image.size.height / imageView.image.size.width * self.scrollView.bounds.size.width;
        CGFloat y = imageHeight > self.scrollView.bounds.size.height ? 0 : self.scrollView.bounds.size.height / 2 - imageHeight / 2;
        self.imageView.frame = CGRectMake(0, y, self.scrollView.bounds.size.width, imageHeight);
        CGFloat scrollHeight = imageHeight > self.scrollView.bounds.size.height ? imageHeight : self.scrollView.bounds.size.height;
        self.scrollView.contentSize = CGSizeMake(self.scrollView.bounds.size.width, scrollHeight);
    }
}

- (void)action_twoTap {
    if (self.disenableScale) {
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
    if (self.jy_imageBrowser.player || self.jy_imageBrowser.assetPlayer) {
        if (self.jy_imageBrowser.playImageView.hidden) {
            [self.jy_imageBrowser.player pause];
            [self.jy_imageBrowser.assetPlayer.player pause];
            self.jy_imageBrowser.playImageView.hidden = NO;
        }
        else {
            [self.jy_imageBrowser.player play];
            [self.jy_imageBrowser.assetPlayer.player play];
            self.jy_imageBrowser.playImageView.hidden = YES;
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
    CGPoint point = [pan translationInView:pan.view];
    BOOL isBottom = (self.scrollView.contentOffset.y <= 0 && point.y > 0);
    BOOL isTop = (self.scrollView.contentOffset.y >= self.scrollView.contentSize.height - self.scrollView.bounds.size.height && point.y < 0);
    if (isBottom || isTop) {
        self.scrollView.scrollEnabled = NO;
        return YES;
    }
    return NO;
}

//移动当前视频
- (void)action_pan:(UIPanGestureRecognizer *)pan {
    if (pan.state == UIGestureRecognizerStateBegan) {
        self.panStartZoomScale = self.scrollView.zoomScale;
        if (self.jy_imageBrowser.playImageView.hidden) {
            self.jy_imageBrowser.playImageView.hidden = NO;
            [self.jy_imageBrowser.player pause];
            [self.jy_imageBrowser.assetPlayer.player pause];
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
                UIViewController *controller = (UIViewController *)self.delegate;
                [controller.view removeFromSuperview];
                [controller removeFromParentViewController];
            }];
        }
        else {
            [UIView animateWithDuration:0.3 animations:^{
                [self.delegate browserCell:self dissmissProgress:0];
            } completion:^(BOOL finished) {
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
}

@end


@interface JYImageBrowser () <UIScrollViewDelegate, UICollectionViewDelegate, UICollectionViewDataSource, JYImageBrowserCollectionViewCellDelegate>
@property (nonatomic, strong) UICollectionView *collectionView;
@property (nonatomic, strong) UIPageControl *pageControl;
@property (nonatomic, assign) NSInteger imageCount;
@property (nonatomic, assign) NSInteger currentIndex;
@property (nonatomic, copy) UIImageView *(^fromImageView)(NSInteger index);
@property (nonatomic, copy) void(^setImage)(UIImageView *imageView, NSInteger index, JYImageBrowser *controller);
@property (nonatomic, copy) void(^scrollTo)(UIView *currentView, NSInteger index, dispatch_block_t disenableScale);
@property (nonatomic, copy) void(^longPress)(NSInteger index, UIImage *image, JYImageBrowser *controller);
@property (nonatomic, copy) dispatch_block_t dismiss;
@end

@implementation JYImageBrowser

+ (void)showImageCount:(NSInteger)imageCount
          browserIndex:(NSInteger)browserIndex
         fromImageView:(UIImageView *(^)(NSInteger index))fromImageView
              setImage:(void(^)(UIImageView *imageView, NSInteger index, JYImageBrowser *controller))setImage {
    [self showImageCount:imageCount browserIndex:browserIndex fromImageView:fromImageView setImage:setImage scrollTo:nil longPress:nil];
}

+ (void)showImageCount:(NSInteger)imageCount
          browserIndex:(NSInteger)browserIndex
         fromImageView:(UIImageView *(^)(NSInteger index))fromImageView
              setImage:(void(^)(UIImageView *imageView, NSInteger index, JYImageBrowser *controller))setImage
               dismiss:(nonnull dispatch_block_t)dismiss {
    [self showImageCount:imageCount browserIndex:browserIndex fromImageView:fromImageView setImage:setImage scrollTo:^(UIView * _Nonnull currentView, NSInteger index, dispatch_block_t  _Nonnull disenableScale) {
            
    } dismiss:dismiss];
}

+ (void)showImageCount:(NSInteger)imageCount
          browserIndex:(NSInteger)browserIndex
         fromImageView:(UIImageView *(^)(NSInteger index))fromImageView
              setImage:(void(^)(UIImageView *imageView, NSInteger index, JYImageBrowser *controller))setImage
              scrollTo:(void(^)(UIView *currentView, NSInteger index, dispatch_block_t disenableScale))scrollTo {
    [self showImageCount:imageCount browserIndex:browserIndex fromImageView:fromImageView setImage:setImage scrollTo:scrollTo dismiss:^{
            
    }];
}

+ (void)showImageCount:(NSInteger)imageCount
          browserIndex:(NSInteger)browserIndex
         fromImageView:(UIImageView *(^)(NSInteger index))fromImageView
              setImage:(void(^)(UIImageView *imageView, NSInteger index, JYImageBrowser *controller))setImage
              scrollTo:(void(^)(UIView *currentView, NSInteger index, dispatch_block_t disenableScale))scrollTo
               dismiss:(dispatch_block_t)dismiss {
    [self showImageCount:imageCount browserIndex:browserIndex fromImageView:fromImageView setImage:setImage scrollTo:scrollTo longPress:nil];
}

+ (void)showImageCount:(NSInteger)imageCount
          browserIndex:(NSInteger)browserIndex
         fromImageView:(UIImageView *(^)(NSInteger index))fromImageView
              setImage:(void(^)(UIImageView *imageView, NSInteger index, JYImageBrowser *controller))setImage
              scrollTo:(void(^)(UIView *currentView, NSInteger index, dispatch_block_t disenableScale))scrollTo
             longPress:(void(^)(NSInteger index, UIImage *image, JYImageBrowser *controller))longPress {
    [self showImageCount:imageCount browserIndex:browserIndex fromImageView:fromImageView setImage:setImage scrollTo:scrollTo longPress:longPress dismiss:^{
            
    }];
}

+ (void)showImageCount:(NSInteger)imageCount
          browserIndex:(NSInteger)browserIndex
         fromImageView:(UIImageView *(^)(NSInteger index))fromImageView
              setImage:(void(^)(UIImageView *imageView, NSInteger index, JYImageBrowser *controller))setImage
              scrollTo:(void(^)(UIView *currentView, NSInteger index, dispatch_block_t disenableScale))scrollTo
             longPress:(void(^)(NSInteger index, UIImage *image, JYImageBrowser *controller))longPress
               dismiss:(dispatch_block_t)dismiss {
    if (imageCount) {
        JYImageBrowser *browser = [[JYImageBrowser alloc] initWithImageCount:imageCount browserIndex:browserIndex fromImageView:fromImageView setImage:setImage scrollTo:scrollTo longPress:longPress dismiss:dismiss];
        
        UIViewController *fromController = JYIM.IM.appWindow.rootViewController;
        while (fromController.presentedViewController) {
            fromController = fromController.presentedViewController;
        }
        [fromController addChildViewController:browser];
        [fromController.view addSubview:browser.view];
        [browser creatUI];
    }
}

- (instancetype)initWithImageCount:(NSInteger)imageCount
                      browserIndex:(NSInteger)browserIndex
                     fromImageView:(UIImageView *(^)(NSInteger index))fromImageView
                          setImage:(void(^)(UIImageView *imageView, NSInteger index, JYImageBrowser *controller))setImage
                          scrollTo:(void(^)(UIView *currentView, NSInteger index, dispatch_block_t disenableScale))scrollTo
                         longPress:(nullable void(^)(NSInteger index, UIImage *image, JYImageBrowser *controller))longPress
                           dismiss:(dispatch_block_t)dismiss
{
    self = [super init];
    if (self) {
        self.fromImageView = fromImageView;
        self.currentIndex = browserIndex;
        if (self.currentIndex >= imageCount) {
            self.currentIndex = imageCount - 1;
        }
        self.imageCount = imageCount;
        self.setImage = setImage;
        self.scrollTo = scrollTo;
        self.longPress = longPress;
        self.dismiss = dismiss;
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
}

- (void)setCurrentIndex:(NSInteger)currentIndex {
    _currentIndex = currentIndex;
    self.pageControl.currentPage = currentIndex;
}

- (void)creatUI {
    self.view.superview.userInteractionEnabled = NO;
    self.view.backgroundColor = [UIColor blackColor];
    UIImageView *fromView;
    if (self.fromImageView) {
        fromView = self.fromImageView(self.currentIndex);
    }
    if (fromView) {
        CGRect toWindowRect = [fromView convertRect:fromView.bounds toView:UIApplication.sharedApplication.keyWindow];
        CGFloat scaleWidth = fromView.bounds.size.width;
        if (fromView.image && fromView.image.size.width >= fromView.image.size.height) {
            scaleWidth = fromView.image.size.width / fromView.image.size.height * fromView.bounds.size.height;
        }
        CGFloat scale = scaleWidth / self.view.bounds.size.width;
        self.view.maskView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, self.view.bounds.size.width * (fromView.bounds.size.width / scaleWidth), fromView.bounds.size.height / fromView.bounds.size.width * self.view.bounds.size.width * (fromView.bounds.size.width / scaleWidth))];
        self.view.maskView.backgroundColor = UIColor.blackColor;
        self.view.maskView.center = CGPointMake(self.view.bounds.size.width / 2, self.view.bounds.size.height / 2);
        self.view.maskView.layer.cornerRadius = fromView.layer.cornerRadius / fromView.bounds.size.width * self.view.maskView.bounds.size.width;
        self.view.maskView.clipsToBounds = YES;
        self.view.transform = CGAffineTransformMakeScale(scale, scale);
        self.view.center = CGPointMake(CGRectGetMidX(toWindowRect), CGRectGetMidY(toWindowRect));
    }
    
    UICollectionViewFlowLayout *layout = [[UICollectionViewFlowLayout alloc] init];
    layout.scrollDirection = UICollectionViewScrollDirectionHorizontal;
    layout.itemSize = CGSizeMake(self.view.bounds.size.width - 2, self.view.bounds.size.height);
    layout.minimumLineSpacing = 2;
    layout.minimumInteritemSpacing = 2;
    
    self.collectionView = [[UICollectionView alloc] initWithFrame:self.view.bounds collectionViewLayout:layout];
    self.collectionView.backgroundColor = UIColor.clearColor;
    self.collectionView.delegate = self;
    self.collectionView.dataSource = self;
    self.collectionView.pagingEnabled = YES;
    self.collectionView.showsVerticalScrollIndicator = NO;
    self.collectionView.showsHorizontalScrollIndicator = NO;
    [self.collectionView registerClass:[JYImageBrowserCollectionViewCell class] forCellWithReuseIdentifier:[JYImageBrowserCollectionViewCell identifier]];
    [self.view addSubview:self.collectionView];
    
    self.pageControl = [[UIPageControl alloc] initWithFrame:CGRectMake(0, CGRectGetMaxY(self.collectionView.frame) - UIApplication.sharedApplication.statusBarFrame.size.height - 10, self.collectionView.bounds.size.width, 10)];
    self.pageControl.currentPageIndicatorTintColor = JYColorHex(JYThemeOrangeColor, 1);
    self.pageControl.pageIndicatorTintColor = UIColor.lightGrayColor;
    self.pageControl.numberOfPages = self.imageCount;
    self.pageControl.currentPage = self.currentIndex;
    [self.view addSubview:self.pageControl];
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.collectionView layoutIfNeeded];
            NSIndexPath *indexPath = [NSIndexPath indexPathForRow:self.currentIndex inSection:0];
            [self.collectionView scrollToItemAtIndexPath:indexPath atScrollPosition:UICollectionViewScrollPositionLeft animated:NO];
            [self.collectionView layoutIfNeeded];
            JYImageBrowserCollectionViewCell *cell = (JYImageBrowserCollectionViewCell *)[self.collectionView cellForItemAtIndexPath:indexPath];
            cell.disenableScale = NO;
            dispatch_block_t disenableScale = ^(void) {
                cell.disenableScale = YES;
            };
            !self.scrollTo ?: self.scrollTo(cell, self.currentIndex, disenableScale);
            if (fromView) {
                [UIView animateWithDuration:0.3 animations:^{
                    self.view.transform = CGAffineTransformIdentity;
                    self.view.center = self.view.superview.center;
                    self.view.maskView.bounds = self.view.bounds;
                    self.view.maskView.center = self.view.center;
                    self.view.maskView.layer.cornerRadius = 0;
                } completion:^(BOOL finished) {
                    self.view.superview.userInteractionEnabled = YES;
                }];
            }
            else {
                self.view.jy_y = self.view.jy_height;
                [UIView animateWithDuration:0.3 animations:^{
                    self.view.jy_y = 0;
                } completion:^(BOOL finished) {
                    self.view.superview.userInteractionEnabled = YES;
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
            JYImageBrowserCollectionViewCell *beforeCell = (JYImageBrowserCollectionViewCell *)[self.collectionView cellForItemAtIndexPath:[NSIndexPath indexPathForItem:self.currentIndex inSection:0]];
            beforeCell.disenableScale = NO;
            [self.collectionView reloadItemsAtIndexPaths:@[[NSIndexPath indexPathForItem:self.currentIndex inSection:0]]];
            self.currentIndex = index;
            if (self.scrollTo) {
                JYImageBrowserCollectionViewCell *cell = (JYImageBrowserCollectionViewCell *)[self.collectionView cellForItemAtIndexPath:[NSIndexPath indexPathForItem:self.currentIndex inSection:0]];
                cell.disenableScale = NO;
                dispatch_block_t disenableScale = ^(void) {
                    cell.disenableScale = YES;
                };
                !self.scrollTo ?: self.scrollTo(cell, self.currentIndex, disenableScale);
            }
        }
    }
}

- (nonnull __kindof UICollectionViewCell *)collectionView:(nonnull UICollectionView *)collectionView cellForItemAtIndexPath:(nonnull NSIndexPath *)indexPath {
    JYImageBrowserCollectionViewCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:[JYImageBrowserCollectionViewCell identifier] forIndexPath:indexPath];
    cell.jy_imageBrowser = self;
    cell.delegate = self;
    if (!self.scrollTo) {
        cell.disenableScale = NO;
    }
    [cell reloadCell];
    if (self.setImage) {
        self.setImage(cell.imageView, indexPath.item, self);
    }
    return cell;
}

- (NSInteger)collectionView:(nonnull UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
    return self.imageCount;
}

- (void)browserCell:(JYImageBrowserCollectionViewCell *)cell didLongPressWithImage:(UIImage *)image {
    if (self.longPress) {
        NSIndexPath *indexPath = [self.collectionView indexPathForCell:cell];
        self.longPress(indexPath.item, image, self);
    }
}

- (void)browserCell:(JYImageBrowserCollectionViewCell *)cell dissmissProgress:(CGFloat)progress {
    UIImageView *fromView;
    if (self.fromImageView) {
        fromView = self.fromImageView(self.currentIndex);
    }
    if (fromView) {
        CGRect toWindowRect = [fromView convertRect:fromView.bounds toView:self.view.superview];
        CGFloat scaleWidth = fromView.bounds.size.width;
        CGFloat height = fromView.bounds.size.height / fromView.bounds.size.width * self.view.bounds.size.width;
        if (fromView.image && fromView.image.size.width >= fromView.image.size.height) {
            scaleWidth = fromView.image.size.width / fromView.image.size.height * fromView.bounds.size.height;
            height = fromView.bounds.size.height / scaleWidth * self.view.bounds.size.width;
        }
        
        CGFloat zoomScale = 1;
        CGFloat widthScale = fromView.bounds.size.width / scaleWidth;
        CGFloat cornerRadius = fromView.layer.cornerRadius;
        CGFloat scale = scaleWidth / self.view.bounds.size.width;
        CGPoint center = CGPointMake(CGRectGetMidX(toWindowRect), CGRectGetMidY(toWindowRect));
        
        zoomScale = (cell.panStartZoomScale - 1) * (1 - progress) + 1;
        widthScale = (1 - widthScale) * (1 - progress) + widthScale;
        height = (self.view.bounds.size.height - height) * (1 - progress) + height;
        cornerRadius = progress * cornerRadius;
        scale = (1 - scale) * (1 - progress) + scale;
        center.x = (self.view.superview.bounds.size.width / 2 - center.x) * (1 - progress) + center.x;
        center.y = (self.view.superview.bounds.size.height / 2 - center.y) * (1 - progress) + center.y;
        
        JYImageBrowserCollectionViewCell *cell = (JYImageBrowserCollectionViewCell *)[self.collectionView cellForItemAtIndexPath:[NSIndexPath indexPathForItem:self.currentIndex inSection:0]];
        cell.scrollView.zoomScale = zoomScale;
        
        self.view.maskView.frame = CGRectMake(0, self.view.bounds.size.height / 2 - height / 2, self.view.bounds.size.width * widthScale, height);
        self.view.maskView.layer.cornerRadius = cornerRadius;
        self.view.transform = CGAffineTransformMakeScale(scale, scale);
        self.view.center = center;
    }
    else {
        self.view.jy_y = self.view.superview.jy_height * progress;
    }
}

- (void)browserCellDissmiss {
    [self action_back];
}

- (void)action_back {
    self.setImage = nil;
    self.longPress = nil;
    UIImageView *fromView;
    if (self.fromImageView) {
        fromView = self.fromImageView(self.currentIndex);
    }
    [UIView animateWithDuration:0.3 animations:^{
        if (fromView) {
            CGRect toWindowRect = [fromView convertRect:fromView.bounds toView:self.view.superview];
            CGFloat scaleWidth = fromView.bounds.size.width;
            CGFloat height = fromView.bounds.size.height / fromView.bounds.size.width * self.view.bounds.size.width;
            if (fromView.image && fromView.image.size.width >= fromView.image.size.height) {
                scaleWidth = fromView.image.size.width / fromView.image.size.height * fromView.bounds.size.height;
                height = fromView.bounds.size.height / scaleWidth * self.view.bounds.size.width;
            }
            CGFloat scale = scaleWidth / self.view.bounds.size.width;
            JYImageBrowserCollectionViewCell *cell = (JYImageBrowserCollectionViewCell *)[self.collectionView cellForItemAtIndexPath:[NSIndexPath indexPathForItem:self.currentIndex inSection:0]];
            cell.scrollView.contentOffset = CGPointMake(0, cell.scrollView.contentSize.height / 2 - cell.scrollView.bounds.size.height / 2);
            cell.scrollView.zoomScale = 1;
            
            self.view.maskView.frame = CGRectMake(0, 0, self.view.bounds.size.width * (fromView.bounds.size.width / scaleWidth), height);
            self.view.maskView.center = CGPointMake(self.view.bounds.size.width / 2, self.view.bounds.size.height / 2);
            self.view.maskView.layer.cornerRadius = fromView.layer.cornerRadius;
            self.view.transform = CGAffineTransformMakeScale(scale, scale);
            self.view.center = CGPointMake(CGRectGetMidX(toWindowRect), CGRectGetMidY(toWindowRect));
        }
        else {
            self.view.jy_y = self.view.superview.jy_height;
        }
    } completion:^(BOOL finished) {
        !self.dismiss ?: self.dismiss();
        [self.view removeFromSuperview];
        [self removeFromParentViewController];
    }];
}

@end
