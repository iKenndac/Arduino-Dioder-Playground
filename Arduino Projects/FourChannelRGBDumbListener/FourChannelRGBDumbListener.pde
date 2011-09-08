/*

This simple problem listens for incoming data in 12-byte
chunks, then pushes the values of those bytes down the
analog pins.

This is a really bad idea. If you (or someone else) pushes
random data to the Arduino with this listening, good luck
getting back in sync!

NOTE: This project requires Arduino Mega.

*/

const int channel1PinR = 2;
const int channel1PinG = 3;
const int channel1PinB = 4;

const int channel2PinR = 5;
const int channel2PinG = 6;
const int channel2PinB = 7;

const int channel3PinR = 8;
const int channel3PinG = 9;
const int channel3PinB = 10;

const int channel4PinR = 11;
const int channel4PinG = 12;
const int channel4PinB = 13;

void setup() {
  // set pins 2 through 13 as outputs:
  for (int thisPin = channel1PinR; thisPin <= channel4PinB; thisPin++) { 
    pinMode(thisPin, OUTPUT); 
    analogWrite(thisPin, 0);
  }

  // initialize the serial communication:
  Serial.begin(9600);  

}

void loop () {
  
  int availableBytes = Serial.available();
  
  if (availableBytes >= 12) {
     for (int thisPin = channel1PinR; thisPin <= channel4PinB; thisPin++) { 
        analogWrite(thisPin, Serial.read());
     }
  }
}
