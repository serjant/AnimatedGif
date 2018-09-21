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

@property (nonatomic, weak) IBOutlet UIImageView *gifImageView1;
@property (nonatomic, weak) IBOutlet UIImageView *gifImageView2;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    NSDataAsset *gifAsset1 = [[NSDataAsset alloc] initWithName:@"trump_gif"];
     NSDataAsset *gifAsset2 = [[NSDataAsset alloc] initWithName:@"animation"];
    
    [[AnimatedGifManager sharedManager] initImageView:self.gifImageView1 withGifImageDate:gifAsset1.data];
    [self.gifImageView1 startAnimating];
    
    [[AnimatedGifManager sharedManager] initImageView:self.gifImageView2 withGifImageDate:gifAsset2.data];
    [self.gifImageView2 startAnimating];
}


@end
