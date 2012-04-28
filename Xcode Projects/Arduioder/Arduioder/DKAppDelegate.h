//
//  DKAppDelegate.h
//  Arduioder
//
//  Created by Daniel Kennett on 28/04/2012.
//  Copyright (c) 2012 Daniel Kennett. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "ArduinoDioderCommunicationController.h"

static NSString * const kTurnOffLightsWithDisplayUserDefaultsKey = @"TurnOffLightsWithDisplay";
static NSString * const kFixedColorUserDefaultsKey = @"FixedColor";
static NSString * const kLightsModeUserDefaultsKey = @"LightsMode";

typedef enum LightsMode : NSInteger {
	kLightsModeMatchDisplay = 0,
	kLightsModeStaticColor = 1
} LightsMode;

@interface DKAppDelegate : NSObject <NSApplicationDelegate>

@property (assign) IBOutlet NSWindow *window;
@property (weak) IBOutlet NSMenu *statusBarMenu;

@property (readwrite, retain, nonatomic) ArduinoDioderCommunicationController *commsController;
@property (readwrite, retain, nonatomic) NSArray *ports;

@property (readwrite, retain, nonatomic) NSColor *fixedColor;

-(void)portsChanged:(NSNotification *)aNotification;
- (IBAction)showPreferencesWindow:(id)sender;

@end
