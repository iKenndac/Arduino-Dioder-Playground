//
//  Dioder_Screen_ColoursAppDelegate.m
//  Dioder Screen Colours
//
//  Created by Daniel Kennett on 14/09/2011.
//  Copyright 2011 KennettNet Software Limited. All rights reserved.
//

#import "Dioder_Screen_ColoursAppDelegate.h"
#import "AMSerialPortList.h"

void screenDidUpdate(CGRectCount count, const CGRect *rectArray, void *userParameter);
static NSTimeInterval const kScreenshotFrequency = 0.05;
static NSDate *lastShotTaken;

@implementation Dioder_Screen_ColoursAppDelegate

@synthesize window;
@synthesize commsController;
@synthesize ports;
@synthesize image;

@synthesize channel1Color;
@synthesize channel2Color;
@synthesize channel3Color;
@synthesize channel4Color;

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    // Insert code here to initialize your application
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(portsChanged:)
                                                 name:AMSerialPortListDidAddPortsNotification
                                               object:[AMSerialPortList sharedPortList]];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(portsChanged:)
                                                 name:AMSerialPortListDidRemovePortsNotification
                                               object:[AMSerialPortList sharedPortList]];
    
    self.commsController = [[[ArduinoDioderCommunicationController alloc] init] autorelease];
    
    [self portsChanged:nil];
    lastShotTaken = nil;
    
    CGRegisterScreenRefreshCallback(screenDidUpdate, self);

}

-(void)portsChanged:(NSNotification *)aNotification {
    self.ports = [[[AMSerialPortList sharedPortList] serialPorts] sortedArrayUsingComparator:^(id a, id b) {
        return [[a name] caseInsensitiveCompare:[b name]];
    }];
}

-(void)applicationWillTerminate:(NSNotification *)notification {
    self.commsController = nil;
    CGUnregisterScreenRefreshCallback(screenDidUpdate, self);
}

#pragma mark -
#pragma mark Screen Monitoring

void screenDidUpdate(CGRectCount count, const CGRect *rectArray, void *userParameter) {
    
    Dioder_Screen_ColoursAppDelegate *self = userParameter;
    
    if (lastShotTaken == nil)
        lastShotTaken = [NSDate new];
    
    if ([[NSDate date] timeIntervalSinceDate:lastShotTaken] < kScreenshotFrequency)
        return;

    CGImageRef screenShot = CGWindowListCreateImage(CGRectInfinite, kCGWindowListOptionOnScreenOnly, kCGNullWindowID, kCGWindowImageDefault);
    [lastShotTaken release];
    lastShotTaken = [NSDate new];
    
    CGSize scaledSize = (CGSize){50.0, 50.0};
    NSUInteger bytesPerPixel = 4;
    
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    unsigned char *rawData = malloc(scaledSize.height * scaledSize.width * bytesPerPixel);
        
    NSUInteger bytesPerRow = bytesPerPixel * scaledSize.width;
    CGContextRef context = CGBitmapContextCreate(rawData, scaledSize.width, scaledSize.height, 8, bytesPerRow, colorSpace, kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big);
    CGColorSpaceRelease(colorSpace);
    
    CGContextDrawImage(context, (CGRect){ CGPointZero, scaledSize }, screenShot);
    CGContextRelease(context);
    CGImageRelease(screenShot);
    
    NSUInteger kBottomMiddle = ((50 * 50) - 25) * bytesPerPixel;
    NSUInteger kTopMiddle = ((50 * 5) + 25) * bytesPerPixel;
    NSUInteger kLeftMiddle = ((50 * 25) + 5) * bytesPerPixel;
    NSUInteger kRightMiddle = ((50 * 25) + 45) * bytesPerPixel;
    
    NSBitmapImageRep *rep = [[NSBitmapImageRep alloc] initWithBitmapDataPlanes:(unsigned char **)&rawData
                                                             pixelsWide:scaledSize.width
                                                             pixelsHigh:scaledSize.height
                                                          bitsPerSample:8
                                                        samplesPerPixel:bytesPerPixel
                                                               hasAlpha:YES
                                                               isPlanar:NO
                                                         colorSpaceName:NSDeviceRGBColorSpace
                                                           bitmapFormat:NSAlphaNonpremultipliedBitmapFormat
                                                            bytesPerRow:bytesPerRow
                                                           bitsPerPixel:8 * bytesPerPixel];
    
    NSImage *image = [[NSImage alloc] initWithSize:NSSizeFromCGSize(scaledSize)];
    [image addRepresentation:rep];
    [self setImage:image];
    [rep release];
    [image release];
    
    self.channel1Color = [NSColor colorWithCalibratedRed:(rawData[kBottomMiddle] * 1.0) / 255.0
                                                   green:(rawData[kBottomMiddle + 1] * 1.0) / 255.0
                                                    blue:(rawData[kBottomMiddle + 2] * 1.0) / 255.0
                                                   alpha:1.0];
    
    self.channel2Color = [NSColor colorWithCalibratedRed:(rawData[kTopMiddle] * 1.0) / 255.0
                                                   green:(rawData[kTopMiddle + 1] * 1.0) / 255.0
                                                    blue:(rawData[kTopMiddle + 2] * 1.0) / 255.0
                                                   alpha:1.0];
    
    self.channel3Color = [NSColor colorWithCalibratedRed:(rawData[kLeftMiddle] * 1.0) / 255.0
                                                   green:(rawData[kLeftMiddle + 1] * 1.0) / 255.0
                                                    blue:(rawData[kLeftMiddle + 2] * 1.0) / 255.0
                                                   alpha:1.0];
    
    self.channel4Color = [NSColor colorWithCalibratedRed:(rawData[kRightMiddle] * 1.0) / 255.0
                                                   green:(rawData[kRightMiddle + 1] * 1.0) / 255.0
                                                    blue:(rawData[kRightMiddle + 2] * 1.0) / 255.0
                                                   alpha:1.0];
    
    [self performSelectorOnMainThread:@selector(sendColours)
                           withObject:nil
                        waitUntilDone:YES];
    
    
   free(rawData);
}

-(void)sendColours {
    [self.commsController pushColorsToChannel1:self.channel1Color
                                      channel2:self.channel2Color
                                      channel3:self.channel3Color
                                      channel4:self.channel4Color];
}


@end
