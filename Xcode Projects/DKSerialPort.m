//
//  DKSerialPort.m
//  Dioder Screen Colours
//
//  Created by Daniel Kennett on 15/09/2011.
//  Copyright (c) 2011 Daniel Kennett. All rights reserved.
//

#import "DKSerialPort.h"
#include <IOKit/IOKitLib.h>
#include <IOKit/serial/IOSerialKeys.h>
#include <IOKit/IOBSD.h>
#include <IOKit/serial/ioss.h>
#include <sys/ioctl.h>

@interface DKSerialPort ()

@property (nonatomic, copy, readwrite) NSString *serialPortPath;
@property (nonatomic, copy, readwrite) NSString *name;

+(void)registerForSerialPortChangeNotifications;
+(DKSerialPort *)getNextSerialPort:(io_iterator_t)serialPortIterator;

@end

@implementation DKSerialPort {
    int serialFileDescriptor; // file handle to the serial port
	struct termios gOriginalTTYAttrs; // Hold the original termios attributes so we can reset them on quit ( best practice )
    BOOL readThreadRunning;
}

-(id)initWithSerialPortAtPath:(NSString *)path name:(NSString *)portName {
    if ((self = [super init])) {
        self.serialPortPath = path;
        self.name = portName;
    }
    return self;
}

-(void)dealloc {
    if (serialFileDescriptor != -1) {
		close(serialFileDescriptor);
		serialFileDescriptor = -1;
    }
    self.name = nil;
    self.serialPortPath = nil;
    [super dealloc];
}

-(BOOL)isEqual:(id)object {
    if ([object isKindOfClass:[self class]]) {
        return [self.serialPortPath isEqualToString:((DKSerialPort *)object).serialPortPath];
    } else {
        return [super isEqual:object];
    }
}

@synthesize name;
@synthesize serialPortPath;

