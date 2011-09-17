//
//  Dioder_Screen_ColoursAppDelegate.m
//  Dioder Screen Colours
//
//  Created by Daniel Kennett on 14/09/2011.
//  Copyright 2011 Daniel Kennett. All rights reserved.
//

#import "Dioder_Screen_ColoursAppDelegate.h"
#import "DKSerialPort.h"

void screenDidUpdate(CGRectCount count, const CGRect *rectArray, void *userParameter);
static NSTimeInterval const kScreenshotFrequency = 0.1;
static NSDate *lastShotTaken;
static unsigned char *_imageRenderBuffer;
static size_t _bufferLength;

@implementation Dioder_Screen_ColoursAppDelegate

@synthesize window;
@synthesize commsController;
@synthesize ports;
@synthesize image;

@synthesize screenSamplingAlgorithm;

@synthesize channel1Color;
@synthesize channel2Color;
@synthesize channel3Color;
@synthesize channel4Color;

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    
    _imageRenderBuffer = NULL;
    _bufferLength = 0;
    
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
    
    if (lastShotTaken == nil)
        lastShotTaken = [NSDate new];
    
    if ([[NSDate date] timeIntervalSinceDate:lastShotTaken] < kScreenshotFrequency)
        return;

    CGImageRef screenShot = CGWindowListCreateImage(CGRectInfinite, kCGWindowListOptionOnScreenOnly, kCGNullWindowID, kCGWindowImageDefault);
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
    
    size_t imageWidth = CGImageGetWidth(imageRef);
    size_t imageHeight = CGImageGetHeight(imageRef);
    NSUInteger bytesPerPixel = 4;
    
    [self renderImage:imageRef];
        
    NSUInteger pixelInset = 128;
    
    NSUInteger kBottomMiddle = ((imageWidth * (imageHeight - pixelInset)) - (imageWidth / 2)) * bytesPerPixel;
    NSUInteger kTopMiddle = ((imageWidth * pixelInset) + (imageWidth / 2)) * bytesPerPixel;
    NSUInteger kLeftMiddle = ((imageWidth * (imageHeight / 2)) + pixelInset) * bytesPerPixel;
    NSUInteger kRightMiddle = ((imageWidth * (imageHeight / 2)) + (imageWidth - pixelInset)) * bytesPerPixel;
    
    self.channel1Color = [NSColor colorWithCalibratedRed:(_imageRenderBuffer[kBottomMiddle] * 1.0) / 255.0
                                                   green:(_imageRenderBuffer[kBottomMiddle + 1] * 1.0) / 255.0
                                                    blue:(_imageRenderBuffer[kBottomMiddle + 2] * 1.0) / 255.0
                                                   alpha:1.0];
    
    self.channel2Color = [NSColor colorWithCalibratedRed:(_imageRenderBuffer[kTopMiddle] * 1.0) / 255.0
                                                   green:(_imageRenderBuffer[kTopMiddle + 1] * 1.0) / 255.0
                                                    blue:(_imageRenderBuffer[kTopMiddle + 2] * 1.0) / 255.0
                                                   alpha:1.0];
    
    self.channel3Color = [NSColor colorWithCalibratedRed:(_imageRenderBuffer[kLeftMiddle] * 1.0) / 255.0
                                                   green:(_imageRenderBuffer[kLeftMiddle + 1] * 1.0) / 255.0
                                                    blue:(_imageRenderBuffer[kLeftMiddle + 2] * 1.0) / 255.0
                                                   alpha:1.0];
    
    self.channel4Color = [NSColor colorWithCalibratedRed:(_imageRenderBuffer[kRightMiddle] * 1.0) / 255.0
                                                   green:(_imageRenderBuffer[kRightMiddle + 1] * 1.0) / 255.0
                                                    blue:(_imageRenderBuffer[kRightMiddle + 2] * 1.0) / 255.0
                                                   alpha:1.0];
    
    [self sendColours];
    [self setPreviewImageWithWidth:imageWidth height:imageHeight];
}

