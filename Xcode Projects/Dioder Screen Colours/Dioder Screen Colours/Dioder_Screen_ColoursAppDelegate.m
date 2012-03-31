//
//  Dioder_Screen_ColoursAppDelegate.m
//  Dioder Screen Colours
//
//  Created by Daniel Kennett on 14/09/2011.
//  Copyright 2011 Daniel Kennett. All rights reserved.
//

#import "Dioder_Screen_ColoursAppDelegate.h"
#import "DKSerialPort.h"
#import <QuartzCore/QuartzCore.h>

void screenDidUpdate(CGRectCount count, const CGRect *rectArray, void *userParameter);

static NSTimeInterval const kScreenshotFrequency = 0.05;
static CGFloat const kScreenColourCalculationInsetFraction = 0.25;

static NSDate *lastShotTaken;

@implementation Dioder_Screen_ColoursAppDelegate

@synthesize window;
@synthesize commsController;
@synthesize ports;
@synthesize image;

@synthesize screenSamplingAlgorithm;
@synthesize avoidRenderingIfPossible;

@synthesize channel1Color;
@synthesize channel2Color;
@synthesize channel3Color;
@synthesize channel4Color;

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    // Insert code here to initialize your application
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(portsChanged:)
                                                 name:DKSerialPortsDidChangeNotification
                                               object:nil];
    
    self.commsController = [[[ArduinoDioderCommunicationController alloc] init] autorelease];
    
    [self portsChanged:nil];
    lastShotTaken = nil;
    
    CGRegisterScreenRefreshCallback(screenDidUpdate, self);

}


-(void)portsChanged:(NSNotification *)aNotification {
    self.ports = [[DKSerialPort availableSerialPorts] sortedArrayUsingComparator:^(id a, id b) {
        return [[a name] caseInsensitiveCompare:[b name]];
    }];
}

-(void)applicationWillTerminate:(NSNotification *)notification {
    [[NSNotificationCenter defaultCenter] removeObserver:self name:DKSerialPortsDidChangeNotification object:nil];
    self.commsController = nil;
    CGUnregisterScreenRefreshCallback(screenDidUpdate, self);
}

#pragma mark -
#pragma mark Screen Monitoring

void screenDidUpdate(CGRectCount count, const CGRect *rectArray, void *userParameter) {
    
    Dioder_Screen_ColoursAppDelegate *self = userParameter;
    
    // Always assume main screen
    NSScreen *mainScreen = [[NSScreen screens] objectAtIndex:0];
    
    CGRect topBar = CGRectMake(0.0, 0.0, mainScreen.frame.size.width, mainScreen.frame.size.height * kScreenColourCalculationInsetFraction);
    CGRect bottomBar = CGRectMake(0.0, mainScreen.frame.size.height - topBar.size.height, topBar.size.width, topBar.size.height);
    CGRect leftBar = CGRectMake(0.0, 0.0, mainScreen.frame.size.width * kScreenColourCalculationInsetFraction, mainScreen.frame.size.height);
    CGRect rightBar = CGRectMake(mainScreen.frame.size.width - leftBar.size.width, 0.0, leftBar.size.width, leftBar.size.height);
    
    for (NSUInteger currentChangedFrame = 0; currentChangedFrame < count; currentChangedFrame++) {
        
        CGRect changedRect = rectArray[currentChangedFrame];
        
        if (CGRectIntersectsRect(changedRect, topBar) ||
            CGRectIntersectsRect(changedRect, bottomBar) ||
            CGRectIntersectsRect(changedRect, leftBar) ||
            CGRectIntersectsRect(changedRect, rightBar)) {
            [self updateScreenColoursIfAppropriate];
            return;
        }
    }
    //NSLog(@"[%@ %@]: %@", NSStringFromClass([self class]), @"screenDidUpdate", @"Change occurred but we don't care!");
}

-(void)updateScreenColoursIfAppropriate {
    if (lastShotTaken == nil)
        lastShotTaken = [NSDate new];
    
    if ([[NSDate date] timeIntervalSinceDate:lastShotTaken] < kScreenshotFrequency)
        return;
    
    CGImageRef screenShot = CGWindowListCreateImage(CGRectInfinite, kCGWindowListOptionOnScreenOnly, kCGNullWindowID, kCGWindowImageDefault);
    CGImageRef screenShot = CGDisplayCreateImage(CGMainDisplayID());
    [lastShotTaken release];
    lastShotTaken = [NSDate new];
    
    [self calculateColoursOfImage:screenShot];
    CGImageRelease(screenShot);
}

#pragma mark -
#pragma mark Image Calculations

-(void)calculateColoursOfImage:(CGImageRef)imageRef {
    
    switch (self.screenSamplingAlgorithm) {
        case kScreenSamplingPickAPixel:
            [self calculateColoursOfImageWithPickAPixel:imageRef];
            break;
        case kScreenSamplingAverageRGB:
            [self calculateColoursOfImageWithAverageRGB:imageRef];
            break;
        case kScreenSamplingAverageHue:
            [self calculateColoursOfImageWithAverageHue:imageRef];
            break;
        default:
            break;
    }
}

