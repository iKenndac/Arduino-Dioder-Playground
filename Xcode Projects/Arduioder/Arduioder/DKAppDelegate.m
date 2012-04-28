//
//  DKAppDelegate.m
//  Arduioder
//
//  Created by Daniel Kennett on 28/04/2012.
//  Copyright (c) 2012 Daniel Kennett. All rights reserved.
//

#import "DKAppDelegate.h"
#import <QuartzCore/QuartzCore.h>

@interface DKAppDelegate ()
-(void)updateScreenColors;
@property (nonatomic, readwrite) BOOL screenUpdatesRunning;
@property (nonatomic, readwrite, strong) NSStatusItem *statusItem;
@end

@implementation DKAppDelegate
@synthesize statusBarMenu;

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
	// Insert code here to initialize your application
	[[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(portsChanged:)
                                                 name:DKSerialPortsDidChangeNotification
                                               object:nil];
	
	NSNotificationCenter *workspaceNotificationCentre = [[NSWorkspace sharedWorkspace] notificationCenter];
	
	[workspaceNotificationCentre addObserver:self
									selector:@selector(displayDidSleep:)
										name:NSWorkspaceScreensDidSleepNotification
									  object:nil];
	
	[workspaceNotificationCentre addObserver:self
									selector:@selector(displayDidWake:)
										name:NSWorkspaceScreensDidWakeNotification
									  object:nil];
	
	[self addObserver:self forKeyPath:@"fixedColor" options:0 context:nil];
	[[NSUserDefaults standardUserDefaults] addObserver:self
											forKeyPath:kLightsModeUserDefaultsKey
											   options:NSKeyValueObservingOptionInitial
											   context:nil];
	
	self.commsController = [[ArduinoDioderCommunicationController alloc] init];
	[self.commsController addObserver:self forKeyPath:@"port" options:0 context:nil];
	
	[self portsChanged:nil];
	
	NSString *portPath = [[NSUserDefaults standardUserDefaults] valueForKey:kPortPathUserDefaultsKey];
	
	if (portPath.length > 0) {
		for (DKSerialPort *port in [DKSerialPort availableSerialPorts]) {
			if ([port.serialPortPath isEqualToString:portPath]) {
				self.commsController.port = port;
				break;
			}
		}
	}
	
	NSData *data = [[NSUserDefaults standardUserDefaults] dataForKey:kFixedColorUserDefaultsKey];
	NSColor *savedColor = data == nil ? nil : [NSUnarchiver unarchiveObjectWithData:data];
	
	self.fixedColor = savedColor == nil ? [NSColor redColor] : savedColor;
	
	self.statusItem = [[NSStatusBar systemStatusBar] statusItemWithLength:NSVariableStatusItemLength];
    
    [self.statusItem setMenu:self.statusBarMenu];
    [self.statusItem setHighlightMode:YES];
	NSImage *image = [NSImage imageNamed:NSImageNameComputer];
	[image setSize:NSMakeSize(16.0, 16.0)];
	[self.statusItem setImage:image];
	
	[self.window center];
}

-(void)applicationWillTerminate:(NSNotification *)notification {
    [[NSNotificationCenter defaultCenter] removeObserver:self name:DKSerialPortsDidChangeNotification object:nil];
	[self.commsController removeObserver:self forKeyPath:@"port"];
    self.commsController = nil;
}

- (IBAction)showPreferencesWindow:(id)sender {
	[NSApp activateIgnoringOtherApps:YES];
	[self.window makeKeyAndOrderFront:sender];
}

#pragma mark - Notifications

-(void)portsChanged:(NSNotification *)aNotification {
	self.ports = [[DKSerialPort availableSerialPorts] sortedArrayUsingComparator:^(id a, id b) {
		return [[a name] caseInsensitiveCompare:[b name]];
	}];
}

-(void)displayDidSleep:(NSNotification *)aNotification {
	if ([[NSUserDefaults standardUserDefaults] boolForKey:kTurnOffLightsWithDisplayUserDefaultsKey])
		self.commsController.lightsEnabled = NO;
}

