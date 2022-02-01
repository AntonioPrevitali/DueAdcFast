# Arduino DueAdcFast

Library is for Arduino DUE with SAM3X8E mcu only.
Implements fast analogRead 1Mhz with measures collect and also differential.

This library uses ADC and PDC in the background by loading the measurements in memory for you, in its circular buffer, without using the resources available for your code. 

The library then allows your code to interact with the buffer in memory obtaining the measurements, in a simple way like the original analogRead and in more complex ways. 

## Installation

library is now available in the arduino library manager. 
Then open the arduino library manager and search for DueAdcFast
Thanks to the library manager management team for adding this library. 

If you want to install manually do so:
1. [Download](https://github.com/AntonioPrevitali/DueAdcFast/releases) the Latest release from GitHub.
2. Remove the '-version' from Folder name and paste Folder on your Library folder.
3. Restart Arduino Software.


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
When you enable Pins you are indicating that you want that measurement but you are not indicating a sequence of pins, a reading order.
The reading order is invariable and is (if all 12 pins are enabled) 
A7 A6 A5 A4 A3 A2 A1 A0 A8 A9 A10 A11
you don't know at any given moment which one will be at the top of the buffer. In the example above, at the top was A1.
For this reason, always test ```lastMis[xi].pin``` 


#### if you have other patience there are other peculiarities

## Library Reference with TIPs and Warnings

- `DueAdcFast DueAdcF(1024);`  if you indicate a number less than 1024 an internal buffer of 1024 elements is created anyway, if you indicate more remember that using memory. each element consumes 2 bytes so 1024 = 2048 Bytes!
you can also indicate zero but it is a special case see below. 

- `EnablePin(uint8_t pin)` enabled pins. The pins must be enabled before the call to Start. pins cannot be enabled while DueAdcF is active/is Start. 
It is useless to enable the same pin several times.

- `Start() Start1Mhz() Start(uint8_t prescaler)` The library was initially designed to do only one initial start. The call to Start, set ADC and PDC, clears the Buffer and waits for some measures to be loaded into the buffer. (at least one of all those enabled).
It is possible to stop with Stop, and restart with another Start, it was not designed to be used like this, but it is very possible. Just consider that Start takes some time to do and that it clears the buffer. 

  After the Stop it is not necessary to redo EnablePin (uint8_t pin) however it is possible to call DisEnabPin () which disables all, and EnablePin (...) for pins you want for the next start.
  
  `Prescaler, from the datasceet of the mcu.   ADCClock = 84000000 / ( (PRESCAL+1) * 2 ).  About 22 ADCClocks are needed to make a measurement.`

- `Stop();`  Stop DueAdcFast, ADC and PDC is reprogrammed as arduino default, so it is possible, if you want, to use the original arduino analogread.
Do not use the original analogread while DueAdcFast is running.

- `float DueAdcFast::MeasureSpeed()` returns the rate at which the buffer fills.
  In particular, how many microseconds are needed to measure the enabled pins.

  Example if only 1 pin is enabled it will return about 1 microsecond, if enabled 2 pin it will return about 2 microseconds etc. etc.

  Actually this function waits for an entire buffer to be read (ex.1024 or more) then divides the time that has passed by (ex.1024/nr of the enabled pins)

  This only measures the times of the ADC and PDC does not measure the times needed to interface with the Buffer. For performance measurements see Sample4.ino 

- `DisEnabPin()` disables the pins previously enabled with EnablePin or EnableDif use only after the stop.

- `nrm = getMeasures(uint16_t nrMeas, DueAdcFastMeasure meas[], uint32_t* xtime)`

  nrMeas = number of desired / requested measurements.
  
  meas [] = Array where to load the requested measures, must have size> = a nrMeas.
  
  xtime = pointer to a uint32 where getMeasures returns the micros() time of measure loaded at meas[0].  
  
  meas[0] is the most recent measure.
  
  The getMeasures returns (in nrm) the number of elements loaded in meas[] or zero if there are no new measures to return.
 
- ` isMeasures()` to test if there are any measures available before calling getMeasures, but better is to call getMeasures which returns zero if there are none.

  if you call isMeasures and immediately after getMeasures do the check twice and just waste a few cycles of cpu. 
  
- ` to10BitResolution(uint32_t value)` convert value to 10 bit resolution (from 12bit).
  
- `oldAnalogRead(uint8_t pin)` does not use buffer, does not use PDC is only an optimization of the original.
  
  it works only if DueAdcFast is Stop (it must be in Stop ..)
  
  this works at 12 bit eventually use to10BitResolution
  
  use this or the original analogRead not both.
  
  This is slightly faster than the original, the code is very similar, yes copied code from the original but with some optimizations.
  
  If this is the only DueAdcFast function you use, use zero in the constructor, `DueAdcFast DueAdcF(0);` does not allocate the Buffer.  

## Measures with 2 pin in Differential mode.

`EnableDif(uint8_t pin)` 

In the differential mode, arduino uses 2 pins in a single conversion and returns the voltage difference between the two pins.  Example A1 - A0

In the differential mode, if the voltage difference between the two pins is zero, the returned value is 2047. (The zero is raised to 2047) 

If the voltage difference between the two pins is + 3.3V the returned value is 4095

If the voltage difference between the two pins is -3.3V the returned value is 0. 

Attention: None of the pins must be powered with negative voltage. and not even higher than 3.3 V otherwise destroy arduino! 

The pins are already paired in pairs and you can use these: 

DIFF A1 - A0

DIFF A3 - A2

DIFF A5 - A4

DIFF A7 - A6

DIFF A8 - A9

DIFF A10 - A11     (you can't do for example DIFF A8 - A3 !)

Per abilitare DIFF A1 - A0  write `EnableDif(A1);` // do not write A1-A0 or A0 write only A1 

Per abilitare DIFF A3 - A2  write `EnableDif(A3);` // A2 is implied not to use A2 write only A3

When you go read the value 

   `xval = DueAdcF.ReadAnalogPin(A1);`  // A1 A3 A5 ecc not A0 A2 A4 ecc...

It is also possible to do some pins in a differential way and some in a normal way (normal il called also Single ended mode) 

`EnableDif(A5);`

`EnablePin(A7);`   // obviously A4 is not available is already busy with A5


## Output of Sample4 is:

```Sample4 test...
let's start with 1000 original analogReads
1000 analogRead original time in microseconds is 4215
I enable pins A0 and A1 in DueAdcF 
Start now DueAdcF
DueAdcF.MeasureSpeed() return 2.00 microseconds (it is the time for the PDC in the background to make 2 measurements (nr. of pins enabled) 
1000 DueAdcF.ReadAnalogPin(A0) time is 2001
If you enable just one pin the ReadAnalogPin time will decrease to something like 1180
If you enable many pins the time will increase!, But FindValueForPin could to help
1000 DueAdcF.FindValueForPin(A0) time is 1507
DueAdcF.getMeasures return 512 measures. it takes to do this  285 microsecondi
PDC is hardware and runs at 1Mhz! But going into the buffer and getting the values takes time!
Ok stop DueAdcF and try with DueAdcF.oldAnalogRead
1000 DueAdcF.oldAnalogRead(A0) time is 2710
Thanks for your attention, and I hope DueAdcF is useful to you. If you liked DueAdcF put Star
```

## Version 1.1 adds 2 new methods :

`uint32_t FindAvgForPin(uint8_t pin,uint16_t pSkip, uint16_t nrM)`

Go to buffer, step back pSkip positions.
if pSkip zero does not step back.

look for the latest nrM measurements available for that pin;
averages the number of measurements and returns the value.


`void SetAllDifGain(uint8_t xgain)`

Set the gain for all differential channels (only for differential enabled pin)

xgain = 0 default               4095=+3.300v 0=-3.300v. return 4095 when +3.3 volt is on Pin, return 0 when -3.3 Volt is on Pin

xgain = 1 increased sensitivity 4095=+1.650v 0=-1.650v.

xgain = 2 even more sensitive   4095=+0.825v 0=-0.825v 

## Version 1.2 adds 2 new methods and add samples Ardu2GridTied :

`uint32_t GetPosCurr(void)`

Get the current position in the buffer to be used later with FindAvgForPinPos.
for example in an interrupt routine get the position and then in the loop code read the buffer.

`uint32_t FindAvgForPinPos(uint32_t xpos,uint8_t pin,uint16_t pSkip, uint16_t nrM)`

It's like FindAvgForPin but int32 must be passed in the first parameter, returned by GetPosCurr.

In the examples attached to this library I have added an entire project that uses this library.
The Ardu2GridTied code is provided as an example in this library, the documentation and future versions of Ardu2GridTied [here.](https://github.com/AntonioPrevitali/Ardu2GridTied)


