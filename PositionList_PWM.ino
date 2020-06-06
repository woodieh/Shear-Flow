#include <avr/pgmspace.h> 
// Interrupt Service Routine (ISR) 
int j=0, i=0; 
const int position[32] PROGMEM= {11968,11968,12332,12336,13688,13688,17596,17596,57048,57048,17596,17596,13688,13688,12332,12336,11964,11968,12332,12336,13688,13688,17596,17596,57048,57048,17596,17596,13688,13688,12332,12336};
const byte direction[2][4] PROGMEM = {{B10101010,B00000000,B00000000,B10101010},
{B00000000,B10101010,B10101010,B00000000}
}; 
ISR(TIMER1_COMPA_vect) 
 { 
OCR1A = pgm_read_word(&(position[j]));
OCR1B = pgm_read_word(&(position[j]));
TCCR1A = (1 << COM1A1) | (1 << COM1B1) | (bitRead(pgm_read_byte(&direction[0][i]),7-j%8) << COM1A0) | (bitRead(pgm_read_byte(&direction[1][i]),7-j%8) << COM1B0); //clear/set OC1A,B on compare match
j++;
if (j == 32) {
   j = 0; 
} 
i = floor(j/8);
} 

void setup(void)
{
pinMode(11, OUTPUT); //timer 1 OC1A
pinMode(12,OUTPUT); //timer 1 OC1B

cli();         // disable global interrupts
TCCR1A = 0; // set registers = 0
TCCR1B = 0;
CLKPR = (0 << CLKPCE) | (0 << CLKPS3) | (0 << CLKPS2) | (1 << CLKPS1) | (0 << CLKPS0);

TIMSK1 = (1 << OCIE3A); //Enable timer compare interrupt

sei();       // enable interrupts

OCR1A = 60000; 
OCR1B = 60000;

TCCR1B = (1 << WGM12)| (1 << CS12);  //CTC mode, prescaler clock/256

}void loop(void)
{
 }
