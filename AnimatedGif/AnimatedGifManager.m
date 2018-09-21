//
//  AnimatedGifManager.m
//  AnimatedGifManager
//
//  Created by David Baum on 9/21/18.
//  Copyright © 2018 David Baum. All rights reserved.
//
#import "AnimatedGifManager.h"

#define GIF_TYPE        @"GIF89a"

@interface AnimatedGifManager ()

@property (nonatomic, strong) NSData *gifPointerData;
@property (nonatomic, strong) NSMutableData *gifBufferData;
@property (nonatomic, strong) NSMutableData *gifScreenData;
@property (nonatomic, strong) NSMutableData *gifGlobalData;
@property (nonatomic, strong) NSMutableData *gifStringData;
@property (nonatomic, strong) NSMutableData *gifFrameHeaderData;

@property (nonatomic, strong) NSMutableArray *gifDelaysArray;
@property (nonatomic, strong) NSMutableArray *gifFramesArray;
@property (nonatomic, strong) NSMutableArray *gifTransparanciesArray;

@property (nonatomic, assign) int GIF_sorted;
@property (nonatomic, assign) int GIF_colorS;
@property (nonatomic, assign) int GIF_colorC;
@property (nonatomic, assign) int GIF_colorF;
@property (nonatomic, assign) int animatedGifDelay;

@property (nonatomic, assign) int dataPointer;
@property (nonatomic, assign) int frameCounter;

@end

@implementation AnimatedGifManager

+ (id)sharedManager {
    static AnimatedGifManager *sharedMyManager = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedMyManager = [[self alloc] init];
    });
    return sharedMyManager;
}

// the decoder
// decodes GIF image data into separate frames
// based on the Wikipedia Documentation at:
//
// http://en.wikipedia.org/wiki/Graphics_Interchange_Format#Example_.gif_file
// http://en.wikipedia.org/wiki/Graphics_Interchange_Format#Animated_.gif
//
- (void)decodeGIF:(NSData *)GIFData  {
    self.gifPointerData = [NSData dataWithData:GIFData];
    
    [self.gifBufferData setData:[NSData data]];
    [self.gifScreenData setData:[NSData data]];
    [self.gifDelaysArray removeAllObjects];
    [self.gifFramesArray removeAllObjects];
    [self.gifStringData setData:[NSData data]];
    [self.gifGlobalData setData:[NSData data]];
    
    self.dataPointer = 0;
    self.frameCounter = 0;
    
    [self GIFGetBytes:6]; // GIF89a
    [self GIFGetBytes:7]; // Logical Screen Descriptor
    
    [self.gifScreenData setData:self.gifBufferData];
    
    size_t length = [self.gifBufferData length];
    unsigned char aBuffer[length];
    [self.gifBufferData getBytes:aBuffer length:length];
    
    if (aBuffer[4] & 0x80) self.GIF_colorF = 1; else self.GIF_colorF = 0;
    if (aBuffer[4] & 0x08) self.GIF_sorted = 1; else self.GIF_sorted = 0;
    self.GIF_colorC = (aBuffer[4] & 0x07);
    self.GIF_colorS = 2 << self.GIF_colorC;
    
    if (self.GIF_colorF == 1) {
        [self GIFGetBytes:(3 * self.GIF_colorS)];
        [self.gifGlobalData setData:self.gifBufferData];
    }
    
    unsigned char bBuffer[1];
    for (bool notdone = true; notdone;) {
        if ([self GIFGetBytes:1] == 1) {
            
            [self.gifBufferData getBytes:bBuffer length:1];
            
            switch (bBuffer[0]) {
                case 0x21:
                    // Graphic Control Extension (#n of n)
                    [self GIFReadExtensions];
                    break;
                case 0x2C:
                    // Image Descriptor (#n of n)
                    [self GIFReadDescriptor];
                    break;
                case 0x3B:
                    notdone = false;
                    break;
            }
        } else {
            break;
        }
    }
    
    // clean up stuff
    [self.gifBufferData setData:[NSData data]];
    [self.gifScreenData setData:[NSData data]];
    [self.gifStringData setData:[NSData data]];
    [self.gifGlobalData setData:[NSData data]];
}

