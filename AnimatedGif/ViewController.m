//
//  ViewController.m
//  AnimatedGif
//
//  Created by David Baum on 9/21/18.
//  Copyright © 2018 David Baum. All rights reserved.
//

#import "ViewController.h"
#import "AnimatedGifManager.h"

@interface ViewController ()

@property (nonatomic, weak) IBOutlet UIImageView *gifImageView;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    NSDataAsset *gifAsset = [[NSDataAsset alloc] initWithName:@"trump_gif"];
    [[AnimatedGifManager sharedManager] initImageView:self.gifImageView withGifImageDate:gifAsset.data];
    [self.gifImageView startAnimating];
}


@end
