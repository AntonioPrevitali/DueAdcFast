#include <Arduino.h>
#if defined(__SAM3X8E__)
#include "DueAdcFast.h"

/*
  DueAdcFast.h - DueAdcFast Implementation file
  For instructions, go to https://github.com/AntonioPrevitali/DueAdcFast
  Created by Antonio Previtali March, 2021.
  
  This library is free software; you can redistribute it and/or
  modify it under the terms of the Gnu general public license version 3
*/

DueAdcFast::DueAdcFast(uint16_t sizeBuffer)
{
  // size check 0 or 1024 e superiori
  if (sizeBuffer != 0 && sizeBuffer < 1024) BufSiz = 1024; else BufSiz = sizeBuffer;
  if (BufSiz > 0)
  {
    // buffer allocate and set to zero.
    Buffer = new(uint16_t[BufSiz * 2]); // uint16_t is 2 byte
    if (Buffer)
    {
      memset(Buffer, 0xFF, BufSiz * 2); // clear 00 is CHNB valid!
    }
  }
}


DueAdcFast::~DueAdcFast()
{
  // deallocate buffer
  if (Buffer)
  {
    delete Buffer;
  }
}


void DueAdcFast::EnablePin(uint8_t pin)
{
  if (pin >= 54 && pin <= 65)
  {
    pin = pin - 54;
    enablPin |= (1 << pin);
  }
}

void DueAdcFast::EnableDif(uint8_t pin)
{
  // CH      PIN          PIN possible in diff mode.
  // ADC7    A0  (54)
  // ADC6    A1           DIFF A1 - A0
  // ADC5    A2
  // ADC4    A3           DIFF A3 - A2
  // ADC3    A4
  // ADC2    A5           DIFF A5 - A4
  // ADC1    A6
  // ADC0    A7           DIFF A7 - A6
  // ADC10   A8           DIFF A8 - A9
  // ADC11   A9
  // ADC12   A10          DIFF A10 - A11
  // ADC13   A11 (65)
  //
  //
  // In Buffer ho riscontrato che l'ordine con cui arrivano i dati in memoria
  // (nel caso che vengano abilitati tutti i canali) è:
  // ADC0 ... ADC7 ADC10 ADC11 ADC12 ADC13 corrispondenti ai pin A7 A6 A5 A4 A3 A2 A1 A0 A8 A9 A10 A11
  // la cosa non pone problema perchè viene sincronizzato grazie al TAG.
  //
  if (pin >= 54 && pin <= 65)
  {
    pin = pin - 54;
    if (pin == 1)
    {
      enablDif |= (1 << pin);          // A1 in differential mode
      enablPin |= (1 << pin);          // A1 enabled
      enablPin &= 0B1111111111111110;  // A0 disable altready in differential mode from A1
    }
    if (pin == 3)
    {
      enablDif |= (1 << pin);          // DIFF A3 - A2
      enablPin |= (1 << pin);
      enablPin &= 0B1111111111111011;
    }
    if (pin == 5)
    {
      enablDif |= (1 << pin);          // DIFF A5 - A4
      enablPin |= (1 << pin);
      enablPin &= 0B1111111111101111;
    }
    if (pin == 7)
    {
      enablDif |= (1 << pin);          // DIFF A7 - A6
      enablPin |= (1 << pin);
      enablPin &= 0B1111111110111111;
    }
    if (pin == 8)
    {
      enablDif |= (1 << pin);          // DIFF A8 - A9
      enablPin |= (1 << pin);
      enablPin &= 0B1111110111111111;
    }
    if (pin == 10 )
    {
      enablDif |= (1 << pin);          // DIFF A10 - A11
      enablPin |= (1 << pin);
      enablPin &= 0B1111011111111111;
    }
  }
}

// disabilita i pin abilitati precedentemente con EnablePin/Dif
// da usare dopo lo stop se si vuole cambiare i pin e ripartire
void DueAdcFast::DisEnabPin(void)
{
  enablPin = 0;
  enablDif = 0;
  allDifGain = 0;
}

