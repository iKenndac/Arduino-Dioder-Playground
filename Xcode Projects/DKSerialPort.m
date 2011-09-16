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

static const int kDefaultReadBufferSize = 256;
static const int kStringReadingBufferSize = 1024;
static const NSTimeInterval kTimeout = 5.0;

@interface DKSerialPort ()

@property (nonatomic, copy, readwrite) NSString *serialPortPath;
@property (nonatomic, copy, readwrite) NSString *name;
@property (nonatomic, retain, readwrite) NSMutableData *internalBuffer;

+(void)registerForSerialPortChangeNotifications;
+(DKSerialPort *)getNextSerialPort:(io_iterator_t)serialPortIterator;

@end

@implementation DKSerialPort {
    int serialFileDescriptor; // file handle to the serial port
	struct termios gOriginalTTYAttrs; // Hold the original termios attributes so we can reset them on quit ( best practice )
}

-(id)initWithSerialPortAtPath:(NSString *)path name:(NSString *)portName {
    if ((self = [super init])) {
        self.serialPortPath = path;
        self.name = portName;
        self.internalBuffer = [NSMutableData data];
    }
    return self;
}

-(void)dealloc {
    if (serialFileDescriptor != -1) {
		close(serialFileDescriptor);
		serialFileDescriptor = -1;
    }
    self.internalBuffer = nil;
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
@synthesize internalBuffer;

-(void)openWithBaudRate:(NSUInteger)baud error:(NSError **)error {
    
    // close the port if it is already open
	if (serialFileDescriptor != -1) {
		close(serialFileDescriptor);
		serialFileDescriptor = -1;
		
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
}

-(void)writeData:(NSData *)data error:(NSError **)error {
    // send a string to the serial port
    if (serialFileDescriptor != -1) {
        if (write(serialFileDescriptor, [data bytes], [data length]) == -1 && error) \
            *error = [NSError errorWithDomain:@"org.danielkennett.dkserialport"
                                         code:0
                                     userInfo:[NSDictionary dictionaryWithObject:@"Couldn't write"
                                                                          forKey:NSLocalizedDescriptionKey]];
    } else if (error) {
        *error = [NSError errorWithDomain:@"org.danielkennett.dkserialport"
                                     code:0
                                 userInfo:[NSDictionary dictionaryWithObject:@"Couldn't write"
                                                                      forKey:NSLocalizedDescriptionKey]];
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

-(NSData *)readWithError:(NSError **)error {
    return [self readWithMaximumByteCount:kDefaultReadBufferSize error:error];
}

-(NSData *)readWithMaximumByteCount:(NSUInteger)bufferSize error:(NSError **)error {
    @synchronized(internalBuffer) {
        
        NSData *existingChunk = nil;
        
        if (self.internalBuffer.length > 0) {
            if (self.internalBuffer.length < bufferSize) {
                existingChunk = [NSData dataWithData:self.internalBuffer];
                [self.internalBuffer replaceBytesInRange:NSMakeRange(0, self.internalBuffer.length)
                                               withBytes:NULL
                                                  length:0];
            } else {
                existingChunk = [self.internalBuffer subdataWithRange:NSMakeRange(0, bufferSize)];
                [self.internalBuffer replaceBytesInRange:NSMakeRange(0, bufferSize)
                                               withBytes:NULL
                                                  length:0];
                return existingChunk;
            }
        }
        
        NSUInteger bytesToReadSize = bufferSize - existingChunk.length;
        
        char byteBuffer[bytesToReadSize]; // buffer for holding incoming data
        ssize_t numBytes = read(serialFileDescriptor, byteBuffer, bytesToReadSize);
        if (numBytes > 0) { // read up to the size of the buffer
            NSData *readData = [NSData dataWithBytes:byteBuffer length:numBytes];
            if (existingChunk) {
                NSMutableData *data = [NSMutableData dataWithData:existingChunk];
                [data appendData:readData];
                return data;
            } else {
                return readData;
            }
        } else if (numBytes == -1) {
            // Error!
            if (error)
                *error = [NSError errorWithDomain:@"org.danielkennett.dkserialport"
                                             code:0
                                         userInfo:[NSDictionary dictionaryWithObject:@"Could not read data"
                                                                              forKey:NSLocalizedDescriptionKey]];
        }
        return nil;
    }
}

-(NSData *)readUntilByte:(unsigned char)terminationByte orMaximumByteCount:(NSUInteger)bufferSize error:(NSError **)error {
    
    // Loooooop
    @synchronized(internalBuffer) {
    
        while(YES) {
            
            if (self.internalBuffer.length >= bufferSize) {
                NSData *existingChunk = [self.internalBuffer subdataWithRange:NSMakeRange(0, bufferSize)];
                [self.internalBuffer replaceBytesInRange:NSMakeRange(0, bufferSize)
                                               withBytes:NULL
                                                  length:0];
                return existingChunk;
            }
            
            if (self.internalBuffer.length > 0) {
                // Check the internal buffer for the character
                
                const unsigned char *bytes = [self.internalBuffer bytes];
                
                for (NSUInteger index = 0; index < self.internalBuffer.length; index++) {
                    
                    if (bytes[index] == terminationByte) {
                        NSData *existingChunk = [self.internalBuffer subdataWithRange:NSMakeRange(0, index + 1)];
                        [self.internalBuffer replaceBytesInRange:NSMakeRange(0, index + 1)
                                                       withBytes:NULL
                                                          length:0];
                        return existingChunk;
                    }
                }
            }
            
            // If we get here, the internal buffer is empty, or less than bufferSize and doesn't contain terminationByte
            NSUInteger bytesToReadSize = bufferSize - self.internalBuffer.length;
            
            char byteBuffer[bytesToReadSize]; // buffer for holding incoming data
            ssize_t numBytes = read(serialFileDescriptor, byteBuffer, bytesToReadSize);
            if (numBytes > 0) { // read up to the size of the buffer
                NSData *readData = [NSData dataWithBytes:byteBuffer length:numBytes];
                [self.internalBuffer appendData:readData];
            } else if (numBytes == -1) {
                // Error!
                if (error)
                    *error = [NSError errorWithDomain:@"org.danielkennett.dkserialport"
                                                 code:0
                                             userInfo:[NSDictionary dictionaryWithObject:@"Could not read data"
                                                                                  forKey:NSLocalizedDescriptionKey]];

                return nil;
            }
        }
    }
}

-(NSString *)readUTF8CStringWithError:(NSError **)error {
    NSData *stringData = [self readUntilByte:0 orMaximumByteCount:kStringReadingBufferSize error:error];
    if (stringData)
        return [[[NSString alloc] initWithUTF8String:[stringData bytes]] autorelease];
    
    return nil;
}

-(NSString *)readLineWithError:(NSError **)error {
    NSData *stringData = [self readUntilByte:'\n' orMaximumByteCount:kStringReadingBufferSize error:error];
    if (stringData)
        return [[[[NSString alloc] initWithUTF8String:[stringData bytes]] autorelease] 
                stringByTrimmingCharactersInSet:[NSCharacterSet newlineCharacterSet]];
    
    return nil;
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
