clear
%%%% INPUT %%%%
DT = 0.1;%[s], time interval for each velocity
OCR3Aprescaler = 1024;
D = 1; % Pulse Settings On Controller
CS = 0;% Pulse Settings On Controller
Prescaler = 1; %This sets time resolution for fast timers

CLKPS = 4; %DONT FORGET

ClockFreq = (16*10^6)/CLKPS; 
mmPerRevolution = 6;
PulsesPerRevolution = 1000/(D+1)*10^CS;
mmPerPulse = mmPerRevolution/PulsesPerRevolution;

%Calculate OCR3A
OCR3A = floor((ClockFreq*DT/(OCR3Aprescaler)) - 1);
if OCR3A > 2^16
     error('DT is too big. Increase OCR3Aprescaler')
end
w = .1; %sine frequency in Hertz
time = [0:DT:120];
%speed = zeros(1,length(time));

% for i = 1:length(time)
%    
%   if mod(i,4) == 0;
%       speed(i) = 10;
%       dir1(i) = 0;
%       dir2(i) = 1;
%   else
%       speed(i) = 0;
%       dir1(i) = 0;
%       dir2(i) = 1;
%   end
% end
  
speed = [10*cos((time)*2*pi*w)];%[mm/s]
plot(speed);
position = zeros(1,length(speed));


for i = 1:length(speed)-1
   
  position(i+1)= position(i)+speed(i)*DT;
  
end

figure(1)
subplot(2,1,1)
title('Position and Speed vs. Time')
plot(time,speed)
ylabel('Speed [mm/s]')
subplot(2,1,2)
plot(time,position)
ylabel('Position [mm]')
xlabel('Time [s]')


for i=1:length(speed)
    
    mmPerDT = abs(speed(i))*DT;
    PulsesPerDT = mmPerDT/mmPerPulse;
    PulsesPerSec = PulsesPerDT/DT;
    OscFreq = PulsesPerSec;
    OCRnA(i) = floor(ClockFreq/Prescaler/OscFreq - 1);
    OscPeriod = 1/OscFreq;
    
    if OCRnA(i) > 2^16-1
        speederror(i) = speed(i);
        OCRnA(i) = 2^16-1;
    end
    
    if OscPeriod < .000002
        error('Osc. Period is too small: Increase prescaler, Decrease Cs, or Increase D')
    end
    
end


%sprintf('A velocity of %d mm/s was rounded to 0. If this is too much error consider decresasing prescaler, Increase Cs, or decrease D ',max(abs(speederror)));


for i=1:length(speed)
  if speed(i)>0
      dir1(i) = 1;
  else
      dir1(i) = 0;
 end 
end



for i=1:length(speed)
  if OCRnA(i) > 2^16-1
      dir2(i) = 0;
  elseif speed(i)>0
      dir2(i) = 0;
  else
      dir2(i) = 1;
  end 
end

fid = fopen(['speedlist.ino'], 'wt');
fprintf(fid, '// Interrupt Service Routine (ISR) \n');
fprintf(fid, 'volatile int i=0, j=0; \n');
fprintf(fid, 'volatile int speed[3][%d] = {\n{', length(speed));
for i=1:length(speed)-1
    fprintf(fid, '%d,', OCRnA(i));
end
fprintf(fid,'%d},\n{', OCRnA(length(speed)));
for i=1:length(speed)-1
    fprintf(fid, '%d,', dir1(i));
end
fprintf(fid,'%d},\n{', dir1(length(speed)));
for i=1:length(speed)-1
    fprintf(fid, '%d,', dir2(i));
end
fprintf(fid,'%d}};\n', dir2(length(speed)));
fprintf(fid,'ISR(TIMER3_COMPA_vect)\n{\n');
fprintf(fid, 'OCR1A = speed[0][j];\nOCR4A = speed[0][j];\n');
fprintf(fid, 'TCCR4A = (speed[2][j] << COM4A0); //toggle OC4A on compare match\n');
fprintf(fid, 'TCCR1A = (speed[1][j] << COM1A0); //toggle OC1A on compare match\n');
fprintf(fid, 'i++;\nj = i %% %d;\n\n}',length(speed));
fprintf(fid, '\n\nvoid setup(void)\n{\n');
fprintf(fid, 'pinMode(11, OUTPUT); //timer 1 OC1A\n');
fprintf(fid, 'pinMode(6,OUTPUT); //timer 4 OC4A\n\n');
fprintf(fid, 'cli();         // disable global interrupts\n\n');
fprintf(fid, 'TCCR1A = 0; // set registers = 0\n');
fprintf(fid, 'TCCR1B = 0;\nTCCR3A = 0;\nTCCR3B = 0;\nTCCR4A = 0;\nTCCR4B = 0;\n\n');
fprintf(fid, 'CLKPR = (1 << CLKPCE) | (0 << CLKPS3) | (0 << CLKPS2) | (0 << CLKPS1) | (0 << CLKPS0);\n\n');
if CLKPS == 1
    fprintf(fid, 'CLKPR = (0 << CLKPCE) | (0 << CLKPS3) | (0 << CLKPS2) | (0 << CLKPS1) | (0 << CLKPS0);\n\n');