-(void)calculateColoursOfImageWithPickAPixel:(CGImageRef)imageRef {
    
    NSBitmapImageRep *rep = [[NSBitmapImageRep alloc] initWithCGImage:imageRef];
    NSUInteger pixelInset = 128;
        
    self.channel1Color = [rep colorAtX:rep.pixelsWide / 2
                                     y:rep.pixelsHigh - pixelInset];
    
    self.channel2Color = [rep colorAtX:rep.pixelsWide / 2
                                     y:pixelInset];
    
    self.channel3Color = [rep colorAtX:pixelInset
                                     y:rep.pixelsHigh / 2];
    
    self.channel4Color = [rep colorAtX:rep.pixelsWide - pixelInset
                                     y:rep.pixelsHigh / 2];
    
    [self sendColours];
    [self setPreviewImageWithBitmapImageRep:rep];
    [rep release];
}

-(void)calculateColoursOfImageWithAverageRGB:(CGImageRef)imageRef {
    
    size_t imageWidth = CGImageGetWidth(imageRef);
    size_t imageHeight = CGImageGetHeight(imageRef);
    
    CIImage *ciImage = [CIImage imageWithCGImage:imageRef];
    CIFilter *averageFilter = [CIFilter filterWithName:@"CIAreaAverage"];
    [averageFilter setValue:ciImage forKey:@"inputImage"];

    CIVector *bottomExtent = [CIVector vectorWithX:0.0 Y:0.0 Z:imageWidth W:imageHeight * kScreenColourCalculationInsetFraction];
    CIVector *leftExtent = [CIVector vectorWithX:0.0 Y:0.0 Z:imageWidth * kScreenColourCalculationInsetFraction W:imageHeight];
    CIVector *topExtent = [CIVector vectorWithX:0.0 Y:imageHeight - (imageHeight * kScreenColourCalculationInsetFraction) Z:imageWidth W:imageHeight * kScreenColourCalculationInsetFraction];
    CIVector *rightExtent = [CIVector vectorWithX:imageWidth - (imageWidth * kScreenColourCalculationInsetFraction) Y:0.0 Z:imageWidth * kScreenColourCalculationInsetFraction W:imageHeight];
    
    // Bottom
    [averageFilter setValue:bottomExtent forKey:@"inputExtent"];
    self.channel1Color = [self colorFromFirstPixelOfCIImage:[averageFilter valueForKey:@"outputImage"]];
    
    // Top
    [averageFilter setValue:topExtent forKey:@"inputExtent"];
    self.channel2Color = [self colorFromFirstPixelOfCIImage:[averageFilter valueForKey:@"outputImage"]];
    
    // Left
    [averageFilter setValue:leftExtent forKey:@"inputExtent"];
    self.channel3Color = [self colorFromFirstPixelOfCIImage:[averageFilter valueForKey:@"outputImage"]];

    //Right
    [averageFilter setValue:rightExtent forKey:@"inputExtent"];
    self.channel4Color = [self colorFromFirstPixelOfCIImage:[averageFilter valueForKey:@"outputImage"]];
    
    [self sendColours];
    
    if (!self.avoidRenderingIfPossible)
        [self setPreviewImageWithBitmapImageRep:[[[NSBitmapImageRep alloc] initWithCIImage:ciImage] autorelease]];
}

-(void)calculateColoursOfImageWithAverageHue:(CGImageRef)imageRef {
    
    self.channel1Color = [NSColor whiteColor];
    self.channel2Color = [NSColor whiteColor];
    self.channel3Color = [NSColor whiteColor];
    self.channel4Color = [NSColor whiteColor];

    [self sendColours];
    
    if (!self.avoidRenderingIfPossible)
        [self setPreviewImageWithBitmapImageRep:[[[NSBitmapImageRep alloc] initWithCGImage:imageRef] autorelease]];
}

-(void)sendColours {
    [self.commsController pushColorsToChannel1:self.channel1Color
                                      channel2:self.channel2Color
                                      channel3:self.channel3Color
                                      channel4:self.channel4Color
                                  withDuration:0.0 /*kScreenshotFrequency * .9*/];
}

#pragma mark -
#pragma mark Image Rendering

-(NSColor *)colorFromFirstPixelOfCIImage:(CIImage *)ciImage {
    NSBitmapImageRep *rep = [[[NSBitmapImageRep alloc] initWithCIImage:ciImage] autorelease];
    return [rep colorAtX:0 y:0];
}

-(void)setPreviewImageWithBitmapImageRep:(NSBitmapImageRep *)rep {
    
    NSImage *previewImage = [[NSImage alloc] initWithSize:NSMakeSize([rep pixelsWide], [rep pixelsHigh])];
    [previewImage addRepresentation:rep];
    [self setImage:previewImage];
    [previewImage release];
}

@end
