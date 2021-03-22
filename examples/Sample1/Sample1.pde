// Sample1
#include <DueAdcFast.h>

DueAdcFast DueAdcF(1024);

// 1024 measures is dimension of internal buffer. (min is 1024)


void setup() {

  Serial.begin(115200);
  while (!Serial);

  analogReadResolution(12);
  // DueAdcF works at 12 bits regardless of this instruction

  // indicate the pins to be used with the library. 
  DueAdcF.EnablePin(A0);
  DueAdcF.EnablePin(A1);


  // indicate at what speed in the background 

  DueAdcF.Start1Mhz();       // max speed 1Mhz (sampling rate)

  //DueAdcF.Start();         // normal speed 667 Khz (sampling rate)
  
  //DueAdcF.Start(255);      // with prescaler value form 3 to 255.
                             // 255 is approx. 7812 Hz (sampling rate)

 Serial.println("Sample1");
}


// these 3 lines of code are essential for the functioning of the library
// you don't call ADC_Handler.
// is used automatically by the PDC every time it has filled the buffer
// and rewrite buffer.
// 
void ADC_Handler() {
  DueAdcF.adcHandler();
}


void loop() {

 uint32_t xvalA0;  // the variables of your code .
 uint32_t xvalA1;

 // like original analogRead but plus fast (if only 1 or 2 Pin enabled)

 xvalA0 = DueAdcF.ReadAnalogPin(A0);   
 xvalA1 = DueAdcF.ReadAnalogPin(A1);  

 // ReadAnalogPin wait for the PIN measurement to be available in the buffer
 // and returns the value, 12-bit values.
                                   
 Serial.println(xvalA0);
 Serial.println(xvalA1);

 delay(1500);

}