elseif CLKPS == 2
    fprintf(fid, 'CLKPR = (0 << CLKPCE) | (0 << CLKPS3) | (0 << CLKPS2) | (0 << CLKPS1) | (1 << CLKPS0);\n\n');
elseif CLKPS == 4
    fprintf(fid, 'CLKPR = (0 << CLKPCE) | (0 << CLKPS3) | (0 << CLKPS2) | (1 << CLKPS1) | (0 << CLKPS0);\n\n');
elseif CLKPS == 8
    fprintf(fid, 'CLKPR = (0 << CLKPCE) | (0 << CLKPS3) | (0 << CLKPS2) | (1 << CLKPS1) | (1 << CLKPS0);\n\n');
elseif CLKPS == 16
    fprintf(fid, 'CLKPR = (0 << CLKPCE) | (0 << CLKPS3) | (1 << CLKPS2) | (0 << CLKPS1) | (0 << CLKPS0);\n\n');
elseif CLKPS == 32
    fprintf(fid, 'CLKPR = (0 << CLKPCE) | (0 << CLKPS3) | (1 << CLKPS2) | (0 << CLKPS1) | (1 << CLKPS0);\n\n');
elseif CLKPS == 64
    fprintf(fid, 'CLKPR = (0 << CLKPCE) | (0 << CLKPS3) | (1 << CLKPS2) | (1 << CLKPS1) | (0 << CLKPS0);\n\n');
elseif CLKPS == 128 
    fprintf(fid, 'CLKPR = (0 << CLKPCE) | (0 << CLKPS3) | (1 << CLKPS2) | (1 << CLKPS1) | (1 << CLKPS0);\n\n');
elseif CLKPS == 256
    fprintf(fid, 'CLKPR = (0 << CLKPCE) | (1 << CLKPS3) | (0 << CLKPS2) | (0 << CLKPS1) | (0 << CLKPS0);\n\n');
else
    error('Select a different CLKPS');
end

fprintf(fid, 'TIMSK3 |= (1 << OCIE3A); //Enable timer compare interrupt\n\n');
fprintf(fid, 'sei();       // enable interrupts\n\n');
fprintf(fid, 'OCR1A = 10000; \nOCR1B = 5000;\n\n');
fprintf(fid, 'OCR3A = %d;\n\n',OCR3A);
fprintf(fid, 'TCCR1B = (1 << WGM12) | (1 << CS10); //CTC mode, prescaler clock/1\n\n');
fprintf(fid, 'TCCR4B = (1 << WGM42) | (1 << CS40);  //CTC mode, prescaler clock/1\n\n');
fprintf(fid, 'TCCR3B = (1 << WGM32) ');
if OCR3Aprescaler == 1
    fprintf(fid, '| (1 << CS30);  //CTC mode, prescaler clock/1\n\n}');
elseif OCR3Aprescaler == 8
    fprintf(fid, '| (1 << CS31);  //CTC mode, prescaler clock/8\n\n}');
elseif OCR3Aprescaler == 64
    fprintf(fid, '| (1 << CS31) | (1 << CS30);  //CTC mode, prescaler clock/16\n\n}');
elseif OCR3Aprescaler == 256
    fprintf(fid, '| (1 << CS32);  //CTC mode, prescaler clock/256\n\n}');
elseif OCR3Aprescaler == 1024
    fprintf(fid, '| (1 << CS32) | (1 << CS30);  //CTC mode, prescaler clock/1024\n\n}');
end
fprintf(fid, 'void loop(void)');
fprintf(fid, '\n{\n }');

fclose(fid);
