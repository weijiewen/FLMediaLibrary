//
//  FLImageBrowserDelegate.h
//  FLMediaLibrary
//
//  Created by weijiewen on 2022/4/17.
//  Copyright © 2022 weijiwen. All rights reserved.
//

#ifndef FLImageBrowserDelegate_h
#define FLImageBrowserDelegate_h

#import <UIKit/UIKit.h>
@protocol FLImageBrowserPlayer <NSObject>
@required
- (void)play;
- (void)pause;
- (BOOL)isPause;
@end

#endif /* FLImageBrowserDelegate_h */
