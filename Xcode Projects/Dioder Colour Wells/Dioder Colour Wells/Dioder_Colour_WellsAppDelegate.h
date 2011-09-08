//
//  Dioder_Colour_WellsAppDelegate.h
//  Dioder Colour Wells
//
//  Created by Daniel Kennett on 08/09/2011.
//  Copyright 2011 Daniel Kennett. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "AMSerialPort.h"

#define kHeaderByte1 0xBA
#define kHeaderByte2 0xBE

struct ArduinoDioderControlMessage {
    unsigned char header[2];
    unsigned char colours[12];
    unsigned char checksum;
};

@interface Dioder_Colour_WellsAppDelegate : NSObject <NSApplicationDelegate> {
    NSWindow *window;
}

@property (assign) IBOutlet NSWindow *window;

@property (readwrite, retain, nonatomic) NSArray *ports;
@property (readwrite, retain, nonatomic) AMSerialPort *port;

@property (readwrite, retain, nonatomic) NSColor *channel1Color;
@property (readwrite, retain, nonatomic) NSColor *channel2Color;
@property (readwrite, retain, nonatomic) NSColor *channel3Color;
@property (readwrite, retain, nonatomic) NSColor *channel4Color;

-(void)updateColoursOnChannel1:(NSColor *)channel1 channel2:(NSColor *)channel2 channel3:(NSColor *)channel3 channel4:(NSColor *)channel4;
-(void)portsChanged:(NSNotification *)aNotification;

@end
