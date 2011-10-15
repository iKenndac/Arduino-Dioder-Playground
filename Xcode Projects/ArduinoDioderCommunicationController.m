//
//  ArduinoDioderCommunicationController.m
//  Dioder Screen Colors
//
//  Created by Daniel Kennett on 15/09/2011.
//  Copyright 2011 Daniel Kennett. All rights reserved.
//

#import "ArduinoDioderCommunicationController.h"

#define kHeaderByte1 0xBA
#define kHeaderByte2 0xBE

struct ArduinoDioderControlMessage {
    unsigned char header[2];
    unsigned char colors[12];
    unsigned char checksum;
};

@interface ArduinoDioderCommunicationController ()

@property (readwrite) BOOL canSendData;

@property (readwrite, retain) NSColor *pendingChannel1Color;
@property (readwrite, retain) NSColor *pendingChannel2Color;
@property (readwrite, retain) NSColor *pendingChannel3Color;
@property (readwrite, retain) NSColor *pendingChannel4Color;

@property (readwrite, retain) NSColor *currentChannel1Color;
@property (readwrite, retain) NSColor *currentChannel2Color;
@property (readwrite, retain) NSColor *currentChannel3Color;
@property (readwrite, retain) NSColor *currentChannel4Color;

-(void)sendColorsWithDuration:(NSTimeInterval)duration;
-(void)writeColorsToChannel1:(NSColor *)channel1 channel2:(NSColor *)channel2 channel3:(NSColor *)channel3 channel4:(NSColor *)channel4;

-(NSColor *)colorByApplyingProgress:(double)progress ofTransitionFromColor:(NSColor *)start toColor:(NSColor *)finish;

@end

@implementation ArduinoDioderCommunicationController

-(id)init {
    self = [super init];
    if (self) {
        // Initialization code here.
        [self addObserver:self forKeyPath:@"port" options:NSKeyValueObservingOptionOld context:nil];
        [self addObserver:self forKeyPath:@"canSendData" options:0 context:nil];
        self.canSendData = NO;
        
        self.currentChannel1Color = [NSColor blackColor];
        self.currentChannel2Color = [NSColor blackColor];
        self.currentChannel3Color = [NSColor blackColor];
        self.currentChannel4Color = [NSColor blackColor];
    }
    return self;
}

-(void)dealloc {
    
    [self removeObserver:self forKeyPath:@"port"];
    [self removeObserver:self forKeyPath:@"canSendData"];
    
    self.pendingChannel1Color = nil;
    self.pendingChannel2Color = nil;
    self.pendingChannel3Color = nil;
    self.pendingChannel4Color = nil;
    
    self.currentChannel1Color = nil;
    self.currentChannel2Color = nil;
    self.currentChannel3Color = nil;
    self.currentChannel4Color = nil;
    
    self.canSendData = NO;
    [self.port close];
    self.port = nil;
    [super dealloc];
}


@synthesize port;
@synthesize canSendData;
@synthesize pendingChannel1Color;
@synthesize pendingChannel2Color;
@synthesize pendingChannel3Color;
@synthesize pendingChannel4Color;
@synthesize currentChannel1Color;
@synthesize currentChannel2Color;
@synthesize currentChannel3Color;
@synthesize currentChannel4Color;