-(void)openWithBaudRate:(NSUInteger)baud error:(NSError **)error {
    
    // close the port if it is already open
	if (serialFileDescriptor != -1) {
		close(serialFileDescriptor);
		serialFileDescriptor = -1;
		
		// wait for the reading thread to die
		while(readThreadRunning);
		
		// re-opening the same port REALLY fast will fail spectacularly... better to sleep a sec
		[NSThread sleepForTimeInterval:0.5];
	}
    
    // Hold the original termios attributes we are setting
	struct termios options;
	
	// receive latency ( in microseconds )
	unsigned long mics = 3;
    
    // open the port
	//     O_NONBLOCK causes the port to open without any delay (we'll block with another call)
	serialFileDescriptor = open([self.serialPortPath UTF8String], O_RDWR | O_NOCTTY | O_NONBLOCK );
	
	if (serialFileDescriptor == -1) { 
		// check if the port opened correctly
        if (error)
            *error = [NSError errorWithDomain:@"org.danielkennett.dkserialport"
                                         code:0
                                     userInfo:[NSDictionary dictionaryWithObject:@"Couldn't open serial port"
                                                                          forKey:NSLocalizedDescriptionKey]];
        return;
    }
    
    // TIOCEXCL causes blocking of non-root processes on this serial-port
    if (ioctl(serialFileDescriptor, TIOCEXCL) == -1) {
        if (error)
            *error = [NSError errorWithDomain:@"org.danielkennett.dkserialport"
                                         code:0
                                     userInfo:[NSDictionary dictionaryWithObject:@"Couldn't obtain lock on serial port"
                                                                          forKey:NSLocalizedDescriptionKey]];
        close(serialFileDescriptor);
		serialFileDescriptor = -1;
        return;
    }
    
    // clear the O_NONBLOCK flag; all calls from here on out are blocking for non-root processes
    if (fcntl(serialFileDescriptor, F_SETFL, 0) == -1) {
        if (error)
            *error = [NSError errorWithDomain:@"org.danielkennett.dkserialport"
                                         code:0
                                     userInfo:[NSDictionary dictionaryWithObject:@"Couldn't obtain lock on serial port"
                                                                          forKey:NSLocalizedDescriptionKey]];
        close(serialFileDescriptor);
		serialFileDescriptor = -1;
        return;
    }
    
    // Get the current options and save them so we can restore the default settings later.
    if (tcgetattr(serialFileDescriptor, &gOriginalTTYAttrs) == -1) {
        if (error)
            *error = [NSError errorWithDomain:@"org.danielkennett.dkserialport"
                                         code:0
                                     userInfo:[NSDictionary dictionaryWithObject:@"couldn't get serial attributes"
                                                                          forKey:NSLocalizedDescriptionKey]];
        close(serialFileDescriptor);
		serialFileDescriptor = -1;
        return;
    }
    
    // copy the old termios settings into the current
    //   you want to do this so that you get all the control characters assigned
    options = gOriginalTTYAttrs;
    
    /*
     cfmakeraw(&options) is equivilent to:
     options->c_iflag &= ~(IGNBRK | BRKINT | PARMRK | ISTRIP | INLCR | IGNCR | ICRNL | IXON);
     options->c_oflag &= ~OPOST;
     options->c_lflag &= ~(ECHO | ECHONL | ICANON | ISIG | IEXTEN);
     options->c_cflag &= ~(CSIZE | PARENB);
     options->c_cflag |= CS8;
     */
    cfmakeraw(&options);
    
    // set tty attributes (raw-mode in this case)
    if (tcsetattr(serialFileDescriptor, TCSANOW, &options) == -1) {
        if (error)
            *error = [NSError errorWithDomain:@"org.danielkennett.dkserialport"
                                         code:0
                                     userInfo:[NSDictionary dictionaryWithObject:@"couldn't set serial attributes"
                                                                          forKey:NSLocalizedDescriptionKey]];
        close(serialFileDescriptor);
		serialFileDescriptor = -1;
        return;
    }
    
    //Set baud rate
    if (ioctl(serialFileDescriptor, IOSSIOSPEED, &baud) == -1) {
        if (error)
            *error = [NSError errorWithDomain:@"org.danielkennett.dkserialport"
                                         code:0
                                     userInfo:[NSDictionary dictionaryWithObject:@"couldn't set baud rate"
                                                                          forKey:NSLocalizedDescriptionKey]];
        close(serialFileDescriptor);
		serialFileDescriptor = -1;
        return;
    }
    
    // Set the receive latency (a.k.a. don't wait to buffer data)
    if (ioctl(serialFileDescriptor, IOSSDATALAT, &mics) == -1) {
        if (error)
            *error = [NSError errorWithDomain:@"org.danielkennett.dkserialport"
                                         code:0
                                     userInfo:[NSDictionary dictionaryWithObject:@"couldn't set receive latency"
                                                                          forKey:NSLocalizedDescriptionKey]];
        close(serialFileDescriptor);
		serialFileDescriptor = -1;
        return;
    }
    
    [self performSelectorInBackground:@selector(incomingDataReadThread:) withObject:[NSThread currentThread]];
}

-(void)writeData:(NSData *)data {
    // send a string to the serial port
    if (serialFileDescriptor != -1) {
        write(serialFileDescriptor, [data bytes], [data length]);
    }
}

-(void)close {
    if (serialFileDescriptor != -1) {
        close(serialFileDescriptor);
        serialFileDescriptor = -1;
    }
}

-(BOOL)isOpen {
    return serialFileDescriptor != -1;
}

// This selector/function will be called as another thread...
//  this thread will read from the serial port and exits when the port is closed
-(void)incomingDataReadThread:(NSThread *)parentThread {
	
	// create a pool so we can use regular Cocoa stuff
	//   child threads can't re-use the parent's autorelease pool
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	
	// mark that the thread is running
	readThreadRunning = YES;
	
	const int BUFFER_SIZE = 100;
	char byte_buffer[BUFFER_SIZE]; // buffer for holding incoming data
	ssize_t numBytes=0; // number of bytes read during read
	
	// assign a high priority to this thread
	[NSThread setThreadPriority:1.0];
	
	// this will loop unitl the serial port closes
	while(YES) {
		// read() blocks until some data is available or the port is closed
		numBytes = read(serialFileDescriptor, byte_buffer, BUFFER_SIZE); // read up to the size of the buffer
		if(numBytes>0) {
			// create an NSString from the incoming bytes (the bytes aren't null terminated)
			NSData *data = [NSData dataWithBytes:byte_buffer length:numBytes];
			
			// this text can't be directly sent to the text area from this thread
			//  BUT, we can call a selctor on the main thread.
			[self performSelectorOnMainThread:@selector(dataWasRead:)
                                   withObject:data
                                waitUntilDone:YES];
		} else {
			break; // Stop the thread if there is an error
		}
	}
	
	// make sure the serial port is closed
	if (serialFileDescriptor != -1) {
		close(serialFileDescriptor);
		serialFileDescriptor = -1;
	}
	
	// mark that the thread has quit
	readThreadRunning = NO;
	
	// give back the pool
	[pool release];
}

