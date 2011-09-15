//
//  ArduinoDioderCommunicationController.h
//  Dioder Screen Colours
//
//  Created by Daniel Kennett on 15/09/2011.
//  Copyright 2011 Daniel Kennett. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "DKSerialPort.h"

@interface ArduinoDioderCommunicationController : NSObject

@property (readwrite, retain) DKSerialPort *port;

-(void)pushColorsToChannel1:(NSColor *)channel1 
                   channel2:(NSColor *)channel2
                   channel3:(NSColor *)channel3
                   channel4:(NSColor *)channel4;

@end