//
// Returns a subframe as NSMutableData.
// Returns nil when frame does not exist.
//
// Use this to write a subframe to the filesystems (cache etc);
- (NSMutableData*) getFrameAsDataAtIndex:(int)index {
    if (index < [self.gifFramesArray count]) {
        return [self.gifFramesArray objectAtIndex:index];
    } else {
        return nil;
    }
}

/*
 * Returns a subframe as an UIImage.
 * Returns nil when frame does not exist.
 *
 * Use this to put a subframe on your GUI.
 */
- (UIImage*) getFrameAsImageAtIndex:(int)index {
    if (index < [self.gifFramesArray count]) {
        UIImage *image = [UIImage imageWithData:[self getFrameAsDataAtIndex: index]];
        
        return image;
        
    } else {
        return nil;
    }
}

/*
 * Returns a subframes as NSArray
 *
 * Use this to put a subframes on your GUI UIImageView.
 */
- (NSArray*) getImageFrames {
    NSMutableArray *frames = [[NSMutableArray alloc] init];
    for(NSData *data in self.gifFramesArray) {
        [frames addObject:[UIImage imageWithData:data]];
    }
    
    return frames;
}

/*
 * This method converts the arrays of GIF data to an animation, counting
 * up all the seperate frame delays, and setting that to the total duration
 * since the iPhone Cocoa framework does not allow you to set per frame
 * delays.
 */

- (void) initImageView:(UIImageView *)imageView withGifImageDate:(NSData *)gifData {
    self.gifBufferData = [NSMutableData data];
    self.gifScreenData = [NSMutableData data];
    self.gifStringData = [NSMutableData data];
    self.gifGlobalData = [NSMutableData data];
    
    self.gifFramesArray = [NSMutableArray array];
    self.gifTransparanciesArray = [NSMutableArray array];
    
    if(gifData != nil) {
        [self decodeGIF:gifData];
        if ([self.gifFramesArray count] > 0) {
            // Add all subframes to the animation
            NSMutableArray *array = [NSMutableArray array];
            for (int i = 0; i < [self.gifFramesArray count]; i++) {
                [array addObject: [self getFrameAsImageAtIndex:i]];
                
            }
            
            [imageView setAnimationImages:array];
            
            // Count up the total delay, since Cocoa doesn't do per frame delays.
            NSTimeInterval total = 0;
            for (int i = 0; i < [self.gifDelaysArray count]; i++) {
                total += [[self.gifDelaysArray objectAtIndex:i] doubleValue];
            }
            
            // GIFs store the delays as 1/100th of a second.
            [imageView setAnimationDuration:total/100];
            
            // Repeat infinite
            [imageView setAnimationRepeatCount:0];
        }
    }
}

- (void)GIFReadExtensions {
    // 21! But we still could have an Application Extension,
    // so we want to check for the full signature.
    unsigned char cur[1], prev[1];
    for ( ; ; ) {
        [self GIFGetBytes:1];
        [self.gifBufferData getBytes:cur length:1];
        
        if (cur[0] == 0x00) {
            break;
        }
        
        // TODO: Known bug, the sequence F9 04 could occur in the Application Extension, we
        //       should check whether this combo follows directly after the 21.
        if (cur[0] == 0x04 && prev[0] == 0xF9) {
            [self GIFGetBytes:5];
            
            unsigned char bBuffer[5];
            [self.gifBufferData getBytes:bBuffer length:5];
            
            // We save the delays for easy access.
            [self.gifDelaysArray addObject:[NSNumber numberWithInt:(bBuffer[1] | bBuffer[2] << 8)]];
            
            // We save the transparent color for easy access.
            [self.gifTransparanciesArray addObject:[NSNumber numberWithInt:bBuffer[3]]];
            
            if (self.gifFrameHeaderData == nil) {
                unsigned char board[8];
                board[0] = 0x21;
                board[1] = 0xF9;
                board[2] = 0x04;
                
                for(int i = 3, a = 0; a < 5; i++, a++) {
                    board[i] = bBuffer[a];
                }
                self.gifFrameHeaderData = [NSMutableData dataWithBytesNoCopy:board length:8 freeWhenDone:NO];
            }
            
            break;
        }
        
        prev[0] = cur[0];
    }
}