void DueAdcFast::memRegister()
{
  memCHSR = ADC->ADC_CHSR;  // channel
  memIMR  = ADC->ADC_IMR;   // interrupt
  memMR   = ADC->ADC_MR;    // mode register
  memRPR  = ADC->ADC_RPR;   // pointer and counter
  memRCR  = ADC->ADC_RCR;
  memRNPR = ADC->ADC_RNPR;
  memRNCR = ADC->ADC_RNCR;
  memPTSR = ADC->ADC_PTSR;  // Transfer Control Register  PTSR PTCR fare prima disable...
  memCGR  = ADC->ADC_CGR;   // gain
  memCOR  = ADC->ADC_COR;   // offset diff
  memEMR  = ADC->ADC_EMR;   // Extended Mode for TAG
}


void DueAdcFast::Start()
{
  gostart(false, 2);
}

void DueAdcFast::Start1Mhz()
{
  gostart(true, 1);
}

void DueAdcFast::Start(uint8_t prescaler)
{
  if (prescaler == 0) prescaler = 1; // not at 42 Mhz ADclock ! max 21Mhz.
  gostart(true, (uint16_t) prescaler);
}

void DueAdcFast::SetAllDifGain(uint8_t xgain)
{
 if (xgain <= 2) allDifGain = xgain; 
}

