/* 
 * For instructions, go to https://github.com/AntonioPrevitali/Ardu2GridTied
 * Created by Antonio Previtali in year 2021.
 * Email is : antonio_prev@hotmail.com
 * 
 * This code is free software; you can redistribute it and/or
 * modify it under the terms of the Gnu general public license version 3
 *
 *  
 *  31/01/2022      ATTENZIONE Cambiano ancora i PIN quindi si taglia ancora con le
 *                  precedenti versioni.
 *                  
 *                  E' un generatore quindi NON collegare direttamente alla rete.
 *                  Se lo fai bruci di sicuro il tutto !
 *                  
 *                  Sulla gamba1 viene fatto PWM a 20khz sia in low side che in hi side
 *                  con dead time hardware.
 *                  
 *                  Sulla gamba2 viene seguita la rete a 50 Hz
 *                  la seconda gamba del ponte sia hi-side che lo-side lavorano a 50Hz. 
 *  
 *                  Il sincronismo avviene confrontando se anticipa o se ritarda e 
 *                  correggendo opportunamente il periodo successivo.
 *                  NB si interviene a stringere o allungare il periodo a semionda
 *                     già iniziata. il pratica non solo il duty DTUPD ma anche il CPRDUPD              
 *                     possono variare durante emissione semionda...
 *                  
 *                  Previsto anche la possibilità di introdurre uno sfasamento a piacere.
 *                  Cioè sincronizzato con la rete ma sfasato di un tot.
 *                  Sfasamento solo in ritardo e massimo di 90 gradi.
 *                  La tensione emessa può essere sinusoidale oppure come quella di rete
 *                  (che a casa mia è sinusoidale ma un pò squadrata! )
 *                  
 *                  Mentre avviene il rilevamento semionde sulla rete viene riempita
 *                  una tabella normalizzata a 200 elementi con la tensione di rete.
 *                  Viene tentuto conto, tentando di correggere, isteresi trasformatore
 *                  di misura e dei 400microsecondi di anticipo...
 *                  anticipo che è solo allo zero cross e non al centro semionda !
 *                  
 *                  La Vrete in tabella MyTabVret ha la seguente scala:
 *                      1415 unità in tabella sono 325.26 Volt cc
 *                  quindi volendo posso dire che 380V di bus sono 1653
 *  
 *                  Il segnale in uscita non è sinusoidale ma segue la rete, come
 *                  se fosse un amplificatore in classe D però con sfasamento impostabile!
 *                  Il potenziometro regola l'ampiezza...
 *  
 *                  I mosfet della seconda gamba sono pilotati con 2 pin 52 e 48
 *                  con digitalWriteDirect.
 *  
 *                  Il sensore di corrente misura la corrente immessa in rete
 *                  (non quella PWM che circola tra induttore e condensatore...)
 *                  è attaccato alla seconda gamba quindi ha i problemi di deltaV/deltaT
 *                  solo durante l'unica commutazione allo zero cross e non durante il pwm
 *                  
 *                  COMPLICAZIONI: sulla prima gamba mosfet hi side voglio pwm centrato
 *                  e dead time hardware quando emette la semionda positiva. ok lo fa !
 *                  Similmente per fare la negativa mi serve pwm centrato e dead time sul mosfet
 *                  low side.  EBBENE non si riesce a farlo con un solo canale !
 *                  Lo si potrebbe fare rinunciando al dead-time ma irrinunciabile !
 *                  Quindi finisco con dover usare 2 canali alternandoli !
 *                  
 *                  pin 35 = PWMH0 di arduino va sul high-side gamba1 inverter
 *                  pin 34 = PWML0 di arduino va sul low-side gamba1 inverter                
 *                  
 *                  pin 37 = PWMH1 va sul low-side gamba1 inverter
 *                  pin 36 = PWML1 va su high-side gamba1 inverter
 *                  
 *                  in pratica i segnali di 35 e 36 vanno in or logico verso mosfet high-side.
 *                  e 34 e 37 vanno in or logico verso mosfet low-side
 *                  
 *                  Or logico lo realizzo con due resistenze da 500 ohm (prudenziali) ! e 
 *                  sfruttando il fatto che quando il canale è in fermo i relativi pin si 
 *                  trovano in alta inpedenza, MAI E POI MAI i 2 canali dovranno essere
 *                  attivi contemporaneamente!
 *  
 *
 *--- QUESTI I NUOVI PIN (non compatibile con versioni precedenti) ----------------------  
 *      pin 35 e pin 36 = PWMH0 PWML1 in or logico vanno sul high-side gamba1 inverter
 *      pin 34 e pin 37 = PWML0 PWMH1 in or logico vanno sul low-side gamba1 inverter 
 *
 *      pin 52 pilota +Vcc su seconda gamba del ponte.
 *      pin 48 pilota GND su seconda gamba del ponte.
 *      
 *  
 *     QUINDI: 
 *       Il filo blu (hi-side inverter gamba1) va al 35 e 36
 *       il filo viola (low-side inverter gamba1) va al 34 e 37
 *       
 *       il filo bianco (hi-side inverter gamba2) va al 52
 *       Il filo grigio (low-side inverter gamba2) va al 48
 *----------------------------------------------------------------------------------   
 *  
 *              Questo usa come hardware l'inverter cinese basato su EGS002->EG8010
 *              dove ho rimosso EG8010 e messo Arduino Due e altri cambi al circuito.
 *              ATTENZIONE la batteria va in tensione 220 quando funziona !!!!
 *              rimane un prototipo solo per test.                               
 *                                
 *  Sensore di corrente collegato 
 *   valori dal sensore di corrente (lettura differenziale pin A8-A9 e Gain=2)   
 *      corrente 0   =2055
 *      corrente +2A =2675  (cioè +310 ogni ampere...)
 *      corrente -2A =1437  (620 in meno del 2055)
 *      
 */



#include <DueAdcFast.h>

DueAdcFast DueAdcF(1024);   // 1024 microsecondi di storico.


int16_t MyTabVret[200];      // tabella con tensione di rete "reale" riempita durante la semionda reale
                             // ma tenendo conto di isteresi/400 micros di anticipo.
                             // viene costantemente aggiornata, vedi codice.
                             // la semionda viene divisa in 200 elementi di circa 50microsecondi ed
                             // il valore in ogni elemento è il "reale" valore di tensione in corrispondenza
                             // dell'inizio di ogni elemento.
                             // NB il valore è positivo anche per le semionde negative
                             //    se il valore è negativo significa che sta leggendo valori errati oppure
                             //    ad inizio semionda forse ci può anche stare !
                             // Attenzione ad usare questa tabella nel calcolo PWM perche essendo
                             // praticamente sincrona si rischia di usare misure della semionda precedente !
                             // da un raffronto si evince che errore è basso ed è fattibile anche usare
                             // misure della semionda precedente ! tanto piu che è una media !

int16_t MyTabVretP[200];     // quella sopra è una tabella di media questa è quella delle semionde positive
int16_t MyTabVretM[200];     // e questa è quella delle semionde negative.  Vedi codice.



uint8_t  NrSetTabVret = 0;  // indica quale elemento della MyTabVret è stato impostato.
                            // 0=nessun elemento impostato (siamo ad inizio semionda)
                            // 1=elemento letto/impostato
                            // arriva sino a 200 compreso e riparte ad ogni semionda.                             

uint32_t SemiPerTabVret = 0;  // è il RetSemiTimU/400 usato nella valorizzazione MyTabVret


                    
                        
// stato corrente dei pin di uscita
volatile boolean  is52on = false; 
volatile boolean  is48on = false;   // 52 e 48 mai assieme sarebbe corto su gamba2 e gestire dead-time...

volatile boolean  ispwmon = false;  


uint16_t VlPot = 0;     // valore letto dal potenziometro collegato al Pin A2
                        // valori che vanno da circa 29 a 4095 con rumore circa 5 unità  +-2.5!
                        // curioso il fatto che in basso non parte da zero ma 14 28 29
                        // con FindAvgForPin(A2,0,10) diminuisce molto il rumore valori da 29 a 4095 

boolean  VlPotgo = false;  // vedi codice attivazione lettura VlPot