-(void)dataWasRead:(NSData *)data {
    NSString *string = [[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] autorelease];
    NSLog(@"[%@ %@]: %@", NSStringFromClass([self class]), NSStringFromSelector(_cmd), string);
}

#pragma mark -
#pragma mark Change Notifications

static NSMutableArray *serialPortList = nil;

+(void)initialize {
    
    // Sometimes we get this twice.
    if (serialPortList)
        return;
    
    serialPortList = [[NSMutableArray alloc] init];
    
	io_iterator_t serialPortIterator;
	DKSerialPort* serialPort;
	
	// Serial devices are instances of class IOSerialBSDClient
	CFMutableDictionaryRef classesToMatch = IOServiceMatching(kIOSerialBSDServiceValue);
	if (classesToMatch != NULL) {
		CFDictionarySetValue(classesToMatch, CFSTR(kIOSerialBSDTypeKey), CFSTR(kIOSerialBSDAllTypes));
        
		// This function decrements the refcount of the dictionary passed it
		kern_return_t kernResult = IOServiceGetMatchingServices(kIOMasterPortDefault, classesToMatch, &serialPortIterator);    
		if (kernResult == KERN_SUCCESS) {			
			while ((serialPort = [self getNextSerialPort:serialPortIterator]) != nil) {
				[serialPortList addObject:serialPort];
			}
			(void)IOObjectRelease(serialPortIterator);
		} else {
			//NSLog(@"IOServiceGetMatchingServices returned %d", kernResult);
		}
	} else {
		//NSLog(@"IOServiceMatching returned a NULL dictionary.");
	}

    [self registerForSerialPortChangeNotifications];
}

+(NSArray *)availableSerialPorts {
    return [NSArray arrayWithArray:serialPortList];
}

+(DKSerialPort *)existingPortWithPath:(NSString *)bsdPath {
    for (DKSerialPort *port in serialPortList) {
        if ([[port serialPortPath] isEqualToString:bsdPath])
            return port;
    }
    return nil;
}

+(DKSerialPort *)getNextSerialPort:(io_iterator_t)serialPortIterator {
    
	DKSerialPort *serialPort = nil;
    
	io_object_t serialService = IOIteratorNext(serialPortIterator);
	if (serialService != 0) {
		CFStringRef modemName = (CFStringRef)IORegistryEntryCreateCFProperty(serialService, CFSTR(kIOTTYDeviceKey), kCFAllocatorDefault, 0);
		CFStringRef bsdPath = (CFStringRef)IORegistryEntryCreateCFProperty(serialService, CFSTR(kIOCalloutDeviceKey), kCFAllocatorDefault, 0);
		CFStringRef serviceType = (CFStringRef)IORegistryEntryCreateCFProperty(serialService, CFSTR(kIOSerialBSDTypeKey), kCFAllocatorDefault, 0);
		if (modemName && bsdPath) {
			// If the port already exists in the list of ports, we want that one.  We only create a new one as a last resort.
			serialPort = [self existingPortWithPath:(NSString *)bsdPath];
			if (serialPort == nil) {
				serialPort = [[[DKSerialPort alloc] initWithSerialPortAtPath:(NSString *)bsdPath name:(NSString *)modemName] autorelease];
			}
		}
		if (modemName) {
			CFRelease(modemName);
		}
		if (bsdPath) {
			CFRelease(bsdPath);
		}
		if (serviceType) {
			CFRelease(serviceType);
		}
		
		// We have sucked this service dry of information so release it now.
		(void)IOObjectRelease(serialService);
	}
	
	return serialPort;
}