- (void)GIFReadDescriptor {
    [self GIFGetBytes:9];
    NSMutableData *GIF_screenTmp = [NSMutableData dataWithData:self.gifBufferData];
    
    unsigned char aBuffer[9];
    [self.gifBufferData getBytes:aBuffer length:9];
    
    if (aBuffer[8] & 0x80) self.GIF_colorF = 1; else self.GIF_colorF = 0;
    
    unsigned char GIF_code, GIF_sort;
    
    if (self.GIF_colorF == 1) {
        GIF_code = (aBuffer[8] & 0x07);
        if (aBuffer[8] & 0x20) GIF_sort = 1; else GIF_sort = 0;
    } else {
        GIF_code = self.GIF_colorC;
        GIF_sort = self.GIF_sorted;
    }
    
    int GIF_size = (2 << GIF_code);
    
    size_t blength = [self.gifScreenData length];
    unsigned char bBuffer[blength];
    [self.gifScreenData getBytes:bBuffer length:blength];
    
    bBuffer[4] = (bBuffer[4] & 0x70);
    bBuffer[4] = (bBuffer[4] | 0x80);
    bBuffer[4] = (bBuffer[4] | GIF_code);
    
    if (GIF_sort) {
        bBuffer[4] |= 0x08;
    }
    
    [self.gifStringData setData:[GIF_TYPE dataUsingEncoding: NSUTF8StringEncoding]];
    [self.gifScreenData setData:[NSData dataWithBytes:bBuffer length:blength]];
    
    [self GIFPutBytes:self.gifScreenData];
    
    if (self.GIF_colorF == 1) {
        [self GIFGetBytes:(3 * GIF_size)];
        [self GIFPutBytes:self.gifBufferData];
    } else {
        [self GIFPutBytes:self.gifGlobalData];
    }
    
    // Add Graphic Control Extension Frame (for transparancy)
    [self.gifStringData appendData:self.gifFrameHeaderData];
    
    char endC = 0x2c;
    [self.gifStringData appendBytes:&endC length:sizeof(endC)];
    
    size_t clength = [GIF_screenTmp length];
    unsigned char cBuffer[clength];
    [GIF_screenTmp getBytes:cBuffer length:clength];
    
    cBuffer[8] &= 0x40;
    
    [GIF_screenTmp setData:[NSData dataWithBytes:cBuffer length:clength]];
    
    [self GIFPutBytes:GIF_screenTmp];
    [self GIFGetBytes:1];
    [self GIFPutBytes:self.gifBufferData];
    
    for ( ; ; ) {
        [self GIFGetBytes:1];
        [self GIFPutBytes:self.gifBufferData];
        
        size_t dlength = [self.gifBufferData length];
        unsigned char dBuffer[1];
        [self.gifBufferData getBytes:dBuffer length:dlength];
        
        int u = (int)dBuffer[0];
        if (u == 0x00) {
            break;
        }
        [self GIFGetBytes:u];
        [self GIFPutBytes:self.gifBufferData];
    }
    
    endC = 0x3b;
    [self.gifStringData appendBytes:&endC length:sizeof(endC)];
    
    // save the frame into the array of frames
    [self.gifFramesArray addObject:[self.gifStringData copy]];
}

- (int)GIFGetBytes:(int)length {
    [self.gifBufferData setData:[NSData data]];
    
    if ([self.gifPointerData length] >= self.dataPointer + length) {
        [self.gifBufferData setData:[self.gifPointerData subdataWithRange:NSMakeRange(self.dataPointer, length)]];
        self.dataPointer += length;
        return 1;
    } else {
        return 0;
    }
}

- (void)GIFPutBytes:(NSData *)bytes {
    [self.gifStringData appendData:bytes];
}

@end
