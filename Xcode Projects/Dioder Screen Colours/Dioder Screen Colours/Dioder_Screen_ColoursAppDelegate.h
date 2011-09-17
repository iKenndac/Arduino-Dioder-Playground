//
//  Dioder_Screen_ColoursAppDelegate.h
//  Dioder Screen Colours
//
//  Created by Daniel Kennett on 14/09/2011.
//  Copyright 2011 Daniel Kennett. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "ArduinoDioderCommunicationController.h"

typedef enum {
    kScreenSamplingPickAPixel = 0,
    kScreenSamplingAverageRGB,
    kScreenSamplingAverageHue
} ScreenSamplingMode;

@interface Dioder_Screen_ColoursAppDelegate : NSObject <NSApplicationDelegate> {
    NSWindow *window;
}

@property (assign) IBOutlet NSWindow *window;

@property (readwrite, retain, nonatomic) ArduinoDioderCommunicationController *commsController;
@property (readwrite, retain, nonatomic) NSArray *ports;
@property (readwrite, retain, nonatomic) NSImage *image;

@property (readwrite, nonatomic) ScreenSamplingMode screenSamplingAlgorithm;
@property (readwrite, nonatomic) BOOL avoidRenderingIfPossible;

@property (readwrite, retain, nonatomic) NSColor *channel1Color;
@property (readwrite, retain, nonatomic) NSColor *channel2Color;
@property (readwrite, retain, nonatomic) NSColor *channel3Color;
@property (readwrite, retain, nonatomic) NSColor *channel4Color;

-(void)portsChanged:(NSNotification *)aNotification;

-(void)calculateColoursOfImage:(CGImageRef)imageRef;
-(void)calculateColoursOfImageWithPickAPixel:(CGImageRef)imageRef;
-(void)calculateColoursOfImageWithAverageRGB:(CGImageRef)imageRef;
-(void)calculateColoursOfImageWithAverageHue:(CGImageRef)imageRef;
-(void)sendColours;

-(NSColor *)colorFromFirstPixelOfCIImage:(CIImage *)ciImage;
-(void)setPreviewImageWithBitmapImageRep:(NSBitmapImageRep *)rep;

@end