float    Tbsinf[200];   // tabella con valori precalcolati funzione sinf() una semionda 180 gradi in 200 step.
                        

boolean  SemiCurRil = false;  // true se rilevato la fine si una semionda positiva, e quindi arriva la negativa... 
boolean  SemiCur = false;     // come SemiCurRil ma riferita alla semionda reale di rete ritardo di 400 micros.
boolean  SemiCurPrd = false;  // come SemiCur ma riferita alla semionda ritardata di TimRitPrd
uint8_t  nSemBts = 0;      // numero di inizi semionda per caricamento condensatori rami alti.


// Non uso la micros() ma la SysTick->VAL (servono 84 SysTick->VAL per fare un microsecondo)
// vedi codice x dettagli...

uint32_t TimSinius = 0;     // qui abbiamo il tempo in um SysTick per la semionda
                            // circa 840000 dipende dalla frequenza di rete...
boolean  TSiniusOk = false; // true quando il TimSinius è in corso...

uint32_t TimScaRet = 0;     // tempo x scadenzare misure tensione di rete, una misura ogni 25 microsec..
boolean  otmCalc=false;     // lavora con TimScaRet vedi codice.
              
uint16_t Imis;    // valore misura eseguita
int16_t  ImisSgn=0; // i misurata con segno. sia che stia facendo semionda positiva o
                    // semionda negativa, questa ImisSgn è positiva, è negativa solo nel
                    // caso in cui la corrente sia nella zona sbagliata
                    // esempio sta facendo semionda negativa e la I è positiva.
                    // Oppure sta facendo semionda positiva e la I è negativa.
                    // cioè negativa significa che la I sta scorrendo in direzione errata
                    // rispetto alla semionda che sti sta facendo...
                    

volatile boolean  bFail = false;     // se qualcosa non torna diventa true e si blocca tutto. Mosfet liberi...

uint8_t  nStat = 0;         // stato attivo vedi codice...

uint32_t CURTicks = 0;      // è il SysTick->VAL ad entrata del ciclo loop.
int32_t  OLDTicks = -1;     // tempo precedente è in SysTick->VAL con segno e valori (-1,0..84000)
uint32_t DeltaTicks = 0;    // è il delta tempo tra CURTicks e OLDTicks  NB la loop non deve durare
                            // pià di 1 millisecondo diversamente sballa il myTimeTicks.

uint32_t myTimeTicks = 0;   // mio tempo ufficiale in Ticks parte da zero e sale sino ad overflow e riparte
                            // in pratica ogni circa 51 secondi si azzera e riparte.


uint32_t deltatx;           // di uso genererico x differenze tempo.
uint16_t Vret = 0;          // valore misura tensione di rete eseguita
int16_t  VretSgn = 0;       // valore con segno sopra o sotto il bias, cioè semionda positiva o negativa...
int16_t  PrecVretSgn = 0;   // precedente VretSgn diverso da zero. (usato per determinare zero crossing)

int32_t  SumVret  = 0;      // somma delle tensioni misurate (x calcolare tensione media) NB segnata...
uint16_t NsumVret = 0;      // numero di misure sommate in SumVret
int32_t  VmedSem  = 0;      // valore medio tensione semionda (calcolato allo zero cross) SumVret/NsumVret
int32_t  VPicMax  = 0;      // i valori massimo e minimo toccati dalla tensione
int32_t  VPicMin  = 0;      // durante una semionda.

boolean  PrecRilsem=false;  // true dopo che è stato rilevato il primo zero crossing (poi rimane true)

int32_t  xtmp1;            // un generico int32 usato nei calcoli verifica tensioni e altri
int32_t  xtmp2;            // un generico int32 usato nei calcoli verifica tensioni e altro.


uint32_t MyTimeAtRil = 0;   // tempo myTimeTicks al rilevamento di inizio semionda
uint8_t  StatRet=0;         // stato rete  0=inizio
                            //             1=errore non arriva semionda successiva in tempo limite (<45hz)
                            //             2=errore semionda troppo vicina a precedente (>54hz)
                            //             3=frequenza rete fuori dai limiti.
                            //             4=errore nel segno delle semionde probabile tensione pulsante...
                            //             5=fuori range la vmedia o fuori range la vpicco per la sinusoide.
                            //             6=fuori forma la sinusoide
                            //           100 = troppo desincronizzato inverter rispetto alla rete troppa variazione di frequenza...
                                                       
boolean  RilIniz=false;     // Rilevato inizio di semionda di rete (che però ha 400microsec di anticipo
                            // rispetto alla rete.

boolean  InizReale=false;   // Questo è l'inizio reale di semionda di rete ottenuto dal RilIniz ritardandolo
                            // di 400 microsecondi.  

uint32_t Tim400Reale = 0;   // va da 0 a circa 400*84 è il tempo di ritardo per InizReale vedi codice...
boolean InizOne = false;    // vedi codice arriva RilIniz "aspetto 400 micros" attivo InizReale poi attendo
                            // che arrivi un altro InizReale non altri 400 micros...

// Nb per come è implementato il seguente TimRitPrd va bene solo per ritardare un pochino cioè
//    meno di mezza sinusoide 840000 ticks, direi che va bene per fare un ritardo da 0 a 90 gradi
//    o poco piu di certo non per creare un anticipo.
//    in seguito vedro come cambiare sta parte del ritardo prossimo ai 180 gradi e piu di 180...
uint32_t TimRitPrd = 0;   // tempo di ritardo tra un InizReale ed un InizPrd inizio di produzione
                          // in pratica è di quanto viene ritardata la tensione prodotta rispetto alla
                          // tensione reale della rete, lo sfasamento ma è in tempo non in gradi...
                          // 0=in fase...

uint32_t TimCntPrd = 0;      // è il contatore per ritardo di produzione va da 0 sino al TimRitPrd
boolean  InizPrdOne = false; // vedi codice arriva InizReale "aspetto TimRitPrd" attivo InizPrd poi attendo
                             // che arrivi un altro InizReale non altri TimRitPrd.

boolean  InizProd=false;    // Questo è l'inizio della semionda ritardata, sono gli inizi come da rete
                            // ma ritardati dell'entita voluta.



uint32_t ArrTimeAtRil[9];   // buffer circolare con gli ultimi 9 TimeAtRil
uint8_t  NrTimeAtRil = 0;   // parte da zero e sale a 9, si azzera solo in corrispondenza di errori
                            // deve arrivare a 9 prima di iniziare ad immettere corrente
                            // i 9 tempi qui contenuti vengono usati per determinare la frequenza
                            // di rete.
uint8_t  IdxTimeAtRil = 0;  // indice dell'ultimo elemento caricato.  (circolare scorre da 0 a 8) 
uint8_t  Idxvecchio = 0;    // indice del più vecchio elemento caricato  

uint32_t RetSemiTime = 0;   // Durata media delle ultime 8 semionde di rete, in pratica è la frequenza
                            // di rete.  a 50hz precisi vale 840000
                            // forzata a 0 in caso di StatRet != 0

uint32_t RetSemiTimU = 0;    // Durata media delle ultime 2 semionde di rete.
                             // è disponibile per NrTimeAtRil > 2
                             // la considero la misura più attendibile di durata dell'ultima semionda.
                             // NB è una media delle ultime due perche sui singoli valori
                             //    ho dei rilevamenti tipo 842936 837679 842463 838086


uint32_t RetSemiTimUrea = 0; // è il RetSemiTimU ma ad inizio della semionda reale di rete.
uint32_t RetSemiTimUPrd = 0; // è il RetSemiTimUrea ma ad inizio della semionda da produrre...


int32_t ArrVppAtRil[9];     // buffer circolare che segue la sorte e usa gli stessi indici di ArrTimeAtRil
                            // contiene pero' il valore di picco della semionda appena finita
                            // se contiene un valore negativo significa che dovrà iniziare la semionda
                            // positiva e viceversa.