-(void)calculateColoursOfImageWithAverageRGB:(CGImageRef)imageRef {
    
    size_t imageWidth = CGImageGetWidth(imageRef);
    size_t imageHeight = CGImageGetHeight(imageRef);
    NSUInteger bytesPerPixel = 4;
    
    [self renderImage:imageRef];

    CGFloat insetFraction = 0.25;
    
    NSUInteger rows = 0;
    NSUInteger columns = 0;
    
    uint64_t rgbBuffer[3] = {0, 0, 0};
    
    // Bottom
    
    rows = imageHeight * insetFraction;
    columns = imageWidth;
    
    for (NSUInteger row = imageHeight - rows; row < imageHeight; row++) {
        for (NSUInteger column = row % 2; column < columns; column += 2) {
            NSUInteger offset = ((row * imageWidth) + column) * bytesPerPixel;
            rgbBuffer[0] += _imageRenderBuffer[offset];
            rgbBuffer[1] += _imageRenderBuffer[offset + 1];
            rgbBuffer[2] += _imageRenderBuffer[offset + 2];
        }
    }
    
    self.channel1Color = [NSColor colorWithDeviceRed:(rgbBuffer[0] / (rows * (columns / 2))) / 255.0
                                               green:(rgbBuffer[1] / (rows * (columns / 2))) / 255.0
                                                blue:(rgbBuffer[2] / (rows * (columns / 2))) / 255.0
                                               alpha:1.0];
    // Top 
    
    rgbBuffer[0] = 0;
    rgbBuffer[1] = 0;
    rgbBuffer[2] = 0;
    
    rows = imageHeight * insetFraction;
    columns = imageWidth;
    
    for (NSUInteger row = 0; row < rows; row++) {
        for (NSUInteger column = row % 2; column < imageWidth; column += 2) {
            NSUInteger offset = ((row * imageWidth) + column) * bytesPerPixel;
            rgbBuffer[0] += _imageRenderBuffer[offset];
            rgbBuffer[1] += _imageRenderBuffer[offset + 1];
            rgbBuffer[2] += _imageRenderBuffer[offset + 2];
        }
    }
    
    self.channel2Color = [NSColor colorWithDeviceRed:(rgbBuffer[0] / (rows * (columns / 2))) / 255.0
                                               green:(rgbBuffer[1] / (rows * (columns / 2))) / 255.0
                                                blue:(rgbBuffer[2] / (rows * (columns / 2))) / 255.0
                                               alpha:1.0];
    
    // Left
    
    rgbBuffer[0] = 0;
    rgbBuffer[1] = 0;
    rgbBuffer[2] = 0;
    
    rows = imageHeight;
    columns = imageWidth * insetFraction;
    
    for (NSUInteger row = 0; row < imageHeight; row++) {
        for (NSUInteger column = row % 2; column < columns; column += 2) {
            NSUInteger offset = ((row * imageWidth) + column) * bytesPerPixel;
            rgbBuffer[0] += _imageRenderBuffer[offset];
            rgbBuffer[1] += _imageRenderBuffer[offset + 1];
            rgbBuffer[2] += _imageRenderBuffer[offset + 2];
        }
    }
    
    self.channel3Color = [NSColor colorWithDeviceRed:(rgbBuffer[0] / (rows * (columns / 2))) / 255.0
                                               green:(rgbBuffer[1] / (rows * (columns / 2))) / 255.0
                                                blue:(rgbBuffer[2] / (rows * (columns / 2))) / 255.0
                                               alpha:1.0];
    
    // Right
    
    rgbBuffer[0] = 0;
    rgbBuffer[1] = 0;
    rgbBuffer[2] = 0;
    
    rows = imageHeight;
    columns = imageWidth * insetFraction;
    
    for (NSUInteger row = 0; row < imageHeight; row++) {
        for (NSUInteger column = (imageWidth - columns) + (row % 2); column < imageWidth; column += 2) {
            NSUInteger offset = ((row * imageWidth) + column) * bytesPerPixel;
            rgbBuffer[0] += _imageRenderBuffer[offset];
            rgbBuffer[1] += _imageRenderBuffer[offset + 1];
            rgbBuffer[2] += _imageRenderBuffer[offset + 2];
        }
    }
    
    self.channel4Color = [NSColor colorWithDeviceRed:(rgbBuffer[0] / (rows * (columns / 2))) / 255.0
                                               green:(rgbBuffer[1] / (rows * (columns / 2))) / 255.0
                                                blue:(rgbBuffer[2] / (rows * (columns / 2))) / 255.0
                                               alpha:1.0];
    
    [self sendColours];
    [self setPreviewImageWithWidth:imageWidth height:imageHeight];
}

-(void)calculateColoursOfImageWithAverageHue:(CGImageRef)imageRef {
    
    
}

-(void)sendColours {
    [self.commsController pushColorsToChannel1:self.channel1Color
                                      channel2:self.channel2Color
                                      channel3:self.channel3Color
                                      channel4:self.channel4Color];
}

#pragma mark -
#pragma mark Image Rendering

-(void)renderImage:(CGImageRef)imageRef {
    
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    size_t imageWidth = CGImageGetWidth(imageRef);
    size_t imageHeight = CGImageGetHeight(imageRef);
    NSUInteger bytesPerPixel = 4;
    NSUInteger bytesPerRow = bytesPerPixel * imageWidth;
    
    if (_bufferLength != imageWidth * imageHeight * bytesPerPixel) {
        if (_imageRenderBuffer != NULL) {
            free(_imageRenderBuffer);
        }
        _bufferLength = imageWidth * imageHeight * bytesPerPixel;
        _imageRenderBuffer = malloc(imageWidth * imageHeight * bytesPerPixel);
    }
    
    CGContextRef context = CGBitmapContextCreate(_imageRenderBuffer, imageWidth, imageHeight, 8, bytesPerRow, colorSpace, kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big);
    CGColorSpaceRelease(colorSpace);
    
    CGContextDrawImage(context, (CGRect){ CGPointZero, CGSizeMake(imageWidth, imageHeight) }, imageRef);
    CGContextRelease(context);
}

-(void)setPreviewImageWithWidth:(size_t)imageWidth height:(size_t)imageHeight {
    
    NSUInteger bytesPerPixel = 4;
    NSUInteger bytesPerRow = bytesPerPixel * imageWidth;
    
    NSBitmapImageRep *rep = [[NSBitmapImageRep alloc] initWithBitmapDataPlanes:(unsigned char **)&_imageRenderBuffer
                                                                    pixelsWide:imageWidth
                                                                    pixelsHigh:imageHeight
                                                                 bitsPerSample:8
                                                               samplesPerPixel:bytesPerPixel
                                                                      hasAlpha:YES
                                                                      isPlanar:NO
                                                                colorSpaceName:NSDeviceRGBColorSpace
                                                                  bitmapFormat:NSAlphaNonpremultipliedBitmapFormat
                                                                   bytesPerRow:bytesPerRow
                                                                  bitsPerPixel:8 * bytesPerPixel];
    
    NSImage *previewImage = [[NSImage alloc] initWithSize:NSMakeSize(imageWidth, imageHeight)];
    [previewImage addRepresentation:rep];
    [self setImage:previewImage];
    [rep release];
    [previewImage release];
}

@end
