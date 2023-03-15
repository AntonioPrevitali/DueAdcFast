#include "Arduino.h"
#ifndef DUEADCFAST_h
#define DUEADCFAST_h
#if defined(ARDUINO_ARCH_SAM) && defined(__SAM3X8E__)
/*
  DueAdcFast.h - DueAdcFast header file
  For instructions, go to https://github.com/AntonioPrevitali/DueAdcFast
  Created by Antonio Previtali March, 2021.
  
  This library is free software; you can redistribute it and/or
  modify it under the terms of the Gnu general public license version 3
*/

typedef struct DueAdcFastMeasure
{
  uint8_t  pin ;
  uint16_t val ;
} DueAdcFastMeasure;


class DueAdcFast {
  public:
    DueAdcFast(uint16_t sizeBuffer);    // costruttore
    ~DueAdcFast();                      // distruttore
    void adcHandler();                  // entry ADC_Handler
    void EnablePin(uint8_t pin);        // Pin abilitati in single ended
    void EnableDif(uint8_t pin);        // Pin abilitati in differential mode
    void Start();                       // Start DueAdcFast at normal speed
    void Start1Mhz();                   // Start DueAdcFast at max speed (21Mhz AdClock)
    void Start(uint8_t prescaler);      // Start at Prescaler Rate.
    float MeasureSpeed();               // measure and return time in microseconds for convert all enabled pin 
    uint32_t ReadAnalogPin(uint8_t pin);   // attende che la misura sia disponibile e ritorna il valore.
	    // waits for the measurement to be available and returns the value.
    uint32_t FindValueForPin(uint8_t pin); // cerca nel Buffer l'ultima misura disponibile per quel pin.
	    // search the Buffer for the last measurement available for that pin
    void Stop();                         // Stop DueAdcFast.  Si può tornare ad usare la analogRead originale.
	    // You can go back to using the original analogRead
    void DisEnabPin(void);              // disabilita i pin abilitati precedentemente con EnablePin/Dif
	    // disable pins previously enabled with EnablePin/Dif
    uint16_t getMeasures(uint16_t nrMeas, DueAdcFastMeasure meas[], uint32_t* xtime); // see code..
    boolean  isMeasures(void);  // per testare se esistono misure disponibili prima di chiamare la getMeasures
                                // ma meglio è chiamare la getMeasures che ritorna zero se non ve ne sono.
                                // se chiamate isMeasures e subito dopo la getMeasures fate 2 volte il check
                                // e sprecate solo alcuni cicli di cpu.  
    // to test if there are any available measures before calling getMeasures
    // but better is to call getMeasures which returns zero if there are none.
    // if you call isMeasures and immediately after the GetMeasures you check
    // twice and just waste a few cpu cycles.

    uint32_t to10BitResolution(uint32_t value); // convert value to 10 bit resolution (from 12bit)
    uint32_t oldAnalogRead(uint8_t pin);   // non usa buffer, non usa DMA è un ottimizzazione dell'originale.
    // funziona se DueAdcFast non è in Start (deve essere in Stop..)
    // è compatibile con originale solo se usata sul medesimo PIN.
    // questa lavora solo a 12 bit eventualmente usa to10BitResolution

    // does not use buffer or DMA, is an optimization of the original.
    // it works if DueAdcFast is not in Start (must be in Stop..)
    // it is compatible with the original only if used on the same PIN.
    // this works only at 12 bit eventually to use 10 Bit Resolution

    // void Test();  // only for debug...

    uint32_t FindAvgForPin(uint8_t pin,uint16_t pSkip, uint16_t nrM); // Va nel buffer indietreggia di pSkip posizioni
                                                                      // se pSkip zero non indietreggia
                                                                      // cerca le ultime nrM misure disponibile per quel pin.
                                                                      // fa la media delle nrM misure e ritorna il valore.
	    // Goes to buffer backs of pSkip positions
	    // if pSkip zero does not back up
	    // look for the latest nrM measurements available for that pin.
	    // averages the nrM measurements and returns the value.
    void SetAllDifGain(uint8_t xgain);  // Imposta il Gain x tutti i canali differenziali 
	    // Set the Gain x all differential channels
                                        // xgain = 0 = default             4095=+3.300v 0=-3.300v
                                        // xgain = 1 sensibilita aumentata 4095=+1.650v 0=-1.650v
                                        // xgain = 2 ancora piu sensibile  4095=+0.825v 0=-0.825v                                                             
    uint32_t GetPosCurr(void);   // Consente di ottenere la posizione corrente nel buffer da utilizzare
                                 // poi con FindAvgForPinPos
	    // Gets the current position in the buffer to use
	    // then with FindAvgForPinPos
    uint32_t FindAvgForPinPos(uint32_t xpos,uint8_t pin,uint16_t pSkip, uint16_t nrM);


  private:
    const uint8_t    chtopin[16] = {A7, A6, A5, A4, A3, A2, A1, A0, 0, 0, A8, A9, A10, A11, 0, 0};
    volatile boolean okHandler = false;
    uint16_t         enablPin = 0;      // pin abilitati
    uint16_t         enablDif = 0;      // pin abilitati in differential mode.
    uint8_t          allDifGain = 0;    // Gain per i canali differenziali 0..2
    uint16_t         enabcha = 0;       // canali abilitati.
    boolean          okStart = false;   // true after Start is call
    uint16_t         BufSiz = 0;            // buffer size
    uint16_t*        Buffer = 0;        // buffer adress
    volatile uint32_t countHand = 0;    // counter interrupt handler
    uint32_t         lastRPR = 0;       // pointer at stop or at last ReadAnalogPin
    uint32_t         lastMs = 0;        // micros at stop, buffer rimane pieno con le misure...
    uint8_t          NumChEn = 0;       // numero di canali enabled.
    uint32_t         MeasRPR = 0;       // pointer last measures returned   
    uint32_t         memCHSR;           // ADC_CHSR
    uint32_t         memIMR;            // ADC_IMR
    uint32_t         memMR;             // ADC_MR
    uint32_t         memRPR;
    uint32_t         memRCR;
    uint32_t         memRNPR;
    uint32_t         memRNCR;
    uint32_t         memPTSR;           // PTSR PTCR
    uint32_t         memCGR;            // gain
    uint32_t         memCOR;            // offset diff
    uint32_t         memEMR;            // TAG
    void             memRegister();     // mem inital state register
    void             gostart(boolean x21, uint16_t prescaler);
};

#else
  #error "This libraries is for arduino DUE SAM3X8E cpu only"	
#endif
#endif
