// Sample2
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
  DueAdcF.EnablePin(A2);

  // indicate at what speed in the background 

  DueAdcF.Start1Mhz();       // max speed 1Mhz (sampling rate)

  //DueAdcF.Start();         // normal speed 667 Khz (sampling rate)
  
  //DueAdcF.Start(255);      // with prescaler value form 3 to 255.
                             // 255 is approx. 7812 Hz (sampling rate)
 
 Serial.println("Sample2");
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
 uint32_t xvalA2;

 // FindValueForPin not wait !
 // FindValueForPin looks in the Buffer and returns the last available measurement for the requested pin.
 // In this example we have enabled 3 pins and every 1 microsecond one of them is converted in sequence.
 // Then FindValueForPin will return the value of the pin that was 1 or 2 or 3 or Zero microseconds ago! 

 xvalA0 = DueAdcF.FindValueForPin(A0);   
 xvalA1 = DueAdcF.FindValueForPin(A1);  
 xvalA2 = DueAdcF.FindValueForPin(A2);  

 // Be patient and see subsequent examples !
                           
 Serial.println(xvalA0);
 Serial.println(xvalA1);
 Serial.println(xvalA2);

 delay(1500);

}
