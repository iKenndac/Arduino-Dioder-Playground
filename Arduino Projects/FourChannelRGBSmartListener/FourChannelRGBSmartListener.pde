/*

This simple program listens for incoming data in 12-byte
chunks, then pushes the values of those bytes down the
analog pins.

To keep a bit of sanity, the 12-byte chunks need to be preceded by
a two-byte header and tailed by a one-byte XOR checksum of the body.

No assumptions are made about colours except that there are twelve
channels starting at kChannel1FirstPin.

NOTE: This project requires Arduino Mega.
DOUBLE NOTE: This program implements the listening side of the messages
sent by all of the included Xcode projects. Don't use the DumbListener, 
because it's dumb.

*/

const int kChannel1FirstPin = 2;

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
  for (int thisPin = kChannel1FirstPin; thisPin < (kChannel1FirstPin + sizeof(receivedMessage)); thisPin++) { 
    pinMode(thisPin, OUTPUT); 
    analogWrite(thisPin, 255);
  }
  
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
      for (int i = 0; i < kProtocolBodyLength; i++) {
        analogWrite(i + kChannel1FirstPin, receivedMessage[i]);
      }
      
      Serial.print("OK");
      Serial.write(byte(10));
      
    } else {
      
      Serial.print("FAIL");
      Serial.write(byte(10));
    }
    
    appearToHaveValidMessage = false;
  }
}

