/*
 * Sample4.ino 
 * 
 * The aim of this Sketch is to measure a little bit the performance of the DueAdcFast library.
 * also comparing it with the original analogRead. 
 *              
 *  This is an empirical method of measurement, but an acceptable one. 
 * 
 */


#include <DueAdcFast.h>

DueAdcFast DueAdcF(1024);

void setup() {

  DueAdcFastMeasure lastMis[512];

  uint32_t xTimeIniz;
  uint32_t xTimeFinal;
  uint32_t xval;
  uint32_t xtimeMicros;
  uint32_t xcurrentMicros;
  uint16_t xnrm;


  Serial.begin(19200);
  while (!Serial);

  Serial.println("Sample4 test...");

  analogReadResolution(12); // applies to the original analogRead DueAdcFast is only 12bit. 
  
  Serial.println("let's start with 1000 original analogReads");
  xTimeIniz = micros();
  for (int xi = 0; xi < 1000; xi++)
  {
    xval = analogRead(A0);
        if (xval == 0xFFFF) Serial.println("Error3");
  }
  xTimeFinal = micros();
  Serial.print("1000 analogRead original time in microseconds is ");
  Serial.println(xTimeFinal - xTimeIniz);

  Serial.println("I enable pins A0 and A1 in DueAdcF ");
  DueAdcF.EnablePin(A0);
  DueAdcF.EnablePin(A1);

  Serial.println("Start now DueAdcF"); 
  DueAdcF.Start1Mhz();         // max speed 1Mhz (sampling rate)


  Serial.print("DueAdcF.MeasureSpeed() return ");
  Serial.print(DueAdcF.MeasureSpeed());
  Serial.println(" microseconds (it is the time for the PDC in the background to make 2 measurements (nr. of pins enabled) ");

  xTimeIniz = micros();
  for (int xi = 0; xi < 1000; xi++)
  {
    xval = DueAdcF.ReadAnalogPin(A0);
  }
  xTimeFinal = micros();
  Serial.print("1000 DueAdcF.ReadAnalogPin(A0) time is ");
  Serial.println(xTimeFinal - xTimeIniz);

  Serial.println("If you enable just one pin the ReadAnalogPin time will decrease to something like 1180");
  Serial.println("If you enable many pins the time will increase!, But FindValueForPin could save the day");
  
  xTimeIniz = micros();
  for (int xi = 0; xi < 1000; xi++)
  {
    xval = DueAdcF.FindValueForPin(A0);
        if (xval == 0xFFFF) Serial.println("Error3");
  }
  xTimeFinal = micros();
  Serial.print("1000 DueAdcF.FindValueForPin(A0) time is ");
  Serial.println(xTimeFinal - xTimeIniz);


  xTimeIniz = micros();
  xnrm = DueAdcF.getMeasures(512, lastMis, &xtimeMicros);
  xTimeFinal = micros();
  Serial.print("DueAdcF.getMeasures return ");
  Serial.print(xnrm);
  Serial.print(" measures. it takes to do this  ");
  Serial.print(xTimeFinal - xTimeIniz);
  Serial.println(" microsecondi");

  Serial.println("PDC is hardware and runs at 1Mhz! But going into the buffer and getting the values takes time!");

  Serial.println("Ok stop DueAdcF and try with DueAdcF.oldAnalogRead");
  DueAdcF.Stop();

  xTimeIniz = micros();
  for (int xi = 0; xi < 1000; xi++)
  {
    xval = DueAdcF.oldAnalogRead(A0);
        if (xval == 0xFFFF) Serial.println("Error3");
  }
  xTimeFinal = micros();
  Serial.print("1000 DueAdcF.oldAnalogRead(A0) time is ");
  Serial.println(xTimeFinal - xTimeIniz);

  Serial.print("Thanks for your attention, and I hope DueAdcF is useful to you.");
  Serial.print("If you liked DueAdcF put a +! ");

// Output is:
// Sample4 test...
// let's start with 1000 original analogReads
// 1000 analogRead original time in microseconds is 4215
// I enable pins A0 and A1 in DueAdcF 
// Start now DueAdcF
// DueAdcF.MeasureSpeed() return 2.00 microseconds (it is the time for the PDC in the background to make 2 measurements (nr. of pins enabled) 
// 1000 DueAdcF.ReadAnalogPin(A0) time is 2001
// If you enable just one pin the ReadAnalogPin time will decrease to something like 1180
// If you enable many pins the time will increase!, But FindValueForPin could save the day
// 1000 DueAdcF.FindValueForPin(A0) time is 1507
// DueAdcF.getMeasures return 512 measures. it takes to do this  285 microsecondi
// PDC is hardware and runs at 1Mhz! But going into the buffer and getting the values takes time!
// Ok stop DueAdcF and try with DueAdcF.oldAnalogRead
// 1000 DueAdcF.oldAnalogRead(A0) time is 2710
// Thanks for your attention, and I hope DueAdcF is useful to you.If you liked DueAdcF put a +! 

}


void ADC_Handler() {
  DueAdcF.adcHandler();
}


void loop() {
 
}