-(void)displayDidWake:(NSNotification *)aNotification {
	if ([[NSUserDefaults standardUserDefaults] boolForKey:kTurnOffLightsWithDisplayUserDefaultsKey])
		self.commsController.lightsEnabled = YES;
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if ([keyPath isEqualToString:@"fixedColor"]) {
		
		if (self.fixedColor == nil) return;
		
		NSData *data = [NSArchiver archivedDataWithRootObject:self.fixedColor];
		[[NSUserDefaults standardUserDefaults] setValue:data forKey:kFixedColorUserDefaultsKey];
		
        if ([[NSUserDefaults standardUserDefaults] integerForKey:kLightsModeUserDefaultsKey] == kLightsModeStaticColor)
			[self.commsController pushColorsToChannel1:self.fixedColor
											  channel2:self.fixedColor
											  channel3:self.fixedColor
											  channel4:self.fixedColor
										  withDuration:0.0];
		
	} else if ([keyPath isEqualToString:kLightsModeUserDefaultsKey]) {
		
		LightsMode mode = [[NSUserDefaults standardUserDefaults] integerForKey:kLightsModeUserDefaultsKey];
		
		if (mode == kLightsModeMatchDisplay) {
			[self startScreenSampling];
		} else {
			[self stopScreenSampling];
			[self.commsController pushColorsToChannel1:self.fixedColor
											  channel2:self.fixedColor
											  channel3:self.fixedColor
											  channel4:self.fixedColor
										  withDuration:0.0];
		}
		
	} else if ([keyPath isEqualToString:@"port"]) {
		
		DKSerialPort *port = self.commsController.port;
		if (port.serialPortPath.length > 0)
			[[NSUserDefaults standardUserDefaults] setValue:port.serialPortPath forKey:kPortPathUserDefaultsKey];
		
    } else {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}

#pragma mark - Screen Sampling

static CGFloat const kScreenColourCalculationInsetFraction = 0.25;

void screenDidUpdate(CGRectCount count, const CGRect *rectArray, void *userParameter) {
    
    DKAppDelegate *self = (__bridge DKAppDelegate *)userParameter;
    
    // Always assume main screen
    NSScreen *mainScreen = [[NSScreen screens] objectAtIndex:0];
    
    CGRect topBar = CGRectMake(0.0, 0.0, mainScreen.frame.size.width, mainScreen.frame.size.height * kScreenColourCalculationInsetFraction);
    CGRect bottomBar = CGRectMake(0.0, mainScreen.frame.size.height - topBar.size.height, topBar.size.width, topBar.size.height);
    CGRect leftBar = CGRectMake(0.0, 0.0, mainScreen.frame.size.width * kScreenColourCalculationInsetFraction, mainScreen.frame.size.height);
    CGRect rightBar = CGRectMake(mainScreen.frame.size.width - leftBar.size.width, 0.0, leftBar.size.width, leftBar.size.height);
    
    for (NSUInteger currentChangedFrame = 0; currentChangedFrame < count; currentChangedFrame++) {
        
        CGRect changedRect = rectArray[currentChangedFrame];
        
        if (CGRectIntersectsRect(changedRect, topBar) ||
            CGRectIntersectsRect(changedRect, bottomBar) ||
            CGRectIntersectsRect(changedRect, leftBar) ||
            CGRectIntersectsRect(changedRect, rightBar)) {
            [self updateScreenColors];
            return;
        }
    }
}

-(void)updateScreenColors {
	CGImageRef screenShot = CGDisplayCreateImage(CGMainDisplayID());
	[self calculateColoursOfImageWithAverageRGB:[CIImage imageWithCGImage:screenShot]];
    CGImageRelease(screenShot);
	screenShot = NULL;
}
 
-(void)calculateColoursOfImageWithAverageRGB:(CIImage *)ciImage {
    
    size_t imageWidth = [ciImage extent].size.width;
    size_t imageHeight = [ciImage extent].size.height;
    
    CIFilter *averageFilter = [CIFilter filterWithName:@"CIAreaAverage"];
    [averageFilter setValue:ciImage forKey:@"inputImage"];
	
    CIVector *bottomExtent = [CIVector vectorWithX:0.0 Y:0.0 Z:imageWidth W:imageHeight * kScreenColourCalculationInsetFraction];
    CIVector *leftExtent = [CIVector vectorWithX:0.0 Y:0.0 Z:imageWidth * kScreenColourCalculationInsetFraction W:imageHeight];
    CIVector *topExtent = [CIVector vectorWithX:0.0 Y:imageHeight - (imageHeight * kScreenColourCalculationInsetFraction) Z:imageWidth W:imageHeight * kScreenColourCalculationInsetFraction];
    CIVector *rightExtent = [CIVector vectorWithX:imageWidth - (imageWidth * kScreenColourCalculationInsetFraction) Y:0.0 Z:imageWidth * kScreenColourCalculationInsetFraction W:imageHeight];
    
    // Bottom
    [averageFilter setValue:bottomExtent forKey:@"inputExtent"];
    NSColor *channel1Color = [self colorFromFirstPixelOfCIImage:[averageFilter valueForKey:@"outputImage"]];
    
    // Top
    [averageFilter setValue:topExtent forKey:@"inputExtent"];
    NSColor *channel2Color = [self colorFromFirstPixelOfCIImage:[averageFilter valueForKey:@"outputImage"]];
    
    // Left
    [averageFilter setValue:leftExtent forKey:@"inputExtent"];
    NSColor *channel3Color = [self colorFromFirstPixelOfCIImage:[averageFilter valueForKey:@"outputImage"]];
	
    //Right
    [averageFilter setValue:rightExtent forKey:@"inputExtent"];
    NSColor *channel4Color = [self colorFromFirstPixelOfCIImage:[averageFilter valueForKey:@"outputImage"]];
    
    [self.commsController pushColorsToChannel1:channel1Color
									  channel2:channel2Color
									  channel3:channel3Color
									  channel4:channel4Color
								  withDuration:0.0];
}

-(NSColor *)colorFromFirstPixelOfCIImage:(CIImage *)ciImage {
    NSBitmapImageRep *rep = [[NSBitmapImageRep alloc] initWithCIImage:ciImage];
    return [rep colorAtX:0 y:0];
}

-(void)startScreenSampling {
	if (self.screenUpdatesRunning) return;
	CGRegisterScreenRefreshCallback(screenDidUpdate, (__bridge void *)self);
	self.screenUpdatesRunning = YES;
}

-(void)stopScreenSampling {
	if (!self.screenUpdatesRunning) return;
	CGUnregisterScreenRefreshCallback(screenDidUpdate, (__bridge void *)self);
	self.screenUpdatesRunning = NO;
}

@end