uint32_t myTimePrd = 0;     // tempo ufficiale ad ogni InizProd
uint32_t myTimeFin = 0;     // tempo ufficiale ad ogni MypwmFin
boolean  OkTimePrd = false; // quando il myTimePrd è disponibile.
boolean  OkTimeFin = false; // quando il myTimeFin è disponibile.
// quando sono disponibili entrambi è il momento di fare il raffronto di tempo
// ad inizio quando parte emissione vengono messe a false.
// anche dopo un raffronto eseguito vengono messe a false...
int32_t myTimeInvRit = 0;   // è la differenza di tempo risultante dal raffronto.
                            // NB il campo è segnato...
                            // se valore positivo significa che inverter è in ritardo
                            // se negativo significa che inverter è troppo veloce cioè arriva
                            // prima del dovuto...


uint32_t mDebu[1026];       // x debug è un sistema rudimentale x debuggare il codice.
uint16_t nDebC = 0;         // counter.
boolean  mDebvis = false;
boolean  mDebSta = false;

boolean  mPin24 = false;     // ottimizza digitalread...  diventa TRUE se rilevato ok al debug...


uint16_t  Limpc = 0;  // conteggio giri loop, ottimizzazione...



/* -----------------------------------------------------------------------------
 *  ATTENZIONE Questa è specifica per Ardu2GridTied sembra quasi una libreria !
 *  
 *  fa PWM sui pin 35 e 34 canale 0 ed interrupt CHID0
 *  fa PWM sui pin 37 e 36 canale 1 ed interrupt CHID1
 *  RICORDO che questi 4 pin pilotano una sola gamba del ponte ad H
 *          questi 4 pin servono per pilotare 2 soli mosfet !
 *  
 *  Possibilita anziche chiamare la go di chiamare
 *  la MyPwM34High() che alza il pin ad 1 e vi
 *  rimane sino alla chiamata di MyPwmGmb1Stop
 *  (usata per caricare condensatore bootstrap 
 *   alla partenza)
 *  
 *  
 */

volatile uint32_t MyPwMTmx = 840000;  // è quanto deve durare la prossima semionda che si va ad emettere.
                                      // viene usata all'inizio per determinare PWM_CPRD
                                      // ed anche al cambio di semionda. (un pochino prima in effetti
                                      // a metà dell'inpulso 199 che va già a pianificare inpulso 0
                                      // prossima semionda)
                                      // ogni volta che la rete determina una nuova durata di semionda
                                      // le rende disponibile per inverter qui.
                                      // viene usata anche quando c'è una correzzione (MyPwMTcr) da fare.

volatile int32_t MyPwMTcr = 0;        // se diverso da zero è il myTimeInvRit con cui fare la correzzione
                                      // di periodo...  codice in interrupt fa la correzzione e
                                      // lo rimette a zero.
                                      
volatile uint16_t MyPwMPr = 2100;     // periodo degli inpulsi deciso ad inizio ed anche a metà
                                      // periodo per il successivo.
                                      // Attenzione che non è pulitissimo leggere questo è
                                      // meglio leggere registro PWM_CPRD
                                 
volatile uint16_t MyPwMcdt = 0;        // è il duty prima lo carica qui poi lo assegna al registro.

volatile boolean MyPwMpolm = false;    // quale semionda fare true=la negativa false=la positiva.
boolean          MyPwMpolm2 = false;   // è il MyPwMpolm ma non volatile.

// variabili sequenti usate internamente dalla "libreria" non usare...
volatile uint8_t  MyPwMonSt = 0;   // Stato interrupt pwm 0=ignorare 1=tratta

volatile uint8_t  MyPwMonid = 0;  // conteggio inpulsi operazioni sul CH0 e CH1

volatile uint32_t  dueadcPos1 = 0;  // è una posizione nel buffer ADC ottenuta da DueAdcFast::GetPosCurr
uint32_t           dueadcPos2 = 0;  // e' il dueadcPos1 ma non volatile.

volatile boolean  MypwmTrg = false;  // diventa true al trigger di metà inpulso
volatile uint8_t  MyPwmTid = 0;      // di quale metà inpulso si tratta 0..199
uint8_t           MyPwmTid2 = 0;     // è il MyPwmTid ma non volatile.

volatile boolean  MypwmFin = false;  // diventa true al trigger di fine inpulso dell' elemento 199
                                     // in pratica alla fine della semionda prodotta, ma già parte
                                     // la successiva non si ferma emissione.


/*
 * da chiamare una sola volta in setup.
 */
void MyPwMsetup(void)
{
  volatile uint32_t xvlreg;
  
  NVIC_DisableIRQ(PWM_IRQn);      // x Pulizia penso non serve 
  NVIC_ClearPendingIRQ(PWM_IRQn); // idem
  PWM->PWM_IDR1 = 0x00FF00FF;     // disabilita tutto ma non serve già disabilitato
  PWM->PWM_IDR2 = 0x00FFFF0F;     // idem 
  // qui dopo le due IDR i registri PWM_IMR1 e PWM_IMR2 sono a zero.

  // Pin 35 PWMH0
  PIO_Configure(g_APinDescription[35].pPort,PIO_PERIPH_B,g_APinDescription[35].ulPin,g_APinDescription[35].ulPinConfiguration);
  // Pin 34 PWML0
  PIO_Configure(g_APinDescription[34].pPort,PIO_PERIPH_B,g_APinDescription[34].ulPin,g_APinDescription[34].ulPinConfiguration);

  // Pin 37 PWMH1
  PIO_Configure(g_APinDescription[37].pPort,PIO_PERIPH_B,g_APinDescription[37].ulPin,g_APinDescription[37].ulPinConfiguration);
  // Pin 36 PWML0
  PIO_Configure(g_APinDescription[36].pPort,PIO_PERIPH_B,g_APinDescription[36].ulPin,g_APinDescription[36].ulPinConfiguration);

  
  // accende PWM clock
  pmc_enable_periph_clk(PWM_INTERFACE_ID);

  PWMC_ConfigureChannelExt(PWM,
                           0, // Channel: 0          
                           PWM_CMR_CPRE_MCK,  // 84000000
                           PWM_CMR_CALG, // Alignment: period is center aligned
                           0, // Polarity: output waveform starts at a low level
                           PWM_CMR_CES, // Counter event: occurs at the end and middle of the period
                           PWM_CMR_DTE, // Dead time generator is enabled
                           0, // Dead time PWMH output is not inverted
                           0);  // Dead time PWML output is not inverted

  PWMC_ConfigureChannelExt(PWM,
                           1, // Channel: 1          
                           PWM_CMR_CPRE_MCK,  // 84000000
                           PWM_CMR_CALG, // Alignment: period is center aligned
                           0, // Polarity: output waveform starts at a low level
                           PWM_CMR_CES, // Counter event: occurs at the end and middle of the period
                           PWM_CMR_DTE, // Dead time generator is enabled
                           0, // Dead time PWMH output is not inverted
                           0);  // Dead time PWML output is not inverted



  PWMC_SetPeriod(PWM, 0, 2100); // Canale 0 Period: 2100 = 50 microsecondi.
  PWMC_SetPeriod(PWM, 1, 2100); // Anche per canale 1
                           
  PWMC_SetDutyCycle(PWM, 0, 1050); // 50 % ma poi lo imposta prima di attivare...
  PWMC_SetDutyCycle(PWM, 1, 1050); // Anche per canale 1

  // optato per 51 che sono 0.6 micros di dead-time.
  PWMC_SetDeadTime(PWM, 0, 51, 51); // Channel: 0, Rising and falling edge dead time: 0.6 us
  PWMC_SetDeadTime(PWM, 1, 51, 51); // Anche per canale 1

  // Output Override Value Register = imposta a zero per CH0 e CH1 (è gia a zero ma ok)
  // Nb per tutti e 4 i bit
  PWM->PWM_OOV = PWM->PWM_OOV & 0xFFFCFFFC; 

  //PWM Output Selection Set Register = attiva ovverride immediato per CH0 e CH1
  // Nb per tutti e 4 i bit  
  PWM->PWM_OSS = 0x00030003;
 
  // qui i canali sono in disabilitato
  
  xvlreg = PWM->PWM_ISR1;     // serve pulire/leggendoli i flag nel registro ISR1
                              // se non li leggo/azzerandoli appena usero il registro PWM_IER1 per
                              // attivare interrupt parte interrupt e chiama la PWM_Handler
                              // per un evento che è del passato...

  xvlreg = PWM->PWM_ISR2;     // non servirebbe ma ok pulisco anche lui.   
    
  PWM->PWM_IER1 = 0x3;        // enable interrupt CHIDn on channel 0 e 1

  NVIC_EnableIRQ(PWM_IRQn);   // da ora in poi interrupt possono arrivare dal PWM...
                              // ma non arrivano per ora perche canali in disabilitato...
}


