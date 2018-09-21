//
//  AnimatedGifManager.h
//  AnimatedGifManager
//
//  Created by David Baum on 9/21/18.
//  Copyright © 2018 David Baum. All rights reserved.
//
#import <UIKit/UIKit.h>

@interface AnimatedGifManager : NSObject

+ (id)sharedManager;
- (void) initImageView:(UIImageView *)imageView withGifImageDate:(NSData *)gifData;

@end
