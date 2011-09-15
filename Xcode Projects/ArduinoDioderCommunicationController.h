//
//  ArduinoDioderCommunicationController.h
//  Dioder Screen Colours
//
//  Created by Daniel Kennett on 15/09/2011.
//  Copyright 2011 KennettNet Software Limited. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "AMSerialPort.h"

@interface ArduinoDioderCommunicationController : NSObject

@property (readwrite, retain) AMSerialPort *port;

-(void)pushColorsToChannel1:(NSColor *)channel1 
                   channel2:(NSColor *)channel2
                   channel3:(NSColor *)channel3
                   channel4:(NSColor *)channel4;

@end