+(void)portsWereAdded:(io_iterator_t)iterator {

    DKSerialPort *serialPort = nil;
	while ((serialPort = [self getNextSerialPort:iterator]) != nil) {
		[serialPortList addObject:serialPort];
	}
	
	NSDictionary *userInfo = [NSDictionary dictionaryWithObject:[DKSerialPort availableSerialPorts]
                                                         forKey:DKSerialPortsKey];
    
	[[NSNotificationCenter defaultCenter] postNotificationName:DKSerialPortsDidChangeNotification 
                                                        object:self
                                                      userInfo:userInfo];
}

+(void)portsWereRemoved:(io_iterator_t)iterator {
	DKSerialPort *serialPort = nil;
    
	while ((serialPort = [self getNextSerialPort:iterator]) != nil) {
		// Since the port was removed, one should obviously not attempt to use it anymore -- so 'close' it.
		// -close does nothing if the port was never opened.
		[serialPort close];
		
		[serialPortList removeObject:serialPort];
	}
    
	NSDictionary *userInfo = [NSDictionary dictionaryWithObject:[DKSerialPort availableSerialPorts]
                                                         forKey:DKSerialPortsKey];
    
	[[NSNotificationCenter defaultCenter] postNotificationName:DKSerialPortsDidChangeNotification 
                                                        object:self
                                                      userInfo:userInfo];
}

static void DKSerialPortWasAddedNotification(void *refcon, io_iterator_t iterator) {
	(void)refcon;
	[DKSerialPort portsWereAdded:iterator];
}

static void DKSerialPortWasRemovedNotification(void *refcon, io_iterator_t iterator) {
	(void)refcon;
	[DKSerialPort portsWereRemoved:iterator];
}


+(void)registerForSerialPortChangeNotifications {
	IONotificationPortRef notificationPort = IONotificationPortCreate(kIOMasterPortDefault); 
	if (notificationPort) {
		CFRunLoopSourceRef notificationSource = IONotificationPortGetRunLoopSource(notificationPort);
		if (notificationSource) {
			// Serial devices are instances of class IOSerialBSDClient
			CFMutableDictionaryRef classesToMatch1 = IOServiceMatching(kIOSerialBSDServiceValue);
			if (classesToMatch1) {
				CFDictionarySetValue(classesToMatch1, CFSTR(kIOSerialBSDTypeKey), CFSTR(kIOSerialBSDAllTypes));
				
				// Copy classesToMatch1 now, while it has a non-zero ref count.
				CFMutableDictionaryRef classesToMatch2 = CFDictionaryCreateMutableCopy(kCFAllocatorDefault, 0, classesToMatch1);			
				// Add to the runloop
				CFRunLoopAddSource([[NSRunLoop currentRunLoop] getCFRunLoop], notificationSource, kCFRunLoopCommonModes);
				
				// Set up notification for ports being added.
				io_iterator_t unused;
				kern_return_t kernResult = IOServiceAddMatchingNotification(notificationPort, kIOPublishNotification, classesToMatch1, DKSerialPortWasAddedNotification, NULL, &unused); // consumes a reference to classesToMatch1
				if (kernResult != KERN_SUCCESS) {
                    // TODO: Error
				} else {
					while (IOIteratorNext(unused)) {}	// arm the notification
				}
                
				if (classesToMatch2) {
					// Set up notification for ports being removed.
					kernResult = IOServiceAddMatchingNotification(notificationPort, kIOTerminatedNotification, classesToMatch2, DKSerialPortWasRemovedNotification, NULL, &unused); // consumes a reference to classesToMatch2
					if (kernResult != KERN_SUCCESS) {
                        // TODO: Error
					} else {
						while (IOIteratorNext(unused)) {}	// arm the notification
					}
				}
			} else {
                //TODO: Error
			}
		}
		// Note that IONotificationPortDestroy(notificationPort) is deliberately not called here because if it were our port change notifications would never fire.  This minor leak is pretty irrelevent since this object is a singleton that lives for the life of the application anyway.
	}
}















@end
