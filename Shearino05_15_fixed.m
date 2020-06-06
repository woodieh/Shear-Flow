close all
clear
%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%% INPUT %%%%%%%%%%

% Sine wave parameters
w = .1 ;   % Frequency (Hz)  NOT JUSTIFIED
A = .1 ;  % Amplitude (mm)
position = @(t) (A*sin(2*pi*w*t)); 

% Step size settings (on controller)
D = 1; 
CS = 0;
PulsesPerRevolution = 1000/(D+1)*10^CS;
mmPerRevolution = 6;
h = mmPerRevolution/PulsesPerRevolution*2; %%%% 2 unjustified

% Clock prescalers
OCR1Aprescaler = 256;
CLKPS = 4; %DONT FORGET
ClockFreq = (16*10^6)/CLKPS/OCR1Aprescaler; 

%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%


% Define time list for sine wave
tfinal = 1/w;
dt = 1/ClockFreq;
Time = 0:dt:tfinal;
steps = size(Time,2);
PosDiscrete(1) = round(position(Time(1))/h)*h;
TimeList(1) = 1;
i=1; 
dif(1)=0;
for k = 2:steps
    PosDiscrete(k) = round(position(Time(k))/h)*h;
    dif(k) = PosDiscrete(k)-PosDiscrete(k-1);
    if abs(dif(k))>1.5*h%wasnt working for h due to machine error?
        error('Moves multiple steps in minimum time discretization. Make dt smaller')
        %This is where we can put a limiter
    end
    stepsign = sign(dif(k));
    if stepsign==0
        TimeList(i) = TimeList(i)+1;
        if TimeList(i) > 2^16-1
            error('This spends too long without moving. Increase prescaler or decrease h')
        end
    else
        SignList(i) = stepsign;
        i = i+1;
        TimeList(i) = 1;
    end
end
TimeList(1) = TimeList(1)+TimeList(end);
TimeList(end) = [];

% Sets high low values and times for stepper
k = 1;
for i = 1:(length(TimeList))
    NewTime(k) = floor(TimeList(i)/2); %% This is time spent in high val
    PositionList(2,k) = heaviside(SignList(i));
    PositionList(3,k) = heaviside(-SignList(i));
    k = k + 1;
    NewTime(k) = TimeList(i) - floor(TimeList(i)/2); %% Time spent in low val. Total is correct 
    PositionList(2,k) = 0;
    PositionList(3,k) = 0;
    k = k + 1;    
end
PositionList(1,:) = NewTime*4; %%% UNJUSTIFIED FIX !!!!!!!!!!!!!!!!


%%% Turn signlist to bytes: add B before each 8 digits

StrSignC = string([PositionList(2,:),0,0,0,0,0,0,0]); % Zero Padding to complete 8-bit
StrSignCC = string([PositionList(3,:),0,0,0,0,0,0,0]);
BitSignC = 'B';
BitSignCC = 'B';
for i = 1:(length(PositionList)+7)
    j = mod(i,8);
    k = floor(i/8);
    BitSignC = [BitSignC, StrSignC(i)];
    BitSignCC = [BitSignCC, StrSignCC(i)];
        
    if (j==0)
        BitSignListC(k) = string(join(BitSignC, ''));
        BitSignListCC(k) = string(join(BitSignCC, ''));
        BitSignC = 'B';
        BitSignCC = 'B';
    end
end



% plot results
figure(1)
subplot(3,1,1)
hold on
bar(Time, PosDiscrete,1)
plot(Time, position(Time))

subplot(3,1,2)
hold on
%plot(TimeList)
plot(PositionList(2,:))
plot(PositionList(3,:))
subplot(3,1,3)
plot(Time, position(Time)-PosDiscrete)
xlabel('t')
ylabel('error')

figure(2)
plot(TimeList)




%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%% WRITE .INO FILE %%%%%%%%%

fid = fopen(['poslist.txt'], 'wt');
fprintf(fid, '#include <avr/pgmspace.h> \n// Interrupt Service Routine (ISR) \n');
fprintf(fid, 'int j=0, i=0; \n');
fprintf(fid, 'const int position[%d] PROGMEM= {', length(PositionList));
for i=1:length(PositionList)-1
    fprintf(fid, '%d,', PositionList(1,i));
end
fprintf(fid,'%d};\n', PositionList(1,end));
fprintf(fid, 'const byte direction[2][%d] PROGMEM = {{', length(BitSignListC));
for i=1:length(BitSignListC)-1
    fprintf(fid, '%s,', BitSignListC(i));
end
fprintf(fid,'%s},\n{', BitSignListC(end));
for i=1:length(BitSignListCC)-1
    fprintf(fid, '%s,', BitSignListCC(i));
end
fprintf(fid,'%s}\n}; \n', BitSignListCC(end));
fprintf(fid, 'ISR(TIMER1_COMPA_vect) \n { \n');
fprintf(fid, 'OCR1A = pgm_read_word(&(position[j]));\nOCR1B = pgm_read_word(&(position[j]));\n');
fprintf(fid, 'TCCR1A = (1 << COM1A1) | (1 << COM1B1) | (bitRead(pgm_read_byte(&direction[0][i]),7-j%%8) << COM1A0) | (bitRead(pgm_read_byte(&direction[1][i]),7-j%%8) << COM1B0); //clear/set OC1A,B on compare match\n');
fprintf(fid, 'j++;\nif (j == %d) {\n   j = 0; \n} \ni = floor(j/8);\n} ', length(PositionList));
fprintf(fid, '\n\nvoid setup(void)\n{\n');
fprintf(fid, 'pinMode(11, OUTPUT); //timer 1 OC1A\n');
fprintf(fid, 'pinMode(12,OUTPUT); //timer 1 OC1B\n\n');
fprintf(fid, 'cli();         // disable global interrupts\n');
fprintf(fid, 'TCCR1A = 0; // set registers = 0\n');
fprintf(fid, 'TCCR1B = 0;\n');
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

fprintf(fid, 'TIMSK1 = (1 << OCIE3A); //Enable timer compare interrupt\n\n');
fprintf(fid, 'sei();       // enable interrupts\n\n');
fprintf(fid, 'OCR1A = 60000; \nOCR1B = 60000;\n\n');
fprintf(fid, 'TCCR1B = (1 << WGM12)');
if OCR1Aprescaler == 1
    fprintf(fid, '| (1 << CS10);  //CTC mode, prescaler clock/1\n\n}');
elseif OCR1Aprescaler == 8
    fprintf(fid, '| (1 << CS11);  //CTC mode, prescaler clock/8\n\n}');
elseif OCR1Aprescaler == 64
    fprintf(fid, '| (1 << CS11) | (1 << CS10);  //CTC mode, prescaler clock/16\n\n}');
elseif OCR1Aprescaler == 256
    fprintf(fid, '| (1 << CS12);  //CTC mode, prescaler clock/256\n\n}');
elseif OCR1Aprescaler == 1024
    fprintf(fid, '| (1 << CS12) | (1 << CS10);  //CTC mode, prescaler clock/1024\n\n}');
else
    error('Select a different OCR1Aprescaler');
end
fprintf(fid, 'void loop(void)');

fprintf(fid, '\n{\n }');

fclose(fid);

