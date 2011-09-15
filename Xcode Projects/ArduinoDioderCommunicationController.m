//
//  ArduinoDioderCommunicationController.m
//  Dioder Screen Colours
//
//  Created by Daniel Kennett on 15/09/2011.
//  Copyright 2011 KennettNet Software Limited. All rights reserved.
//

#import "ArduinoDioderCommunicationController.h"
#import "AMSerialPortAdditions.h"
#import "AMSerialPortList.h"

#define kHeaderByte1 0xBA
#define kHeaderByte2 0xBE

struct ArduinoDioderControlMessage {
    unsigned char header[2];
    unsigned char colours[12];
    unsigned char checksum;
};

@interface ArduinoDioderCommunicationController ()

@property (readwrite) BOOL canSendData;

@property (readwrite, retain) NSColor *pendingChannel1Color;
@property (readwrite, retain) NSColor *pendingChannel2Color;
@property (readwrite, retain) NSColor *pendingChannel3Color;
@property (readwrite, retain) NSColor *pendingChannel4Color;

-(void)sendColours;

@end

@implementation ArduinoDioderCommunicationController

-(id)init {
    self = [super init];
    if (self) {
        // Initialization code here.
        [self addObserver:self forKeyPath:@"port" options:NSKeyValueObservingOptionOld context:nil];
        [self addObserver:self forKeyPath:@"canSendData" options:0 context:nil];
        self.canSendData = NO;
    }
    return self;
}

@synthesize port;
@synthesize canSendData;
@synthesize pendingChannel1Color;
@synthesize pendingChannel2Color;
@synthesize pendingChannel3Color;
@synthesize pendingChannel4Color;

-(void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    
    if ([keyPath isEqualToString:@"port"]) {
        
        self.canSendData = NO;
        
        id oldPort = [change valueForKey:NSKeyValueChangeOldKey];
        if (oldPort != [NSNull null])
            [oldPort close];
        
        if (self.port.available) {
            
            [self.port setSpeed:B9600];
            [self.port setParity:kAMSerialParityNone];
            [self.port setStopBits:kAMSerialStopBitsOne];
            [self.port setDataBits:8];
            [self.port setReadTimeout:1.0];
            self.port.delegate = self;
            [self.port open];
            
            self.canSendData = YES;
            
        } else if (self.port != nil) {
            self.port = nil;
        }
        
    } else if ([keyPath isEqualToString:@"canSendData"]) {
        if (self.canSendData && self.pendingChannel1Color)
            [self sendColours];
    } else {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}

-(void)pushColorsToChannel1:(NSColor *)channel1 
                   channel2:(NSColor *)channel2
                   channel3:(NSColor *)channel3
                   channel4:(NSColor *)channel4 {
    
    self.pendingChannel1Color = channel1;
    self.pendingChannel2Color = channel2;
    self.pendingChannel3Color = channel3;
    self.pendingChannel4Color = channel4;
    
    if (self.canSendData)
        [self sendColours];
}

-(void)sendColours {
    
    if (!self.canSendData)
        return;
    
    self.canSendData = NO;
    [self performSelectorInBackground:@selector(sendColoursInBackground) withObject:nil];
}

-(void)sendColoursInBackground {
    
    [self retain];
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

    // If you choose a greyscale colour, it won't have red, green or blue components so we defensively convert.
    NSColor *rgbChannel1 = [self.pendingChannel1Color colorUsingColorSpace:[NSColorSpace genericRGBColorSpace]];
    NSColor *rgbChannel2 = [self.pendingChannel2Color colorUsingColorSpace:[NSColorSpace genericRGBColorSpace]];
    NSColor *rgbChannel3 = [self.pendingChannel3Color colorUsingColorSpace:[NSColorSpace genericRGBColorSpace]];
    NSColor *rgbChannel4 = [self.pendingChannel4Color colorUsingColorSpace:[NSColorSpace genericRGBColorSpace]];
    
    struct ArduinoDioderControlMessage message;
    memset(&message, 0, sizeof(struct ArduinoDioderControlMessage));
    
    message.header[0] = kHeaderByte1;
    message.header[1] = kHeaderByte2;
    
    message.colours[0] = (unsigned char)([rgbChannel1 redComponent] * 255);
    message.colours[1] = (unsigned char)([rgbChannel1 greenComponent] * 255);
    message.colours[2] = (unsigned char)([rgbChannel1 blueComponent] * 255);
    
    message.colours[3] = (unsigned char)([rgbChannel2 redComponent] * 255);
    message.colours[4] = (unsigned char)([rgbChannel2 greenComponent] * 255);
    message.colours[5] = (unsigned char)([rgbChannel2 blueComponent] * 255);
    
    message.colours[6] = (unsigned char)([rgbChannel3 redComponent] * 255);
    message.colours[7] = (unsigned char)([rgbChannel3 greenComponent] * 255);
    message.colours[8] = (unsigned char)([rgbChannel3 blueComponent] * 255);
    
    message.colours[9] = (unsigned char)([rgbChannel4 redComponent] * 255);
    message.colours[10] = (unsigned char)([rgbChannel4 greenComponent] * 255);
    message.colours[11] = (unsigned char)([rgbChannel4 blueComponent] * 255);
    
    unsigned char checksum = 0;
    for (int i = 0; i < sizeof(message.colours); i++)
        checksum ^= message.colours[i];
    
    message.checksum = checksum;
    
    NSData *data = [NSData dataWithBytes:&message length:sizeof(struct ArduinoDioderControlMessage)];
    NSError *error = nil;
    NSString *reply = nil;
    
    [self.port writeData:data error:&error];
    
    if (!error)
        reply = [self.port readBytes:10 upToChar:(char)10 usingEncoding:NSUTF8StringEncoding error:&error];
    
    if (error)
        NSLog(@"[%@ %@]: %@", NSStringFromClass([self class]), NSStringFromSelector(_cmd), error);
    
    if (!error && ![[reply stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] isEqualToString:@"OK"])
        NSLog(@"[%@ %@]: %@", NSStringFromClass([self class]), NSStringFromSelector(_cmd), reply);
    
    self.pendingChannel1Color = nil;
    self.pendingChannel2Color = nil;
    self.pendingChannel3Color = nil;
    self.pendingChannel4Color = nil;
    
    [self performSelectorOnMainThread:@selector(completeSend) 
                           withObject:nil
                        waitUntilDone:YES];
    
    [pool drain];
    [self release];
}

-(void)completeSend {
    self.canSendData = YES;
}

-(void)dealloc {
    
    [self removeObserver:self forKeyPath:@"port"];
    
    self.canSendData = NO;
    [self.port close];
    self.port = nil;
    [super dealloc];
}

@end
