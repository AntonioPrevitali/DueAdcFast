# Arduino DueAdcFast

Library is for Arduino DUE with SAM3X8E mcu only.
Implements fast analogRead 1Mhz with measures collect and also differential.

This library uses ADC and PDC in the background by loading the measurements in memory for you, in its circular buffer, without using the resources available for your code. 

The library then allows your code to interact with the buffer in memory obtaining the measurements, in a simple way like the original analogRead and in more complex ways. 

## Installation

1. [Download](https://github.com/AntonioPrevitali/DueAdcFast/releases) the Latest release from GitHub.
2. Remove the '-version' from Folder name and paste Folder on your Library folder.
3. Restart Arduino Software.

Work in progress to make the library available in the arduino library manager. 

## Getting Started

```c++
#include <DueAdcFast.h>

DueAdcFast DueAdcF(1024); // 1024 measures is dimension of internal buffer. (min is 1024)

void setup() {
  analogReadResolution(12);   // DueAdcF works at 12 bits regardless of this instruction

  // indicate the pins to be used with the library. 
  DueAdcF.EnablePin(A0);
  DueAdcF.EnablePin(A1);

  // select what speed in the background buffer
  DueAdcF.Start1Mhz();       // max speed 1Mhz (sampling rate)

  //DueAdcF.Start();         // normal speed 667 Khz (sampling rate)
  
  //DueAdcF.Start(255);      // with prescaler value form 3 to 255.
                             // 255 is approx. 7812 Hz (sampling rate)
}

// these 3 lines of code are essential for the functioning of the library
// you don't call ADC_Handler.
// is used automatically by the PDC every time it has filled the buffer.
// 
void ADC_Handler() {
  DueAdcF.adcHandler();
}

void loop() {
 uint32_t xvalA0;  // the variables of your code .
 uint32_t xvalA1;

 // like original analogRead but plus fast (if only 1 or 2 Pin enabled else + slow)
 xvalA0 = DueAdcF.ReadAnalogPin(A0);   
 xvalA1 = DueAdcF.ReadAnalogPin(A1);  

 // ReadAnalogPin wait for the PIN measurement to be available in the buffer
 // and returns the value, 12-bit values.
 
 // Serial.println(xvalA0);
 // Serial.println(xvalA1);
 delay(1500);
}
```
Of course, used like this, the library is almost just a complication!
analogread original does the conversion and takes about 3 microseconds on average.
With the library every 1 microsecond, one of the enabled pins is converted in sequence.
DueAdcF.ReadAnalogPin waits for the background conversion to be done for the pin.

### Be patient and see a more complex use (sample2.ino)

```c++
  xvalA0 = DueAdcF.FindValueForPin(A0);   
  xvalA1 = DueAdcF.FindValueForPin(A1);
```
FindValueForPin not wait !
it looks in the Buffer and returns the last available measurement for the requested pin.
if we have enabled 2 pins, every 1 microsecond one of them is converted in sequence.
Then FindValueForPin will return the value of the pin that was 1 or 2 or Zero microseconds ago.

### a more complex use (sample3.ino)

```c++
void loop() {
 uint32_t xtimeMicros;
 uint16_t xnrm;

 delay(3000);  // wait 3 seconds, measures are updated in the buffer during this time. 

 xnrm = DueAdcF.getMeasures(100, lastMis, &xtimeMicros);
 if (xnrm > 0) // nr measures available to process. 
 {
       Serial.println("DueAdcF.getMeasures");
       Serial.print("xtimeMicros=");
       Serial.println(xtimeMicros);
       Serial.println("Misures:");
       for (int xi = 0; xi < xnrm; xi++)
       {
         // lastMis[xi].pin  contains which pin A0 A1 etc. 
         // lastMis[xi].val  contains the measure 
         Serial.print("A");                // only for formatting
         Serial.print(lastMis[xi].pin-A0); // A0 constant is 54 A1 is 55 ecc
         Serial.print(" ");
         Serial.println(lastMis[xi].val);
       }
       Serial.println("-------------------------");
 }
}
```
```
Output is:
Sample3
DueAdcF.getMeasures
xtimeMicros=3005002
Misures:
A1 1251 misure at xtimeMicros
A2 1286 old misure
A0 1284 old old misure ecc ecc.
A1 1252
A2 1286
A0 1282
A1 1249
A2 1283
ecc ecc...
-------------------------
```
#### if you have other patience there are other peculiarities

## Library Reference with TIPs and Warnings

work in progress