// attenzione che oltre alla gamba1 imposta anche la gamba2 come del resto
// poi succede in automatico al susseguirsi delle semionde
// non viene chiamata la stop ad ogni semionda ma tramite PWM_Handler
// continua ad emettere semionde...
void MyPwMgo(void)
{
  if ((PWM->PWM_SR & 0x3) == 0 && ispwmon == false)  // i canali devono essere in fermo
  {
    MyPwMPr = MyPwMTmx/400; // periodo degli inpulsi che si vanno ad emettere.
    MyPwMonid = 0;
    PWM->PWM_CH_NUM[0].PWM_CPRD = MyPwMPr;
    PWM->PWM_CH_NUM[0].PWM_DT = 0x00330033; // sono i due 51 che in esadecimale diventano 33 !
    PWM->PWM_CH_NUM[1].PWM_CPRD = MyPwMPr;
    PWM->PWM_CH_NUM[1].PWM_DT = 0x00330033; // idem per ch1
    MyPwMcdt = CalCDTYImp(MyPwMPr,0);
    PWM->PWM_CH_NUM[0].PWM_CDTY = MyPwMcdt;
    PWM->PWM_CH_NUM[1].PWM_CDTY = MyPwMcdt;
    MyPwMonSt = 1;       // abilita trattamento interrupt
    ispwmon = true;
    // imposta anche l'altra gamba opportunamente.
    if (MyPwMpolm)
    {
        setPin48Off();    // x sicurezza...
        setonGamb2();     // gamba2 sul vbus.
        PWM->PWM_ENA = 0x2;  // fa partire il canale 1
    }
    else
    {
        setPin52Off();    // x sicurezza...
        setGndGamb2();    // gamba2 sul GND.
        PWM->PWM_ENA = 0x1;  // fa partire il canale 0
    }
    // toglie eventuale output override presente. (per i 4 bit)
    PWM->PWM_OSC = 0x00030003;
   }
}


// nota che ferma pwm su gamba1 ma la gamba2 non la tocca, fermare anche gamba2 se serve.
void MyPwmGmb1Stop()
{
  // ferma pwm sulla gamba1
  if (ispwmon)  // potrebbe essere pericoloso ma rende tutto piu facile...
  {
     //PWM Output Selection Set Register = attiva ovverride immediato sui 4 bit.
     PWM->PWM_OSS = 0x00030003;
     // se canale è attivo
     if (PWM->PWM_SR & 0x1)
     {
       PWM->PWM_DIS = 0x1; // chiede il fermo x ch0
     }
     if (PWM->PWM_SR & 0x2)
     {
       PWM->PWM_DIS = 0x2; // chiede il fermo x ch1
     }
     MyPwMonSt = 0; // ignora eventuali interrupt successivi
     ispwmon = false;
  }     
}




/*
 * alza il pin ad 1 e vi rimane sino allo stop.
 * Attenzione che dopo lo stop serve un pò di tempo prima che il canale
 * effettivamente si fermi quindi non è possibile fare lo stop e subito la go...
 * tenerne conto nella parte di codice che carica condensatori bootstrap...
 */
void MyPwM34High(void)
{
  if ((PWM->PWM_SR & 0x3) == 0 && ispwmon == false)  // i due canali devono essere in fermo
  {
    // imposta il periodo ed il duty inpulsi  SOLO x CH0, CH1 resta in disabilitato.
    PWM->PWM_CH_NUM[0].PWM_CPRD = 2100;
    PWM->PWM_CH_NUM[0].PWM_CDTY = 2100;
    PWM->PWM_CH_NUM[0].PWM_DT = 0x00330033; // sono i due 51 che in esadecimale diventano 33 !
    MyPwMonSt = 0;       // interrupt non li tratta 
    MyPwMonid = 0;       // x sfizio/sicurezza
    ispwmon = true;
    PWM->PWM_ENA = 0x1;  // fa partire il canale
    // toglie eventuale output override presente. (per i 4 bit, si meglio x tutti e 4!)
    PWM->PWM_OSC = 0x00030003;
   }
}




// PWM_Handler
//
void PWM_Handler(void) // PWM interrupt handler
{
   uint32_t dummy = PWM->PWM_ISR1;   // clear interrupt flag1
   uint32_t dummy2 = PWM->PWM_ISR2;  // anche il flag2
   uint16_t prdmez;
   int32_t  ztmp1;
   int32_t  ztmp2;
   uint32_t zregCCNT;
   
   if (MyPwMonSt == 1) // se trattare interrupt...
   {
        if ((dummy & 0x3) == 3)
        {
           // non deve succedere significa entrambi i canali in enabled !!!
           //PWM Output Selection Set Register = attiva ovverride immediato sui 4 bit.
           PWM->PWM_OSS = 0x00030003;
           bFail = true;     // blocca tutto.
        }
        // evento CHID0
        if (dummy & 0x1  )
        {
          prdmez = PWM->PWM_CH_NUM[0].PWM_CPRD;
          zregCCNT = PWM->PWM_CH_NUM[0].PWM_CCNT;
        }
        else
        { // se non è CH0 dico che è CH1 contando sul fatto che mai sono abilitati insieme.
          prdmez = PWM->PWM_CH_NUM[1].PWM_CPRD;
          zregCCNT = PWM->PWM_CH_NUM[1].PWM_CCNT;
        }        
        
        // evento CHID0 o CHID1
        if (dummy & 0x3)
        {
          prdmez = prdmez >> 1; // divide x 2 indicativamente viene 1050
          if (zregCCNT > prdmez)   // come metodo per trattare solo gli interrupt a metà inpulso...
          {                        // considerando 2100 come top 1050 siamo tra il 25% e il 75%

             if(MyPwMonid == 200) MyPwMonid = 0;   // ok cambio avvenuto siamo nel nuovo inpulso 0

             // imposta flag per giro Trg 
             MypwmTrg = true;        // siamo al trigger di metà inpulso.
             MyPwmTid = MyPwMonid;   // di quale metà inpulso
             dueadcPos1 = DueAdcF.GetPosCurr();  // punto dove misurare la corrente...
             MyPwMonid++;  // aumenta per il successivo

             // va a determinare
             // il nuovo duty da applicare al prossimo inpulso...
             if (MyPwmTid == 199)
             {
                 // siamo a metà inpulso del 199 ma è già il momento di pianificare periodo
                 // e duty della prossima semionda che pwm dovrà emettere...
                 // ed anche di richiedere fermo del canale in corso...
                 MyPwMPr = MyPwMTmx/400;
                 MyPwMPr -= 42;  // recuperà cosi il microsecondo di dead-time al cambio della gamba2.
                 MyPwMcdt = CalCDTYImp(MyPwMPr,0);
                 if (dummy & 0x1  )
                 {
                    PWM->PWM_DIS = 0x1; // chiede il fermo x ch0
                    // e pianifica periodo e duty per prossima semionda prossimo canale !
                    PWM->PWM_CH_NUM[1].PWM_CPRD = MyPwMPr;
                    PWM->PWM_CH_NUM[1].PWM_CDTY = MyPwMcdt; 
                 }
                 else
                 {
                    // è il CH1
                    PWM->PWM_DIS = 0x2; // chiede il fermo x ch2
                    // e pianifica periodo e duty per prossima semionda prossimo canale !
                    PWM->PWM_CH_NUM[0].PWM_CPRD = MyPwMPr;
                    PWM->PWM_CH_NUM[0].PWM_CDTY = MyPwMcdt; 
                 }
                 MyPwMPr += 42;  // rimette i 42 per eventuale correzzione periodo successiva...
             }
             else
             {
               // vede se è il momento di fare la correzzione di periodo
               if (MyPwMTcr != 0)  // >0 deve allargare durata semionda...
               {
                  // calcolo in ztmp1 quanto tempo misurano gli inpulsi già emessi.
                  ztmp1 = MyPwmTid+1;
                  ztmp1 = ztmp1 * MyPwMPr * 2;  // *2 per convertire da pwm a systicks.
                  // calcolo quanto deve durare il tutto (già emesso e parte mancante)
                  ztmp2 = MyPwMTmx + MyPwMTcr;
                  MyPwMTcr = 0;                 // ok azzerato correzzione fatta qui sotto !
                  // un controllino che non si sta sbagliando tutto!
                  if (MyPwmTid > 100 || ztmp2 < 420000 || ztmp2 > 1260000) // già emesso 100 inpulsi o 5ms o 15ms
                  {
                     bFail = true;     // blocca tutto
                  }
                  // quindi calcolo quanto deve durare la parte mancante (che deve ancora fare)
                  ztmp2 = ztmp2 - ztmp1;
                  // calcola quanti inpulsi deve ancora fare...
                  ztmp1 = 199 - MyPwmTid; // sono 200 in tutto ma MyPwmTid conta da zero.
                  // calcola il CPRDUPD da usare
                  ztmp2 = ztmp2 >> 1;      // divide per 2 per passare da systicks a pwm
                  ztmp1 = ztmp2 / ztmp1;
                  // un controllino ancora
                  if (ztmp1 < 1050 || ztmp1 > 3150)
                  {
                     bFail = true;     // blocca tutto
                  }
                  MyPwMPr = ztmp1; // nuovo periodo da usare.
               }
               MyPwMcdt = CalCDTYImp(MyPwMPr,MyPwmTid+1);
               if (dummy & 0x1  )
               {               
                 PWM->PWM_CH_NUM[0].PWM_CPRDUPD = MyPwMPr;
                 PWM->PWM_CH_NUM[0].PWM_CDTYUPD = MyPwMcdt;
               }
               else
               {  
                 PWM->PWM_CH_NUM[1].PWM_CPRDUPD = MyPwMPr;
                 PWM->PWM_CH_NUM[1].PWM_CDTYUPD = MyPwMcdt;
               }              
             }
          }
          else
          {
             // evento interrupt di fine periodo 
             if(MyPwMonid == 200)
             {
               // qui direi che arriva con il canale che si è già disabilitato! lo verifico !
               if ((PWM->PWM_SR & 0x3) != 0)
               {  
                    //PWM Output Selection Set Register = attiva ovverride immediato sui 4 bit.
                    PWM->PWM_OSS = 0x00030003;
                    bFail = true;     // blocca tutto.               
               }     
               // cambia quindi la seconda gamba e avvia l'altro canale !
               MypwmFin = true;
               MyPwMpolm = !MyPwMpolm;
               if (MyPwMpolm)
               {
                  setPin48Off();
                  setonGamb2();     // gamba2 sul vbus.
                  // ha appena fatto 1 micros di dead-time sulla gamba2 venuto buono anche x gamba1...
                  PWM->PWM_ENA = 0x2;  // fa partire il CH1
               }
               else
               {
                  setPin52Off();
                  setGndGamb2();    // gamba2 sul GND.
                  // ha appena fatto 1 micros di dead-time sulla gamba2 venuto buono anche x gamba1...
                  PWM->PWM_ENA = 0x1;  // fa partire il CH0
               }
             }
          } 
        }
   }
}



