/*

This simple program listens for incoming data in 12-byte
chunks, then pushes the values of those bytes down the
analog pins.

To keep a bit of sanity, the 12-byte chunks need to be preceded by
a two-byte header and tailed by a one-byte XOR checksum of the body.

No assumptions are made about colours except that there are twelve
channels starting at kChannel1FirstPin.

NOTE: This project requires Arduino Uno, and only supports the first two colours.
DOUBLE NOTE: This program implements the listening side of the messages
sent by all of the included Xcode projects. Don't use the DumbListener, 
because it's dumb.

*/

const int kChannel1FirstPin = 3;
const int kChannel1SecondPin = 5;
const int kChannel1ThirdPin = 6;

const int kChannel2FirstPin = 9;
const int kChannel2SecondPin = 10;
const int kChannel2ThirdPin = 11;

// Protocol details (two header bytes, 12 value bytes, checksum)

const int kProtocolHeaderFirstByte = 0xBA;
const int kProtocolHeaderSecondByte = 0xBE;

const int kProtocolHeaderLength = 2;
const int kProtocolBodyLength = 12;
const int kProtocolChecksumLength = 1;

// Buffers and state

bool appearToHaveValidMessage;
byte receivedMessage[12];

void setup() {
  // set pins 2 through 13 as outputs:
  pinMode(kChannel1FirstPin, OUTPUT);
  
  pinMode(kChannel1SecondPin, OUTPUT);
  pinMode(kChannel1ThirdPin, OUTPUT);
  
  pinMode(kChannel2FirstPin, OUTPUT);
  pinMode(kChannel2SecondPin, OUTPUT);
  pinMode(kChannel2ThirdPin, OUTPUT);
  
  analogWrite(kChannel1FirstPin, 255);
  analogWrite(kChannel1SecondPin, 255);
  analogWrite(kChannel1ThirdPin, 255);
  
  analogWrite(kChannel1FirstPin, 255);
  analogWrite(kChannel2SecondPin, 255);
  analogWrite(kChannel2ThirdPin, 255);
  
  appearToHaveValidMessage = false;

  // initialize the serial communication:
  Serial.begin(57600);
}


void loop () {
  
  int availableBytes = Serial.available();
  
  if (!appearToHaveValidMessage) {
    
    // If we haven't found a header yet, look for one.
    if (availableBytes >= kProtocolHeaderLength) {
      
      // Read then peek in case we're only one byte away from the header.
      byte firstByte = Serial.read();
      byte secondByte = Serial.peek();
      
      if (firstByte == kProtocolHeaderFirstByte &&
          secondByte == kProtocolHeaderSecondByte) {
            
          // We have a valid header. We might have a valid message!
          appearToHaveValidMessage = true;
          
          // Read the second header byte out of the buffer and refresh the buffer count.
          Serial.read();
          availableBytes = Serial.available();
      }
    }
  }
  
  if (availableBytes >= (kProtocolBodyLength + kProtocolChecksumLength) && appearToHaveValidMessage) {
     
    // Read in the body, calculating the checksum as we go.
    byte calculatedChecksum = 0;
    
    for (int i = 0; i < kProtocolBodyLength; i++) {
      receivedMessage[i] = Serial.read();
      calculatedChecksum ^= receivedMessage[i];
    }
    
    byte receivedChecksum = Serial.read();
    
    if (receivedChecksum == calculatedChecksum) {
      // Hooray! Push the values to the output pins.
      
      analogWrite(kChannel1FirstPin, receivedMessage[0]);
      analogWrite(kChannel1SecondPin, receivedMessage[1]);
      analogWrite(kChannel1ThirdPin, receivedMessage[2]);
      
      analogWrite(kChannel2FirstPin, receivedMessage[3]);
      analogWrite(kChannel2SecondPin, receivedMessage[4]);
      analogWrite(kChannel2ThirdPin, receivedMessage[5]);
      
      
      Serial.print("OK");
      Serial.write(byte(10));
      
    } else {
      
      Serial.print("FAIL");
      Serial.write(byte(10));
    }
    
    appearToHaveValidMessage = false;
  }
}

