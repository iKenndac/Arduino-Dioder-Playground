//
//  AMSerialPort_Deprecated.m
//  AMSerialTest
//
//  Created by Andreas on 26.07.06.
//  Copyright 2006-2009 Andreas Mayer. All rights reserved.
//

#import "AMSerialPort_Deprecated.h"
#import "AMSerialPortAdditions.h"


@implementation AMSerialPort (Deprecated)

- (id)init:(NSString *)path withName:(NSString *)name
{
	return [self init:path withName:name type:@""];
}

// renamed to -options
- (NSDictionary *)getOptions
{
	return [self options];
}

// renamed to -speed
- (long)getSpeed
{
	return [self speed];
}

// renamed to -dataBits
- (int)getDataBits
{
	return [self dataBits];
}

// replaced by  -parity
- (BOOL)testParity
{
	// NO for "no parity"
	return (options->c_cflag & PARENB);
}

// replaced by  -parity
- (BOOL)testParityOdd
{
	// meaningful only if TestParity == YES
	return (options->c_cflag & PARODD);
}

// replaced by  -setParity:
- (void)setParityNone
{
	options->c_cflag &= ~PARENB;
}

// replaced by  -setParity:
- (void)setParityEven
{
	options->c_cflag |= PARENB;
	options->c_cflag &= ~PARODD;
}

// replaced by  -setParity:
- (void)setParityOdd
{
	options->c_cflag |= PARENB;
	options->c_cflag |= PARODD;
}

// renamed to -stopBits;
- (int)getStopBits
{
	return [self stopBits];
}

// replaced by  -setStopBits:
- (void)setStopBits2:(BOOL)two
{
	// YES for 2 stop bits, NO for 1 stop bit
	if (two) {
		[self setStopBits:kAMSerialStopBitsTwo];
	} else {
		[self setStopBits:kAMSerialStopBitsOne];
	}
}
																	
// renamed to -echoEnabled
- (BOOL)testEchoEnabled
{
	return [self echoEnabled];
}

// renamed to -RTSInputFlowControl
- (BOOL)testRTSInputFlowControl
{
	return [self RTSInputFlowControl];
}

// renamed to -DTRInputFlowControl
- (BOOL)testDTRInputFlowControl
{
	return [self DTRInputFlowControl];
}

// renamed to -CTSOutputFlowControl
- (BOOL)testCTSOutputFlowControl
{
	return [self CTSOutputFlowControl];
}

// renamed to -DSROutputFlowControl
- (BOOL)testDSROutputFlowControl
{
	return [self DSROutputFlowControl];
}

// renamed to -CAROutputFlowControl
- (BOOL)testCAROutputFlowControl
{
	return [self CAROutputFlowControl];
}

// renamed to -hangupOnClose
- (BOOL)testHangupOnClose
{
	return [self hangupOnClose];
}

// renamed to -localMode
- (BOOL)getLocal
{
	return [self localMode];
}

// renamed to -setLocalMode:
- (void)setLocal:(BOOL)local
{
	return [self setLocalMode:local];
}

// renamed to -bytesAvailable
- (int)checkRead
{
	return [self bytesAvailable];
}

// replaced by  -readStringUsingEncoding:error:
- (NSString *)readString
{
	return [self readStringUsingEncoding:NSMacOSRomanStringEncoding error:NULL];
}

// replaced by  -readBytes:usingEncoding:error:
- (NSString *)readStringOfLength:(unsigned int)length
{
	return [self readBytes:length usingEncoding:NSMacOSRomanStringEncoding error:NULL];
}

// replaced by  -writeString:usingEncoding:error:
- (int)writeString:(NSString *)string
{
	int result = 0;
	NSError *error;
	[self writeString:string usingEncoding:NSMacOSRomanStringEncoding error:&error];
	if (error) {
		NSDictionary *userInfo = [error userInfo];
		if (userInfo) {
			result = [[userInfo objectForKey:@"bytesWritten"] intValue];
		}
	}
	return result;
}

// renamed to -flushInput:output:
- (BOOL)flushInput:(BOOL)fIn Output:(BOOL)fOut
{
	return [self flushInput:fIn output:fOut];
}

@end
