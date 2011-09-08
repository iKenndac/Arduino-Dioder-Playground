//
//  AMSerialPort_Deprecated.h
//  AMSerialTest
//
//  Created by Andreas on 26.07.06.
//  Copyright 2006-2009 Andreas Mayer. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "AMSerialPort.h"


@interface AMSerialPort (Deprecated)

- (id)init:(NSString *)path withName:(NSString *)name DEPRECATED_ATTRIBUTE;
// replaced by  -init:withName:type:

- (NSDictionary *)getOptions DEPRECATED_ATTRIBUTE;
// renamed to -options

- (long)getSpeed DEPRECATED_ATTRIBUTE;
// renamed to -speed

- (int)getDataBits DEPRECATED_ATTRIBUTE;
// renamed to -dataBits

- (BOOL)testParity DEPRECATED_ATTRIBUTE;			// NO for "no parity"
- (BOOL)testParity DEPRECATED_ATTRIBUTE;		// meaningful only if TestParity == YES
- (void)setParityNone DEPRECATED_ATTRIBUTE;
- (void)setParityEven DEPRECATED_ATTRIBUTE;
- (void)setParityOdd DEPRECATED_ATTRIBUTE;
// replaced by  -parity  and  -setParity:

- (int)getStopBits DEPRECATED_ATTRIBUTE;
// renamed to -stopBits;
- (void)setStopBits2:(BOOL)two DEPRECATED_ATTRIBUTE;		// YES for 2 stop bits, NO for 1 stop bit
// replaced by  -setStopBits:

- (BOOL)testEchoEnabled DEPRECATED_ATTRIBUTE;
// renamed to -echoEnabled

- (BOOL)testRTSInputFlowControl DEPRECATED_ATTRIBUTE;
// renamed to -RTSInputFlowControl

- (BOOL)testDTRInputFlowControl DEPRECATED_ATTRIBUTE;
// renamed to -DTRInputFlowControl

- (BOOL)testCTSOutputFlowControl DEPRECATED_ATTRIBUTE;
// renamed to -CTSOutputFlowControl

- (BOOL)testDSROutputFlowControl DEPRECATED_ATTRIBUTE;
// renamed to -DSROutputFlowControl

- (BOOL)testCAROutputFlowControl DEPRECATED_ATTRIBUTE;
// renamed to -CAROutputFlowControl

- (BOOL)testHangupOnClose DEPRECATED_ATTRIBUTE;
// renamed to -hangupOnClose

- (BOOL)getLocal DEPRECATED_ATTRIBUTE;
// renamed to -localMode

- (void)setLocal:(BOOL)local DEPRECATED_ATTRIBUTE;
// renamed to -setLocalMode:

- (int)checkRead DEPRECATED_ATTRIBUTE;
// renamed to -bytesAvailable

- (NSString *)readString DEPRECATED_ATTRIBUTE;
// replaced by  -readStringUsingEncoding:error:

- (NSString *)readStringOfLength:(unsigned int)length DEPRECATED_ATTRIBUTE;
// replaced by  -readBytes:usingEncoding:error:

- (int)writeString:(NSString *)string DEPRECATED_ATTRIBUTE;
// replaced by  -writeString:usingEncoding:error:

- (BOOL)flushInput:(BOOL)fIn Output:(BOOL)fOut DEPRECATED_ATTRIBUTE;
// renamed to -flushInput:output:

@end