void DueAdcFast::gostart(boolean x21, uint16_t prescaler)
{
  uint32_t xcher = 0;
  uint32_t xcor = 0;
  uint32_t xcgr = 0;
  uint32_t xbit = 0;
  // determina i canali differenziali
  xbit = !!(enablDif & 2);  // DIFF A1 - A0
  if (xbit)
  {
    xcor |=  ADC_COR_DIFF6
             | ADC_COR_DIFF7
             | ADC_COR_OFF6
             | ADC_COR_OFF7;
    xcgr |=  ADC_CGR_GAIN6(allDifGain)
             | ADC_CGR_GAIN7(allDifGain);
    enablPin &= 0B1111111111111110;  // A0 disable altready in differential mode from A1
  }
  xbit = !!(enablDif & 8);  // DIFF A3 - A2
  if (xbit)
  {
    xcor |=  ADC_COR_DIFF4
             | ADC_COR_DIFF5
             | ADC_COR_OFF4
             | ADC_COR_OFF5;
    xcgr |=  ADC_CGR_GAIN4(allDifGain)
             | ADC_CGR_GAIN5(allDifGain);             
    enablPin &= 0B1111111111111011;
  }
  xbit = !!(enablDif & 32);  // DIFF A5 - A4
  if (xbit)
  {
    xcor |=  ADC_COR_DIFF2
             | ADC_COR_DIFF3
             | ADC_COR_OFF2
             | ADC_COR_OFF3;
    xcgr |=  ADC_CGR_GAIN2(allDifGain)
             | ADC_CGR_GAIN3(allDifGain);             
    enablPin &= 0B1111111111101111;
  }
  xbit = !!(enablDif & 128);  // DIFF A7 - A6
  if (xbit)
  {
    xcor |=  ADC_COR_DIFF0
             | ADC_COR_DIFF1
             | ADC_COR_OFF0
             | ADC_COR_OFF1;
    xcgr |=  ADC_CGR_GAIN0(allDifGain)
             | ADC_CGR_GAIN1(allDifGain);             
    enablPin &= 0B1111111110111111;
  }
  xbit = !!(enablDif & 256);  // DIFF A8 - A9
  if (xbit)
  {
    xcor |=  ADC_COR_DIFF10
             | ADC_COR_DIFF11
             | ADC_COR_OFF10
             | ADC_COR_OFF11;
    xcgr |=  ADC_CGR_GAIN10(allDifGain)
             | ADC_CGR_GAIN11(allDifGain);             
    enablPin &= 0B1111110111111111;
  }
  xbit = !!(enablDif & 1024);  // DIFF A10 - A11
  if (xbit)
  {
    xcor |=  ADC_COR_DIFF12
             | ADC_COR_DIFF13
             | ADC_COR_OFF12
             | ADC_COR_OFF13;
    xcgr |=  ADC_CGR_GAIN12(allDifGain)
             | ADC_CGR_GAIN13(allDifGain);             
    enablPin &= 0B1111011111111111;
  }
  // determina in base ai Pin quali canali ADC abilitare.
  NumChEn = 0;
  xbit = !!(enablPin & 1);  // A0
  if (xbit) NumChEn++;
  xbit = xbit << 7; // ACD7
  xcher |= xbit;
  xbit = !!(enablPin & 2);  // A1
  if (xbit) NumChEn++;
  xbit = xbit << 6; // ACD6
  xcher |= xbit;
  xbit = !!(enablPin & 4);  // A2
  if (xbit) NumChEn++;
  xbit = xbit << 5;
  xcher |= xbit;
  xbit = !!(enablPin & 8);  // A3
  if (xbit) NumChEn++;
  xbit = xbit << 4;
  xcher |= xbit;
  xbit = !!(enablPin & 16);  // A4
  if (xbit) NumChEn++;
  xbit = xbit << 3;
  xcher |= xbit;
  xbit = !!(enablPin & 32);  // A5
  if (xbit) NumChEn++;
  xbit = xbit << 2;
  xcher |= xbit;
  xbit = !!(enablPin & 64);  // A6
  if (xbit) NumChEn++;
  xbit = xbit << 1;
  xcher |= xbit;
  xbit = !!(enablPin & 128);  // A7
  if (xbit) NumChEn++;
  //xbit = xbit<<0;
  xcher |= xbit;
  xbit = !!(enablPin & 256);  // A8
  if (xbit) NumChEn++;
  xbit = xbit << 10;
  xcher |= xbit;
  xbit = !!(enablPin & 512);  // A9
  if (xbit) NumChEn++;
  xbit = xbit << 11;
  xcher |= xbit;
  xbit = !!(enablPin & 1024); // A10
  if (xbit) NumChEn++;
  xbit = xbit << 12;
  xcher |= xbit;
  xbit = !!(enablPin & 2048); // A11
  if (xbit) NumChEn++;
  xbit = xbit << 13;
  xcher |= xbit;
  if (!okStart)
  {
    if (enablPin && Buffer) // start only if enabled pin e buffer allocated...
    {
      memset(Buffer, 0xFF, BufSiz * 2); // clear buffer.
      memRegister();      // to restore state at stop..
      ADC->ADC_MR = 0x10380200;       // is default arduino DUE
      ADC->ADC_IDR = ~ADC_IDR_ENDRX;  // all disable (not ENDRX)
      ADC->ADC_IER = ADC_IER_ENDRX;   // enable ENDRX
      ADC->ADC_RPR = (uint32_t)Buffer; // DMA buffer
      ADC->ADC_RCR = BufSiz;
      ADC->ADC_RNPR = (uint32_t)Buffer;
      ADC->ADC_RNCR = BufSiz;
      lastRPR = ADC->ADC_RPR;    // to check change
      MeasRPR = 0;               // ok zero see code.
      NVIC_EnableIRQ(ADC_IRQn);  // default is disabled...
      ADC->ADC_PTCR = 1;
      okHandler = true;
      ADC->ADC_CGR = xcgr;       // GAIN
      ADC->ADC_CHER = xcher;          // enable channels
      ADC->ADC_CHDR = ~xcher;         // disable channels
      enabcha = xcher;                // for use later see code
      ADC->ADC_COR = xcor;   // differential channels, offset
      ADC->ADC_EMR |= (1 << 24); // TAG mode.
      // 0001 1000 1011 1000 0000 0001 0000 0000 = 0x18B80100
      //   Transfer 1 then 5 ADCClock periods.
      //      Traktim 8 then 9 ADCClock periods.
      //           ANACH
      //             Settling 3 then 17 ADCClock.
      //                startup 8 then 512 ADCClock.
      //                     Prescaler 1 then ADCClock=21Mhz.
      //                                freerun=later
      // Differense with default is
      //  Traktim 8 then 9 ADCClock periods.
      //  ANACH
      //  prescaler at 21Mhz default is 14 Mhz
      //
      if (x21)
        ADC->ADC_MR =  0x18B80000;  // 21 Mhz diventa dopo prescaler 0x18B80100
      else
        ADC->ADC_MR =  0x18B80000;  // 14 Mhz diventa 0x18B80200
      // mette il prescaler.
      ADC->ADC_MR |=  prescaler << 8; 
      //-- forse in una prossima release
      //-- per ora non mi convince
      //-- sarebbe da indagare per CHER
      //-- e CHSR...
      // ADC->ADC_SEQR1 = 0x01234567;
      // ADC->ADC_SEQR2 = 0x00DCBA00;
      // ADC->ADC_MR |= 1u<<31;  // USEQ
      //--------------------------------
      ADC->ADC_MR |= 0x80; // OK go.
      okStart = true;
      // attende che vengano riempite le prime NumChEn misure.
      while (ADC->ADC_RCR > BufSiz - NumChEn);
    }
  }
}


