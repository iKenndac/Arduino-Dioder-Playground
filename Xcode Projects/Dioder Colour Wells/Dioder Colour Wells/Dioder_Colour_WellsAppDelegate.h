//
//  Dioder_Colour_WellsAppDelegate.h
//  Dioder Colour Wells
//
//  Created by Daniel Kennett on 08/09/2011.
//  Copyright 2011 KennettNet Software Limited. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "AMSerialPort.h"

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