/* 
 * -------------------------------------------------------------------------
 * -------------------------------------------------------------------------  
 * -------------------------------------------------------------------------
 *  
 */


// ATTENZIONE che viene chiamata da interrup fare in modo che duri poco sta routine...
// calcola il valore da caricare in registro CDTY per durata inpulso pwm
// xPCur = durata del periodo pwm, il 2100 per capirci
// xtid = quale inpulso calcolare da 0 a 199 per accedere a tabelle MyTabVret e Tbsinf
// Utilizza anche il VlPot come elemento moltiplicatore/regolatore...
inline uint16_t CalCDTYImp(uint16_t xPCur, uint8_t  xtid)
{
 uint16_t xtm;
 int32_t  xvtmp1;
 int32_t  xvtmp2;

 xvtmp1 = MyTabVret[xtid];  // tensione di rete va da 0 a 1658  (1658 è il massimo previsto per picco tensione di rete)
                            // ma la vbus a 380vcc è in pratica un 1653
                            // quindi 1653 è proprio il massimo!!!
                            // quando tester su rete indica 230vca la MyTabVret arriva a 1415

 if (xvtmp1 < 0) xvtmp1 = 0; // se negativa in tabella allora 0. 

 xvtmp1 = xvtmp1 * xPCur;
 xvtmp1 = xvtmp1 / 1658;  // in pratica qui ottiene già il valore pwm che produce la tensione di rete...


 // -- Se invece si vuole un onda sinusoidale commenta le righe sopra e scommenta queste 3 righe.
 // xvtmp1 = 1415 * xPCur;
 // xvtmp1 = Tbsinf[xtid] * xvtmp1;
 // xvtmp1 = xvtmp1 / 1658;

                            
 // passo da VlPot ad un valore da 500 a 1400 a fare un moltiplicatore da 0.5 a 1.4
 xvtmp2 = VlPot;
 xvtmp2 = xvtmp2 * 900;
 xvtmp2 = xvtmp2 / 4095;
 xvtmp2 += 500;                             

 // applico il moltiplicatore da 0.5 a 1.4 senza usare i float..
 xvtmp1 = xvtmp1 * xvtmp2;
 xvtmp1 = xvtmp1 / 1000;

 // il dead time lo ho impostato a 0.6 micros, 607 ns.
 // in pratica il dead-time accorcia la durata dell'inpulso.
 // gli IGBT usati da datascheet mediamente allungano la durata inpulso di 261 ns.
 //          gli IGBT usati ritardano un pochino in chiusura e ritardano molto in apertura
 //          in pratica succede che gli IGBT usati allungano impulso mediamente di 261ns.
 //          avendolo accorciato con dead-time di 607 ns 
 //          Vado qui ad applicare un correttivo di 346 ns.
 //          Con questo correttivo vado a migliorare il passaggio per lo zero del
 //          segnale prodotto.
 //
 // xvtmp1 += 15;   // 30 clock a 84mhz sono 357 ns. Quindi correttivo diventa 30/2=15 
 //
 // Da test eseguiti si vede che nonostante migliori il passaggio per lo zero nel segnale prodotto
 // (quando non immette), però poi in reale immissione in rete (tramite resistenza da 30 ohm) la
 // corrente immessa come forma peggiora nel passaggio per lo zero.
 //

 // controlli di sicurezza
 if (xvtmp1 < 0) xvtmp1 = 0;
 if (xvtmp1 > xPCur) xvtmp1 = xPCur;

 xtm = xvtmp1;
 xtm = xPCur - xtm;  // va invertito sopra ha ragionato che xvtmp1 piccolo significava piccolo inpulso...
                     // mentre il registro pwm fa al contrario. (valore piccolo = impulso largo)

 return xtm;

}



/*
 * velocizza i calcoli usando Tbsinf precalcolata rispetto alla sinf
 */
void FillTbsinf(void)
{
  int xi;
  float sinrad;
  float deltarad;
  deltarad = M_PI;          // UNA SEMIONDA INTERA
  deltarad = deltarad/200;  // 200 elementi in tabella.
  sinrad = deltarad/2;      // conviene fare cosi
  for(xi=0;xi < 200; xi++)
  { 
    Tbsinf[xi] = sinf(sinrad);
    sinrad += deltarad;
  }
}




void RiempieTabsIni(void)
{
  int xi;
  float xval;
  for(xi=0;xi < 200; xi++)
  { 
    MyTabVret[xi] = 0;  // pulizia iniziale.
    MyTabVretP[xi] = 0;
    MyTabVretM[xi] = 0;
  }
}



// funzione trovata in internet per fare IO piu veloce.
// 1 milione di queste le fa in 750 millisecondi.
// rispetto ai 4 secondi della digitalWrite standard.
// Ai fini di quello che vedo in oscilloscopio nel transitorio
// non cambia nulla.
// I transistor e mosfet del circuito hanno una loro velocità/Lentezza.
void digitalWriteDirect(int pin, boolean val){
 if(val) g_APinDescription[pin].pPort -> PIO_SODR = g_APinDescription[pin].ulPin;
 else    g_APinDescription[pin].pPort -> PIO_CODR = g_APinDescription[pin].ulPin;
}


