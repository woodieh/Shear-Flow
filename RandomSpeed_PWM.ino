// Interrupt Service Routine (ISR)
volatile int i=0, j=0;
volatile int speed[3][20] = { {13713, 10665, 11999, 10665, 31998, 11999, 19199, 65535, 9599, 9599, 13713, 9599, 
9599, 65535, 15998, 11999, 47999, 10665, 15998, 9599}, {1, 1, 0, 1, 1, 0, 0, 1, 1, 1, 0, 1, 1, 0, 1, 0, 0, 1, 1, 1, }, 
{0, 0, 1, 0, 0, 1, 1, 0, 0, 0, 1, 0, 0, 1, 0, 1, 1, 0, 0, 0, } };

ISR(TIMER3_COMPA_vect)
{
  OCR1A = speed[0][j];
  OCR4A = speed[0][j];

  TCCR4A = (speed[2][j] << COM4A0);               //toggle OC4A on compare match
  TCCR1A = (speed[1][j] << COM1A0);               //toggle OC1A on compare match
  i++;
  j = i % 20;
} 

void setup(void)
{
    pinMode(11, OUTPUT); //timer 1 OC1A
    pinMode(6, OUTPUT); //timer 4 OC4A
 
    cli();          // disable global interrupts
    
    TCCR1A = 0;     // set registers = 0;
    //TCCR1B = 0;
    TCCR3A = 0;
    TCCR3B = 0;
    TCCR4A = 0;
    TCCR4B = 0;

    TIMSK3 = (1 << OCIE3A); //Enable timer compare interrupt
    
    sei();          // enable interrupts
    
    OCR1A = 10000;
    OCR4A = 10000;
    
    OCR3A = 5000;
    
    
    
    
    TCCR1B = (1 << WGM12) | (1 << CS10);   //CTC mode, prescaler clock/1

   
    TCCR4B = (1 << WGM42) | (1 << CS40);   //CTC mode, prescaler clock/1
    
    TCCR3B = (1 << WGM32) | (1 << CS32) | (1 << CS30); //CTC mode, prescaler clock/1024
}

void loop(void)
{
}