float DueAdcFast::MeasureSpeed()
{
  uint32_t xnHand;
  uint32_t xTimeIniz;
  uint32_t xTimeFinal;
  uint32_t deltaT;
  float xr;
  if (!okStart) return 0; // only if start...
  xnHand = countHand;
  while (countHand == xnHand) ; // whait change
  xTimeIniz = micros();
  xnHand = countHand;
  while (countHand == xnHand) ; // whait change
  xTimeFinal = micros();
  deltaT =  xTimeFinal - xTimeIniz;
  // use float deltaT / (BufSiz / NumChEn)
  xr = (float) deltaT / ( (float) BufSiz / (float) NumChEn);
  return xr;
}


void DueAdcFast::adcHandler()
{
  if (okHandler)
  {
    if (ADC->ADC_ISR & ADC_ISR_ENDRX)
    {
      ADC->ADC_RNPR = (uint32_t)Buffer;
      ADC->ADC_RNCR = BufSiz;
      countHand++;
    }
  }
}


void DueAdcFast::Stop()
{
  if (okStart) // only if start...
  {
    // stop free running
    ADC->ADC_MR &= 0xFFFFFF7F;
    delayMicroseconds(2);   // terminate current measure ?!
    lastRPR = ADC->ADC_RPR;       // pointer and micros at stop
    lastMs  = micros();           // Buffer rimane pieno con le misure...
    ADC->ADC_PTCR = 2;            //  Disables the PDC receiver channel requests
    ADC->ADC_IDR = ADC_IDR_ENDRX; //  Disable ENDRX
    NVIC_DisableIRQ(ADC_IRQn);   // default is disabled...
    okHandler = false;
    ADC->ADC_CHDR = ~memCHSR;
    ADC->ADC_CHER = memCHSR;     // enable original channels arduino default (last analogread..)
    ADC->ADC_IDR = ~memIMR;
    ADC->ADC_IER = memIMR;   // enable original interrupt arduino default (none)
    ADC->ADC_RPR = memRPR;   // pointer counter
    ADC->ADC_RCR = memRCR;
    ADC->ADC_RNPR = memRNPR;
    ADC->ADC_RNCR = memRNCR;
    ADC->ADC_PTCR = memPTSR; // default is none see ADC->ADC_PTCR = 2 upper...
    ADC->ADC_CGR = memCGR;  // GAIN
    ADC->ADC_COR = memCOR;  // offset e diff...
    ADC->ADC_EMR = memEMR;  // tag
    ADC->ADC_MR  = memMR;   // mode original
    okStart = false;
  }
}