// Questa è indispensabile per DueAdcFast !!!
void ADC_Handler() {
  DueAdcF.adcHandler();
}


void setup()
{
  pinMode(52, OUTPUT);       // pin 52 e 48 sono usati per mosfet gamba2
  pinMode(48, OUTPUT);
                            
  MyPwMsetup();              // mia "libreria" pwm arduino2 CH0 e CH1

  pinMode(24, INPUT);        // usato x debug  TENERE A MASSA se legge 1 si ferma PWM e va in serial
                             // a visualizzare  OCCHIO AD APRIRE E CHIUDERE IL MONITOR SERIALE CHE RESETTA...

  mDebSta = true;    // ok parte debug..

  FillTbsinf();      // dura 4945 micros.
                     // leggere i 200 elementi di Tbsinf richiede circa 27 microsecondi.

  RiempieTabsIni(); // dura 870 microsecondi

  DueAdcF.EnablePin(A0);     // Sensore di tensione di rete
  DueAdcF.EnablePin(A2);     // Sensore x potenziometro
  DueAdcF.EnableDif(A8);     // DIFF A8 - A9   sensore di corrente.
  DueAdcF.SetAllDifGain(2);  // Gain a 2 per le lettura differenziali. 
  DueAdcF.Start1Mhz();

  // x caricare i condensatori bootstrap sul ramo alto non è possibile
  // chiudere qui i mosfet con la rete che arriva sul ponte...
  // sarebbe un corto per fuori sync...
  // vedi codice dove usa variabile nSemBts

  //Serial.print("ADC speed is = ");
  //Serial.println(DueAdcF.MeasureSpeed());  // ritorna 3.38 microsecondi per fare le 3 letture... A0 A2 A8
  
  delay(4000);      // tempo di attesa prima di iniziare...
   
}


// cambio i nomi ovviamente
void setonGamb2(void)
{
  if (is52on == false && is48on == false)
  {
     delayMicroseconds(1);        // 1 di dead-time
     digitalWriteDirect(52, HIGH);
     is52on = true;
  }
}


void setGndGamb2(void)
{
  if (is48on == false && is52on == false)
  {
     delayMicroseconds(1);        // 1 di dead-time
     digitalWriteDirect(48, HIGH);
     is48on = true;
  }
}

void setPin48Off()
{
  if (is48on)
  {
     digitalWriteDirect(48, LOW);
     is48on = false;
  } 
}

void setPin52Off()
{
  if (is52on)
  {
     digitalWriteDirect(52, LOW);
     is52on = false;
  }
}


void FaiStopGamb2(void)  // libero è lo stato iniziale non sincronizzato con la rete non attivo nessuno dei 2 mosfet gamba2
{
 setPin48Off();
 setPin52Off();
}




