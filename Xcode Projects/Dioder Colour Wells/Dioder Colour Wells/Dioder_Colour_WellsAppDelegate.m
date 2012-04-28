//
//  Dioder_Colour_WellsAppDelegate.m
//  Dioder Colour Wells
//
//  Created by Daniel Kennett on 08/09/2011.
//  Copyright 2011 Daniel Kennett. All rights reserved.
//

#import "Dioder_Colour_WellsAppDelegate.h"

@implementation Dioder_Colour_WellsAppDelegate

@synthesize window;
@synthesize commsController;
@synthesize ports;
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
    
    [self portsChanged:nil];
    
    self.commsController = [ArduinoDioderCommunicationController new];
    
    self.channel1Color = [NSColor blackColor];
    self.channel2Color = [NSColor blackColor];
    self.channel3Color = [NSColor blackColor];
    self.channel4Color = [NSColor blackColor];
    
    [self addObserver:self forKeyPath:@"channel1Color" options:0 context:nil];
    [self addObserver:self forKeyPath:@"channel2Color" options:0 context:nil];
    [self addObserver:self forKeyPath:@"channel3Color" options:0 context:nil];
    [self addObserver:self forKeyPath:@"channel4Color" options:0 context:nil];
    
}

-(void)portsChanged:(NSNotification *)aNotification {
    self.ports = [[DKSerialPort availableSerialPorts] sortedArrayUsingComparator:^(id a, id b) {
        return [[a name] caseInsensitiveCompare:[b name]];
    }];
}

-(void)applicationWillTerminate:(NSNotification *)notification {
    [[NSNotificationCenter defaultCenter] removeObserver:self 
                                                    name:DKSerialPortsDidChangeNotification
                                                  object:nil];
    self.commsController = nil;
}

-(void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    if ([keyPath hasPrefix:@"channel"]) {
        [self.commsController pushColorsToChannel1:self.channel1Color
                                          channel2:self.channel2Color
                                          channel3:self.channel3Color
                                          channel4:self.channel4Color
                                      withDuration:0.0];
        
    } else {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}

@end