uint32_t DueAdcFast::ReadAnalogPin(uint8_t pin)
{
  uint16_t xch;
  uint16_t xval;
  uint16_t xchL;
  uint16_t* prpr;
  uint32_t  curRPR;
  /*  --- only for debug...
    uint16_t Buffer2[BufSiz];
    static boolean xonetime=false;
    if (!xonetime) {
     xonetime = true;
     memcpy(Buffer2,Buffer,BufSiz*2);
     Serial.println("Situazione");
     for(int xi=0;xi<100;xi++)
     {
       Serial.println(Buffer2[xi]);
     }
    }
    ------- */
  if (okStart == false || pin < 54 || pin > 65) return 0xFFFF;
  xch = g_APinDescription[pin].ulADCChannelNumber; // channel to wait
  // controlla se canale e tra quelli che vengono raccolti/abilitati
  if (!( enabcha & (1 << xch) )) return 0xFFFF;  // canale non enabled
  xch = xch << 12; // like format of CHNB TAG  
  do
  {
    // vede se nuovo rpr o attende nuovo rpr
    do curRPR = ADC->ADC_RPR; while (curRPR == lastRPR);
    lastRPR = curRPR;
    // indietro di uno c'è il valore.
    prpr = (uint16_t*) curRPR;
    prpr--; // DMA carica valore e avanza il pointer.
    if (prpr < Buffer) prpr = Buffer + BufSiz - 1;
    xval = *prpr;
    xchL = xval & 0xF000;  // CHNB TAG test
  } while (xch != xchL);
  return xval & 0xFFF;
}


// cerca nel Buffer l'ultima misura disponibile per quel pin.
uint32_t DueAdcFast::FindValueForPin(uint8_t pin)
{
  uint16_t xch;
  uint16_t xval;
  uint16_t xchL;
  uint16_t* prpr;
  uint32_t  curRPR;
  uint16_t  xi;
  if (okStart == false || pin < 54 || pin > 65) return 0xFFFF;
  xch = g_APinDescription[pin].ulADCChannelNumber; // channel to wait
  // controlla se canale e tra quelli che vengono raccolti/abilitati
  if (!( enabcha & (1 << xch) )) return 0xFFFF;  // canale non enabled
  xch = xch << 12; // like format of CHNB TAG
  curRPR = ADC->ADC_RPR;
  prpr = (uint16_t*) curRPR;
  // observe max last NumChEn measure...
  for (xi = 0; xi < NumChEn; xi++)
  {
    prpr--; // DMA carica valore e avanza il pointer.
    if (prpr < Buffer) prpr = Buffer + BufSiz - 1;
    xval = *prpr;
    xchL = xval & 0xF000;  // CHNB TAG test
    if (xch == xchL)
      return xval & 0xFFF; // ok found
  }
  return 0xFFFF;  // not found !
}


