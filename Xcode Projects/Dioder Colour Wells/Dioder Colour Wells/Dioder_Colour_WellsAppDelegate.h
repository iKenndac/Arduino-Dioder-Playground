//
//  Dioder_Colour_WellsAppDelegate.h
//  Dioder Colour Wells
//
//  Created by Daniel Kennett on 08/09/2011.
//  Copyright 2011 Daniel Kennett. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "ArduinoDioderCommunicationController.h"

@interface Dioder_Colour_WellsAppDelegate : NSObject <NSApplicationDelegate>

@property (assign) IBOutlet NSWindow *window;

@property (readwrite, retain, nonatomic) NSArray *ports;
@property (readwrite, retain, nonatomic) ArduinoDioderCommunicationController *commsController;

@property (readwrite, retain, nonatomic) NSColor *channel1Color;
@property (readwrite, retain, nonatomic) NSColor *channel2Color;
@property (readwrite, retain, nonatomic) NSColor *channel3Color;
@property (readwrite, retain, nonatomic) NSColor *channel4Color;

-(void)portsChanged:(NSNotification *)aNotification;

@end