void loop()
{
 // la loop usa tempo ad ogni ciclo, esce fa del lavoro sulle seriali e rientra...
 // cosi come trucco resto dentro la loop e ci esco solo dopo
 // un certo numero di cicli
 
 while (Limpc <=8000)  // METTO 8000 è un conteggio giri di loop
 {
   // -------------------  QUI DICIAMO LA MIA LOOP --------------------------------

   if (MypwmTrg)  // questo è quasi un codice interrupt questo MypwmTrg viene infatti
   {              // attivato dentro un interrupt ad indicare che è il momento
                  // di misurare la corrente...

                  // Nota però che da prove vedi commenti sotto qui ci può arrivare
                  //      anche con 30 o piu microsecondi di ritardo...
      noInterrupts();
      MypwmTrg = false;        // ok rilevato
      MyPwmTid2 = MyPwmTid;    // cosi compilatore può ottimizzare codice ecc...
      dueadcPos2 = dueadcPos1; // idem.
      MyPwMpolm2 = MyPwMpolm;  // idem.
      interrupts();

      // Con le attuali 3 misure fatte dall'ADC A0,A2,A8 la velocita è di 3.38 micros
      // per fare le 3 misure
      
      Imis = DueAdcF.FindAvgForPinPos(dueadcPos2,A8,0, 5);  // 5 sono 16.9 microsecondi...
      if (Imis > 4095)      // non succede mai..
      {
          bFail = true;     // blocca tutto
          return;  // prossimo giro di loop ferma tutto... non succede mai...
      }
      // controllo che la corrente sia entro i limiti  +5A e -5A 
      if (Imis > 3605 || Imis < 500 )     // oltre i +5A e -5A fermare tutto!
      {
           bFail = true;     // blocca tutto
           return;  // prossimo giro di loop ferma tutto...
      }  

      // ottiene ImisSgn  (ANCHE se per ora non la usa!)
      // valore negativo significa che sta scorrendo dalla parte sbagliata
      // rispetto alla semionda che si sta facendo...
      if (MyPwMpolm2)
          ImisSgn = 2055 - Imis;
      else
          ImisSgn = Imis - 2055;

   }

   
   // x debug
   if (mPin24)   // digitalRead(24) == HIGH
   {
     bFail = true;
     
     MyPwmGmb1Stop();
     FaiStopGamb2();

     // ed ora visualizza i valori catturati in debug mode...
     if (!mDebvis)
     {
       mDebvis = true;   // una sola volta
       //Serial.begin(115200);
       //while (!Serial);
       SerialUSB.begin(115200);
       while (!SerialUSB);
       //Serial.println("Valori catturati debug sono:");
       SerialUSB.println("Valori catturati debug sono:");
       for (int xi=0;xi < nDebC; xi++)
       {
         //Serial.println(mDebu[xi]);
         SerialUSB.println(mDebu[xi]);
       }
       //Serial.println("Fine valori catturati");
       //Serial.end();
       SerialUSB.println("Fine valori catturati");
       SerialUSB.end();
     }
   }
   
   if (bFail)
   {
     MyPwmGmb1Stop();
     FaiStopGamb2();
     if (digitalRead(24) == HIGH) mPin24 = true;  // per emettere debug con seriale collegata
   }
   else
   {
     // Qui si entra solo se non in errore/bloccato
     CURTicks  = SysTick->VAL;
     if (OLDTicks == -1) OLDTicks = CURTicks;   // la prima volta.
     DeltaTicks = ((OLDTicks < CURTicks) ? 84000 + OLDTicks : OLDTicks) - CURTicks;
     OLDTicks = CURTicks;       // da ora si che è old, per il prossimo giro...
     myTimeTicks += DeltaTicks; // aggiorna il tempo "ufficiale"!
     TimSinius += DeltaTicks;
     Tim400Reale += DeltaTicks;
     TimScaRet += DeltaTicks;
     TimCntPrd += DeltaTicks;

     if (TimScaRet >= 840) // ogni 10 microsec monitorizza la rete
     {
         // Da un debug della TimScaRet in questo punto si vede che a volte gira molto
         // velocemente ma in alcuni casi quando centra molte if/molto da fare...
         // arriva anche a ritardare di 30 o piu microsecondi...

         TimScaRet = 0;  // 24/01/2022 faccio cosi... tenere comunque presente che
                         //            a volte un giro di loop dura anche 30 microsecondi...
                  
         // 
         // 10/12/2021 utilizzo la FindValueForPin
         //
         Vret = DueAdcF.FindValueForPin(A0);
         if (Vret > 4095)      // non succede mai..
         {
            bFail = true;     // blocca tutto
            return;  // prossimo giro di loop ferma tutto... non succede mai...
         }
         if (VretSgn != 0) PrecVretSgn = VretSgn;    // il precedente VretSgn diverso da zero !
         VretSgn = Vret - 2035;       // 2035 è il Bias verificare se enable altri PIN...
         otmCalc = true;
     }

     // ok qui arrivano le misure della tensione di rete
     RilIniz = false;
     if (otmCalc)
     {
       otmCalc = false;
       if (PrecRilsem)
       {
            deltatx = myTimeTicks - MyTimeAtRil;  // tempo passato dall'ultimo rilevamento.
            if (deltatx > 11111 * 84)             // 11111 microsec sarebbe una semionda a 45hz...
            {                  
               StatRet = 1;   // 1=errore non arriva semionda successiva in tempo limite (<45hz)
            }            
       }
       // vediamo se siamo allo zero crossing
       if ((VretSgn == 0 && PrecVretSgn != 0) ||
           (VretSgn >  0 && PrecVretSgn <  0) ||
           (VretSgn <  0 && PrecVretSgn >  0)    )
         {
             // rilevato possibile cambio da una semionda all'altra...
             deltatx = myTimeTicks - MyTimeAtRil;  // tempo passato dall'ultimo rilevamento.
             if (PrecRilsem && deltatx < 1000*84)
             {
                  // almeno 1 millisecondo minimo tra un rilevamento e l'altro
             }
             else
             {
                 MyTimeAtRil = myTimeTicks;
                 RilIniz = true; // siamo ad inizio della semionda
                 // attiva PrecRilsem e calcola valore medio tensione semionda
                 PrecRilsem = true;
                 //-- 10/12/2021 qui cerca una pensata fatta cosi:
                 //--       if (VretSgn == 0) NsumVret++; // gli zeri fanno parte della semionda.
                 //--       ma poi ripensandoci ho deciso che più pulito non
                 //--       farlo, l'ultima misura fatta sulla semionda fosse anche lo zero
                 //--       va inputato alla semionda successiva.  Ai fini pratici cambia nulla !
                 //-- 
                 if (NsumVret > 0) VmedSem = SumVret / NsumVret; else VmedSem = 0;
                 SumVret = 0;
                 NsumVret = 0;
                 //
                 // solo x info il VmedSem da debug qui assume valori di +-880 (rete a 230v)
                 //
                 // carica ArrTimeAtRil storico dei tempi rilevati
                 if (NrTimeAtRil > 0)   IdxTimeAtRil++;     // dove caricare elemento
                 if (IdxTimeAtRil > 8) IdxTimeAtRil = 0;    // circolare ricomincia.
                 if (NrTimeAtRil < 9) NrTimeAtRil++;       // contatore quanti elementi caricati in array
                 ArrTimeAtRil[IdxTimeAtRil] = MyTimeAtRil;
                 // memorizza nell'array parallelo ArrVppAtRil il valore di picco
                 if (VmedSem > 0) ArrVppAtRil[IdxTimeAtRil] = VPicMax; else ArrVppAtRil[IdxTimeAtRil] = VPicMin;
                 //
                 // da un test fatto mentre il tester indicava 229 o 230Vca fai 230!
                 // il codice riportava qui un valore di picco di 1415
                 // quindi 230=> 325.26 <==> 1415
                 //
                 VPicMax = 0;
                 VPicMin = 0;
                 if (NrTimeAtRil > 1)
                 {
                    // imposta Idxvecchio sul precedente
                    if (IdxTimeAtRil > 0) Idxvecchio = IdxTimeAtRil - 1; else Idxvecchio = 8;
                    // controlla che non sia troppo vicina come tempo... (>54hz)
                    deltatx = MyTimeAtRil - ArrTimeAtRil[Idxvecchio];
                    if (deltatx < 9259 * 84)
                    {
                      // 9259 microsec sarebbe una semionda a 54hz..
                      StatRet = 2;   // 2=errore semionda troppo vicina a precedente (>54hz)
                    }
                    
                    //  qui fa anche un controllo sulla tensione semionda media e di picco
                    xtmp1=VmedSem;
                    if (xtmp1 < 0) xtmp1 = -xtmp1;
                    xtmp2=ArrVppAtRil[IdxTimeAtRil];
                    if (xtmp2 < 0) xtmp2 = -xtmp2;
                    if (xtmp1 < 704 || xtmp1 > 1056 || xtmp2 < 1105 || xtmp2 > 1658)
                    {
                         StatRet = 5; // fuori range la vmedia o fuori range la vpicco.
                    }
                    else
                    {  
                      // qui va anche a sindacare sulla forma d'onda
                      // rapporto tra vpp/vmedio=1.57 nei sinusoidi perfetti..
                      xtmp1 = (xtmp2 * 100) / xtmp1;
                      if (xtmp1 < 136 || xtmp1 > 182) StatRet = 6; // fuori forma la sinusoide 
                    }
                 }
                 // verifica alternanza delle semionde che non si tratti di pulsante
                 if (NrTimeAtRil > 2)  // il valore caricato sulla prima ArrVppAtRil non è affidabile 
                 {                     // qui entra dal terzo rilevamento in poi e fa il controllo.
                    // imposta Idxvecchio sul precedente
                    if (IdxTimeAtRil > 0) Idxvecchio = IdxTimeAtRil - 1; else Idxvecchio = 8;
                    if ((ArrVppAtRil[IdxTimeAtRil] > 0 && ArrVppAtRil[Idxvecchio] > 0) ||
                        (ArrVppAtRil[IdxTimeAtRil] < 0 && ArrVppAtRil[Idxvecchio] < 0)    )
                    {
                        StatRet = 4;   // 4 = errore nel segno delle semionde probabile tensione pulsante...
                    }
                 }

                 // calcola RetSemiTimU
                 if (NrTimeAtRil > 2)
                 {  
                     // per aggiornare la MyTabVret serve RetSemiTimU
                     // e RetSemiTimU serve anche per altro...
                     // imposta Idxvecchio sul precedente
                     if (IdxTimeAtRil > 0) Idxvecchio = IdxTimeAtRil - 1; else Idxvecchio = 8;
                     // Idxvecchio indietro ancora di uno
                     if (Idxvecchio > 0 ) Idxvecchio = Idxvecchio-1; else Idxvecchio = 8;
                     deltatx = MyTimeAtRil - ArrTimeAtRil[Idxvecchio];
                     RetSemiTimU = deltatx >> 1; // un modo veloce di dividere x 2 !

                     // esempio di valori rilevati di RetSemiTimU
                     // 839525  
                     // 839661  +136
                     // 839583  - 78
                     // 839850  +267
                     // 839574  -276
                     // 839220  -354
                     // 839531  +311
                     // 839999  +468  468 sono 5.57 micros...
                     // 839624  -375
                     
                 }
              
                 // ad array pieno calcola la frequenza
                 if (NrTimeAtRil == 9)
                 {
                     Idxvecchio = IdxTimeAtRil + 1;  // il piu vecchio è il successivo ! buffer circolare...
                     if (Idxvecchio > 8) Idxvecchio = 0;
                     // delta tempo
                     deltatx = MyTimeAtRil - ArrTimeAtRil[Idxvecchio];
                     RetSemiTime = deltatx >> 3; // un modo veloce di dividere x 8 !
                     // verifica che sia nei limiti di 47.5 e 51.5 compresi.
                     if (RetSemiTime > 884210 || RetSemiTime < 815533) StatRet = 3;

                 }
             }
       }
       // aggiorna la SumVret e i valori di picco...
       SumVret += VretSgn;
       NsumVret++;
       if (VPicMax < VretSgn) VPicMax = VretSgn;
       if (VPicMin > VretSgn) VPicMin = VretSgn;

     }


     // gestione del ritardo di 400micros e impostazione del InizReale
     InizReale = false; 
     if (RilIniz)
     {
      Tim400Reale = 0;
      InizOne = true;   // solo una volta dopo il RilIniz
      // se quella appena finita era positiva allora arriva la negativa o viceversa
      if (VmedSem > 0) SemiCurRil = true; else SemiCurRil = false;
     }
     if (InizOne && Tim400Reale >= 33600) // 400*84=33600
     {
       InizReale = true;  // ok rilevato inizio reale.
       InizOne = false;
       TimSinius = 0;         // in pratica è qui che lo sincronizza, TimSinius segue la reale non
                              // quella rilevata che è in anticipo di 400 micros...
       NrSetTabVret = 0;      // idem
       SemiCur = SemiCurRil;  // la reale parte 400 micros dopo ma non è cambiata nel frattempo...
       SemiPerTabVret = RetSemiTimU/400;  // RetSemiTimU viene alterato 400 micros prima che finisca la semionda reale...
       RetSemiTimUrea = RetSemiTimU;      // è il RetSemiTimU ma ad inizio della semionda reale di rete.
       VlPotgo = true;
       if (NrTimeAtRil > 2) TSiniusOk = true; 
     }


     // aggiorna elemento della tabella tensione di rete MyTabVret facendo la correzzione isteresi...
     if (TSiniusOk && NrSetTabVret < 200)
       if (TimSinius > SemiPerTabVret * 2 * (uint32_t) NrSetTabVret )
        {
           // il valore da leggere si trova però indietro di 400 micros !
           // per il primo elemento, mentre al centro elemento 100 è
           // il corrente in pratica la correzzione isteresi trasformatore
           // di misura tensione la fa cosi:
           // Ricordo che ADC A0,A2,A8 la velocita è di 3.38 micros
           // per fare le 3 misure
           // quindi 400/(3.38/3) mi dice quanti elementi andare indietro
           // nel buffer ADC...
           // girando formula si puo scrivere 400*3/3.38 ed anche
           // 400 * 300 / 338
           // ed 1-Tbsinf[NrSetTabVret] mi fa la correzzione per arrivare
           // a zero al centrale...
           
           xtmp2 =  (1.0 - Tbsinf[NrSetTabVret]) * 120000;   // 120000 = 400*300
           xtmp2 = xtmp2 / 338;
           if (xtmp2 < 0) xtmp2 = 0; // sicurezza!
       
           // va a prendere dal buffer ADC il valore "reale" indietro 
           // nel tempo di 400 micros, o meno, della tensione.
           xtmp1 = DueAdcF.FindAvgForPin(A0, xtmp2, 1);
           if (xtmp1 > 4095)   // non succede mai..
           {
            bFail = true;     // blocca tutto
            return;  // prossimo giro di loop ferma tutto... non succede mai...
           }

           // applica il bias e riporta le negative a positive e le carica
           // nelle due tabelle P ed M
           if (SemiCur)
           {
                xtmp1 =  2035 - xtmp1;
                MyTabVretM[NrSetTabVret] = xtmp1;
                // aggiorna la media
                xtmp1 += MyTabVretP[NrSetTabVret];
                xtmp1 = xtmp1 / 2;
                noInterrupts();
                MyTabVret[NrSetTabVret] = xtmp1;
                interrupts();
           }  
           else
           {
                xtmp1 = xtmp1 - 2035;
                MyTabVretP[NrSetTabVret] = xtmp1;
                // aggiorna la media
                xtmp1 += MyTabVretM[NrSetTabVret];
                xtmp1 = xtmp1 / 2;
                noInterrupts();
                MyTabVret[NrSetTabVret] = xtmp1;
                interrupts();
           }

           NrSetTabVret++;  // passa al successivo.
       }


     // gestione del ritardo di TimRitPrd e impostazione del InizProd
     InizProd = false; 
     if (InizReale)
     {
      TimCntPrd = 0;
      InizPrdOne  = true;   // solo una volta dopo InizReale

      // provo a mettere un ritardo di sfasamento di 45 gradi
      // TimRitPrd = RetSemiTime / 4;
      
      // è cosi di 90 gradi non andare oltre...
      // TimRitPrd = RetSemiTime / 2;
      
     }
     if (InizPrdOne && TimCntPrd  >= TimRitPrd)
     {
       InizProd = true;  // ok rilevato inizio x semionda ritardata
       InizPrdOne = false;
       SemiCurPrd = SemiCur;            // ok dai non è cambiata nel frattempo...
       RetSemiTimUPrd = RetSemiTimUrea; // idem

       noInterrupts();
       MyPwMTmx = RetSemiTimUPrd;       // tiene aggiornato anche quello x pwm inverter...
       interrupts();
 
       myTimePrd = myTimeTicks;
       OkTimePrd = true;      // viene messo a false sotto ad inizio emissione semionde...
                              // ed anche per errori ecc..
     }

     // se evento inverter di fine semionda
     if (MypwmFin)
     {
      MypwmFin = false; // ok rilevato.
      myTimeFin = myTimeTicks;
      OkTimeFin = true;
     }

     // se è il momento di fare raffronto tempi lo fa...
     if (OkTimePrd && OkTimeFin && ispwmon)
     {
        myTimeInvRit = myTimePrd - myTimeFin;
        OkTimeFin = false;
        OkTimePrd = false; 
        // fa un controllo di quanto sfasamento è stato rilevato
        // da alcune prove vedo che arrivano valori di myTimeInvRit
        // grossomodo inferiori a +-4000  e 4000 sono circa 47 microsecondi !!! 
        // ma il controllo lo faccio molto prudenziale !
        // tollero una variazione in una sola semionda da 47.5hz a 51.5hz
        // cioè 884210 - 815533 = 68677 (sono 0.817 ms)
        
        if (myTimeInvRit < -68677 || myTimeInvRit > 68677)
        {
           StatRet = 100; // si lo tratto come errore di rete anche se potrebbe essere considerato di inverter...
        }
        else 
        {
           // imposta MyPwMTcr che in codice interrupt farà la correzzione..
           noInterrupts();
           MyPwMTcr = myTimeInvRit;
           interrupts();
           
        }
       
     }
     
     // se errori StatRet butta lo storico tempi, lo fa ripartire e servira
     // quindi riempire di nuovo prima che possa ripartire l'immissione. 
     if (StatRet != 0)
     {
        // ferma i mosfet gambe inverter
        FaiStopGamb2();
        MyPwmGmb1Stop();
      
        NrTimeAtRil = 0;
        IdxTimeAtRil = 0;
        TSiniusOk = false;
        RetSemiTime = 0;
        StatRet = 0;     // lo rimette a zero come ad inizio comunque immissione
                         // non può partire perche NrTimeAtRil non è a 9
        OkTimeFin = false;
        OkTimePrd = false;
        MyPwMTcr = 0;

        nStat = 0;      // cosi riparte ad aspettare NrTimeAtRil a 9.

     }      

     // conteggio giri di loop
     Limpc++;

     // la variabile nStat la uso cosi
     //  0 stato iniziale o dopo un errore e arriva qui con mosfet già tutti aperti vedi appena sopra.
     //  1 = NrTimeAtRil arrivato a 9 e tocca a semionda negativa e quindi iniziare a caricare condensatori bootstrap..
     //  2 = condensatori caricati e si avvia emissione
     //  3 = emissione è attiva (rimane in questo stato, eventualmente riparte dallo zero)

     if (InizProd) // quando è inizio semionda da emettere/produzione vede se momento di fare qualcosa..
     {
        // dallo stato 0 attende che NrTimeAtRil arrivi a 9 e attende anche che sia un
        // InizProd di semionda negativa
        if (nStat == 0 && NrTimeAtRil >= 9 && SemiCurPrd)
        {
           nStat=1;       // 1 = si può iniziare a caricare condensatori bootstrap...
           nSemBts = 0;   // per caricamento condensatori rami alti.
        }
        if (nStat==1)
        {
           nSemBts++;     // fa 2 semionde la negativa e la positiva successiva caricando condensatori bootstrap...
           if (nSemBts >= 3) nStat=2; // alla terza passa in stato 2 cioè inizia emissione...
        } 

        if (nStat==1)
        {
           // i mosfet sotto seguono la rete
           // in modo da caricare i condensatori di boot che servono
           // per pilotare i mosfet sopra...
           if (SemiCurPrd)
           {
             FaiStopGamb2();
             MyPwM34High();     // Gamba1 a Gnd.
           }
           else
           {
             MyPwmGmb1Stop();  // gamba1 ferma
             setPin52Off();    // x sicurezza...
             setGndGamb2();    // gamba2 sul GND.
           }
        }

        if (nStat==2)
        {
            MyPwMpolm = SemiCurPrd;
            MyPwMTmx = RetSemiTimUPrd;
            OkTimeFin = false;
            OkTimePrd = false; 
            MyPwMgo();  // fa partire il pwm e imposta anche la gamba2
            nStat = 3;  // rimane in stato 3 diciamo..

        }
      
     }
     
     
     // dopo 2 ms dall inizio semionda reale legge una volta VlPot e pin 24
     if (VlPotgo && TimSinius > 168000)
     {
        VlPotgo = false; 
        VlPot = DueAdcF.FindAvgForPin(A2,0,10);

        // controlla anche il pin di stop/debug.
        if (digitalRead(24) == HIGH) mPin24 = true;
        
     }

   
   }

   // -------------------  FINE DELLA DICIAMO LA MIA LOOP -------------------------
 }  
 Limpc = 0;
}