uint32_t DueAdcFast::FindAvgForPin(uint8_t pin,uint16_t pSkip, uint16_t nrM)
{
  uint16_t xch;
  uint16_t xval;
  uint16_t xchL;
  uint16_t* prpr;
  uint32_t curRPR;
  uint16_t xi;
  uint32_t sumavg;
  boolean  okprimo;
  if (okStart == false || pin < 54 || pin > 65 || nrM == 0) return 0xFFFF;
  xch = g_APinDescription[pin].ulADCChannelNumber; // channel to wait
  // controlla se canale e tra quelli che vengono raccolti/abilitati
  if (!( enabcha & (1 << xch) )) return 0xFFFF;  // canale non enabled
  xch = xch << 12; // like format of CHNB TAG
  curRPR = ADC->ADC_RPR;
  prpr = (uint16_t*) curRPR;
  if (pSkip > 0)  // se richiesto indietreggia
  {
    prpr = prpr - pSkip;
    if (prpr < Buffer)
    {
      pSkip = Buffer - prpr;
      prpr = Buffer + BufSiz - pSkip;
    }
  }
  // qui cerca l'ultima misura disponibile x quel pin.
  // observe max last NumChEn measure...
  okprimo = false;
  sumavg = 0;
  for (xi = 0; xi < NumChEn; xi++)
  {
    prpr--; // DMA carica valore e avanza il pointer.
    if (prpr < Buffer) prpr = Buffer + BufSiz - 1;
    xval = *prpr;
    xchL = xval & 0xF000;  // CHNB TAG test
    if (xch == xchL)
      {
        okprimo = true;
        sumavg += (xval & 0xFFF);
        break;
      }
  }
  if (!okprimo) return  0xFFFF;  // not found !
  if (nrM == 1) return sumavg;
  // è già posizionato sul pin giusto per trovare i precedenti
  // è sufficiente indietreggiare di NumChEn  
  for (xi = 1; xi < nrM; xi++)  // parte da 1, uno già caricato in sumavg
  {
      prpr = prpr - NumChEn;   // salto indietro
      if (prpr < Buffer)
      {
        pSkip = Buffer - prpr;
        prpr = Buffer + BufSiz - pSkip;
      }
      xval = *prpr;
      xchL = xval & 0xF000;  
      if (xch != xchL) return 0xFFFF;  // CHNB TAG test NOT OK !
      sumavg += (xval & 0xFFF);
  }
  return sumavg / (uint32_t) nrM;
}


uint32_t DueAdcFast::to10BitResolution(uint32_t value)
{
  // convert value to 10 bit resolution (from 12bit)
  if (value == 0xFFFF) return value; // error...
  return value >> 2; // 12-10=2 bit shift !
}


// non usa buffer, non usa DMA è un ottimizzazione dell'originale.
// funziona se DueAdcFast non è in Start (deve essere in Stop..)
// è compatibile con originale solo se usata sul medesimo PIN.
// questa lavora solo a 12 bit eventualmente usa to10BitResolution
// E' piu veloce dell'originale
//
// volendo cosi miliora ancora...
//      ADC->ADC_MR = 0x18380100;  // 21Mhz...
//
uint32_t DueAdcFast::oldAnalogRead(uint8_t pin)
{
  uint32_t xcher;
  uint32_t xval;
  if (okStart || pin < 54 || pin > 65) return 0xFFFF;
  // fa una verifica sul channel status..
  // vede se il canale è già abilitato (esempio da precedente analogRead originale...)
  xcher = (1u << g_APinDescription[pin].ulADCChannelNumber);
  if (ADC->ADC_CHSR != xcher)
  {
    // non abilitato abilita.
    ADC->ADC_CHER = xcher;
    ADC->ADC_CHDR = ~xcher;
  }
  // adc_start
  ADC->ADC_CR = ADC_CR_START;
  // attende fine conversione
  while ((ADC->ADC_ISR & ADC_ISR_DRDY) != ADC_ISR_DRDY);
  // carica il valore convertito
  xval = ADC->ADC_LCDR;
  return xval;
}