-(void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    
    if ([keyPath isEqualToString:@"port"]) {
        
        self.canSendData = NO;
        
        id oldPort = [change valueForKey:NSKeyValueChangeOldKey];
        if (oldPort != [NSNull null])
            [oldPort close];
        
        NSError *err = nil;
        [self.port openWithBaudRate:57600
                              error:&err];
        
        if (err)
            NSLog(@"[%@ %@]: %@", NSStringFromClass([self class]), NSStringFromSelector(_cmd), err);
        
        [self performSelector:@selector(enableWrite)
                   withObject:nil
                   afterDelay:1.0];
        
    } else if ([keyPath isEqualToString:@"canSendData"]) {
        if (self.canSendData && self.pendingChannel1Color) {
            [self sendColorsWithDuration:0.0];
            NSLog(@"[%@ %@]: %@", NSStringFromClass([self class]), NSStringFromSelector(_cmd), @"forcing");
        }
    } else {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}

#pragma mark -
#pragma mark Setup

-(void)enableWrite {
    self.canSendData = YES;
    
    [self pushColorsToChannel1:[NSColor whiteColor]
                      channel2:[NSColor whiteColor]
                      channel3:[NSColor whiteColor]
                      channel4:[NSColor whiteColor]
                  withDuration:5.0];
    
}

-(void)pushColorsToChannel1:(NSColor *)channel1 
                   channel2:(NSColor *)channel2
                   channel3:(NSColor *)channel3
                   channel4:(NSColor *)channel4
               withDuration:(NSTimeInterval)duration {
    
    if ([channel1 isEqualTo:self.currentChannel1Color] &&
        [channel2 isEqualTo:self.currentChannel2Color] &&
        [channel3 isEqualTo:self.currentChannel3Color] &&
        [channel4 isEqualTo:self.currentChannel4Color])
        return;
    
    self.pendingChannel1Color = channel1;
    self.pendingChannel2Color = channel2;
    self.pendingChannel3Color = channel3;
    self.pendingChannel4Color = channel4;
    
    if (self.canSendData)
        [self sendColorsWithDuration:duration];
}

-(void)sendColorsWithDuration:(NSTimeInterval)duration {
    
    if (!self.canSendData && ![self.port isOpen])
        return;
    
    self.canSendData = NO;
    [self performSelectorInBackground:@selector(sendPendingColorsInBackground:) withObject:[NSNumber numberWithDouble:duration]];
}

#pragma mark -
#pragma mark Sending (in background)

-(void)sendPendingColorsInBackground:(NSNumber *)animationDuration {
    
    [self retain];
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    
    NSTimeInterval duration = [animationDuration doubleValue];
    NSDate *operationStartDate = [NSDate date];
    NSTimeInterval timeSinceStartDate = 0.0;
    double animationSpeed = 1.0 / duration;
    
    while (timeSinceStartDate < duration) {
        
        [self writeColorsToChannel1:[self colorByApplyingProgress:timeSinceStartDate * animationSpeed ofTransitionFromColor:self.currentChannel1Color toColor:self.pendingChannel1Color]
                           channel2:[self colorByApplyingProgress:timeSinceStartDate * animationSpeed ofTransitionFromColor:self.currentChannel2Color toColor:self.pendingChannel2Color]
                           channel3:[self colorByApplyingProgress:timeSinceStartDate * animationSpeed ofTransitionFromColor:self.currentChannel3Color toColor:self.pendingChannel3Color]
                           channel4:[self colorByApplyingProgress:timeSinceStartDate * animationSpeed ofTransitionFromColor:self.currentChannel4Color toColor:self.pendingChannel4Color]];

        
        timeSinceStartDate = [[NSDate date] timeIntervalSinceDate:operationStartDate];
    }
    
    [self writeColorsToChannel1:self.pendingChannel1Color
                       channel2:self.pendingChannel2Color
                       channel3:self.pendingChannel3Color
                       channel4:self.pendingChannel4Color];
    
    [self performSelectorOnMainThread:@selector(completeSend) 
                           withObject:nil
                        waitUntilDone:YES];
    
    [pool drain];
    [self release];
}

-(void)writeColorsToChannel1:(NSColor *)channel1 channel2:(NSColor *)channel2 channel3:(NSColor *)channel3 channel4:(NSColor *)channel4 {
    
    [self retain];
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    
    // If you choose a greyscale color, it won't have red, green or blue components so we defensively convert.
    NSColor *rgbChannel1 = [channel1 colorUsingColorSpace:[NSColorSpace genericRGBColorSpace]];
    NSColor *rgbChannel2 = [channel2 colorUsingColorSpace:[NSColorSpace genericRGBColorSpace]];
    NSColor *rgbChannel3 = [channel3 colorUsingColorSpace:[NSColorSpace genericRGBColorSpace]];
    NSColor *rgbChannel4 = [channel4 colorUsingColorSpace:[NSColorSpace genericRGBColorSpace]];
    
    struct ArduinoDioderControlMessage message;
    memset(&message, 0, sizeof(struct ArduinoDioderControlMessage));
    
    message.header[0] = kHeaderByte1;
    message.header[1] = kHeaderByte2;
    
    message.colors[0] = (unsigned char)([rgbChannel1 greenComponent] * 255);
    message.colors[1] = (unsigned char)([rgbChannel1 blueComponent] * 255);
    message.colors[2] = (unsigned char)([rgbChannel1 redComponent] * 255);
    
    message.colors[3] = (unsigned char)([rgbChannel2 greenComponent] * 255);
    message.colors[4] = (unsigned char)([rgbChannel2 blueComponent] * 255);
    message.colors[5] = (unsigned char)([rgbChannel2 redComponent] * 255);
    
    message.colors[6] = (unsigned char)([rgbChannel3 greenComponent] * 255);
    message.colors[7] = (unsigned char)([rgbChannel3 blueComponent] * 255);
    message.colors[8] = (unsigned char)([rgbChannel3 redComponent] * 255);
    
    message.colors[9] = (unsigned char)([rgbChannel4 greenComponent] * 255);
    message.colors[10] = (unsigned char)([rgbChannel4 blueComponent] * 255);
    message.colors[11] = (unsigned char)([rgbChannel4 redComponent] * 255);
    
    unsigned char checksum = 0;
    for (int i = 0; i < sizeof(message.colors); i++)
        checksum ^= message.colors[i];
    
    message.checksum = checksum;
    
    NSData *data = [NSData dataWithBytes:&message length:sizeof(struct ArduinoDioderControlMessage)];
    NSError *error = nil;
    NSString *reply = nil;
    
    [self.port writeData:data error:&error];
    
    if (!error)
        reply = [self.port readLineWithError:&error];
    
    if (error)
        NSLog(@"[%@ %@]: %@", NSStringFromClass([self class]), NSStringFromSelector(_cmd), error);
    else if (reply && ![reply isEqualToString:@"OK"])
        NSLog(@"[%@ %@]: %@", NSStringFromClass([self class]), NSStringFromSelector(_cmd), reply);
    
    [pool drain];
    [self release];
}

-(void)completeSend {
    
    self.currentChannel1Color = self.pendingChannel1Color;
    self.currentChannel2Color = self.pendingChannel2Color;
    self.currentChannel3Color = self.pendingChannel3Color;
    self.currentChannel4Color = self.pendingChannel4Color;
    
    self.pendingChannel1Color = nil;
    self.pendingChannel2Color = nil;
    self.pendingChannel3Color = nil;
    self.pendingChannel4Color = nil;
    
    self.canSendData = YES;
}

#pragma mark -
#pragma mark Helpers

-(NSColor *)colorByApplyingProgress:(double)progress ofTransitionFromColor:(NSColor *)start toColor:(NSColor *)finish {
    
    if ([start isEqualTo:finish])
        return finish;
    
    // If you choose a greyscale color, it won't have red, green or blue components so we defensively convert.
    start = [start colorUsingColorSpace:[NSColorSpace genericRGBColorSpace]];
    finish = [finish colorUsingColorSpace:[NSColorSpace genericRGBColorSpace]];
    
    CGFloat fromRed = [start redComponent];
    CGFloat fromGreen = [start greenComponent];
    CGFloat fromBlue = [start blueComponent];
    
    CGFloat toRed = [finish redComponent];
    CGFloat toGreen = [finish greenComponent];
    CGFloat toBlue = [finish blueComponent];
    
    return [NSColor colorWithDeviceRed:fromRed + ((toRed - fromRed) * progress)
                                 green:fromGreen + ((toGreen - fromGreen) * progress)
                                  blue:fromBlue + ((toBlue - fromBlue) * progress)
                                 alpha:1.0];
}

@end
