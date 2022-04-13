//
//  FLProgressView.m
//  FLMediaLibrary_Example
//
//  Created by weijiewen on 2022/4/12.
//  Copyright © 2022 weijiwen. All rights reserved.
//

#import "FLProgressView.h"

@interface FLProgressView ()
@property (nonatomic, strong) CAShapeLayer *cacheLayer;
@property (nonatomic, strong) CAShapeLayer *progressLayer;
@end
@implementation FLProgressView

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = [UIColor colorWithWhite:0.7 alpha:1];
        self.cacheLayer = CAShapeLayer.layer;
        self.cacheLayer.frame = self.bounds;
        self.cacheLayer.strokeEnd = 0;
        self.cacheLayer.fillColor = UIColor.clearColor.CGColor;
        self.cacheLayer.strokeColor = UIColor.orangeColor.CGColor;
        self.cacheLayer.lineWidth = frame.size.height;
        [self.layer addSublayer:self.cacheLayer];
        
        self.progressLayer = CAShapeLayer.layer;
        self.progressLayer.frame = self.bounds;
        self.progressLayer.strokeEnd = 0;
        self.progressLayer.fillColor = UIColor.clearColor.CGColor;
        self.progressLayer.strokeColor = UIColor.blueColor.CGColor;
        self.progressLayer.lineWidth = frame.size.height;
        [self.layer addSublayer:self.progressLayer];
        
        UIBezierPath *path = UIBezierPath.bezierPath;
        [path moveToPoint:CGPointMake(0, frame.size.height / 2)];
        [path addLineToPoint:CGPointMake(frame.size.width, frame.size.height / 2)];
        self.cacheLayer.path = path.CGPath;
        self.progressLayer.path = path.CGPath;
    }
    return self;
}

- (void)setCache:(CGFloat)cache {
    self.cacheLayer.strokeEnd = cache;
}
- (void)setProgress:(CGFloat)progress {
    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    self.progressLayer.strokeEnd = progress;
    [CATransaction commit];
}

@end