// nrMeas = Numero di misure richieste
// meas[] = array dove caricare le misure richieste. NB size deve essere >= nrMeas
// La funzione ritorna :
//    Il numero di misure caricate in array (puo essere minore di nrMeas se non disponibili)
//    tramite il parametro *xtime la funzione ritorna al chiamante il tempo micros() dell'
//    ultima misura disponibile,  meas[0] = ultima misura disponibile/eseguita
//                                meas[1] = misura precedente piu vecchia.
//                                meas[n] = misura precedente precedente.
//
//  Se DueAdcFast è in Stop è possibile richiedere tutte le misure in Buffer.
//  Se DueAdcFast è in Start è consigliabile richiedere alcune misure, max 1/2 Buffer ?
//
uint16_t DueAdcFast::getMeasures(uint16_t nrMeas, DueAdcFastMeasure meas[], uint32_t* xtime)
{
  uint16_t* prpr;
  uint32_t  curRPR;
  uint16_t  nrm = 0;
  uint16_t  xval;
  uint16_t  xchL;
  uint16_t* prprMeas;
  if (okStart)
  {
    curRPR = ADC->ADC_RPR;
    if (MeasRPR == curRPR) return 0; // optimize speed.
    *xtime = micros();
  }
  else
  {
    curRPR = lastRPR;
    if (curRPR == 0) return 0;
    if (MeasRPR != 0 && MeasRPR == curRPR) return 0; // optimize speed.
    *xtime = lastMs;
  }
  // continua solo se buffer esiste
  if (!Buffer || BufSiz == 0 || nrMeas == 0) return 0;
  prpr = (uint16_t*) curRPR;
  prprMeas = (uint16_t*) MeasRPR;
  if (prprMeas !=0)
  {
    prprMeas--;
    if (prprMeas < Buffer) prprMeas = Buffer + BufSiz - 1;
  }
  for (nrm = 0; nrm < nrMeas; nrm++)
  {
    prpr--; // DMA carica valore e avanza il pointer.
    if (prpr < Buffer) prpr = Buffer + BufSiz - 1;
    if (prpr == prprMeas) break; // valore già restituito in precedente chiamata
    xval = *prpr;
    xchL = (xval & 0xF000) >> 12; // CHNB TAG
    xval &= 0xFFF;
    if (xchL == 0xF) break; // zona del buffer non ancora caricata.
    // ok carica la misura
    // xchL is already filtered and value is from 0 to 15 see upper & 0xF000)>12;
    meas[nrm].pin = chtopin[xchL];
    meas[nrm].val = xval;
  }
  MeasRPR = curRPR;
  return nrm;
}


// per testare se esistono misure disponibili prima di chiamare la getMeasures
// ma meglio è chiamare la getMeasures che ritorna zero se non ve ne sono.
// se chiamate isMeasures e subito dopo la getMeasures fate 2 volte il check
// e sprecate solo alcuni cicli di cpu.
//
boolean DueAdcFast::isMeasures(void)
{
  uint16_t* prpr;
  uint32_t  curRPR;
  uint16_t  xval;
  if (okStart)
  {
    curRPR = ADC->ADC_RPR;
  }
  else
  {
    curRPR = lastRPR;
    if (curRPR == 0) return false;
  }
  // continua solo se buffer esiste
  if (!Buffer || BufSiz == 0) return false;
  if (MeasRPR == 0)
  {
    if (curRPR == (uint32_t) Buffer) // non ancora partito oppure ha fatto un giro completo !
    {
       prpr = Buffer + BufSiz - 1;
       xval = *prpr;
       if (xval == 0xFFFF) return false; // non ha fatto un giro completo...
    }
    return true;
  }
  if (MeasRPR == curRPR) return false;
  return true;
}



/* -------- only for debug ---
  void DueAdcFast::Test()
  {
  Serial.print("enablPin=");
  Serial.println(enablPin,BIN);
  Serial.print("enablDif=");
  Serial.println(enablDif,BIN);
  Serial.print("ADC->ADC_CHSR=");
  Serial.println(ADC->ADC_CHSR,HEX);
  Serial.print("ADC->ADC_IMR=");
  Serial.println(ADC->ADC_IMR,HEX);
  Serial.print("ADC->ADC_MR=");
  Serial.println(ADC->ADC_MR,HEX);
  Serial.print("ADC->ADC_PTSR=");
  Serial.println(ADC->ADC_PTSR,HEX);
  Serial.print("ADC->ADC_CGR=");
  Serial.println(ADC->ADC_CGR,HEX);
  Serial.print("ADC->ADC_COR=");
  Serial.println(ADC->ADC_COR,HEX);
  Serial.print("ADC->ADC_EMR=");
  Serial.println(ADC->ADC_EMR,HEX);
  }
  ----------- */


#endif
