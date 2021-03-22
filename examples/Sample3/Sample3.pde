// Sample3
#include <DueAdcFast.h>

DueAdcFast DueAdcF(1024);  // 1024 measures is dimension of internal buffer. (min is 1024)

DueAdcFastMeasure lastMis[100];  // buffer is 1024 elements these are 100 measures copied from the buffer. 

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

  //DueAdcF.Start1Mhz();       // max speed 1Mhz (sampling rate)

  //DueAdcF.Start();         // normal speed 667 Khz (sampling rate)
  
  DueAdcF.Start(255);        // with prescaler value form 3 to 255.
                             // 255 is approx. 7812 Hz (sampling rate)
 
 Serial.println("Sample3");
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
