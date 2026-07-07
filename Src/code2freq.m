function freq = code2freq(sat, code)
% ==================================================================================================
% CODE2FREQ
%   convert observation code with satellite index to carrier-frequency
% ==================================================================================================

global const

persistent fcn
if isempty(fcn)
    fcn = [...
        +1; ...     % slot number  1
        -4; ...     % slot number  2
        +5; ...     % slot number  3
        +6; ...     % slot number  4
        +1; ...     % slot number  5
        -4; ...     % slot number  6
        +5; ...     % slot number  7
        +6; ...     % slot number  8
        -2; ...     % slot number  9
        -7; ...     % slot number 10
        +0; ...     % slot number 11
        -1; ...     % slot number 12
        -2; ...     % slot number 13
        -7; ...     % slot number 14
        +0; ...     % slot number 15
        -1; ...     % slot number 16
        +4; ...     % slot number 17
        -3; ...     % slot number 18
        +3; ...     % slot number 19
        +2; ...     % slot number 20
        +4; ...     % slot number 21
        -3; ...     % slot number 22
        +3; ...     % slot number 23
        +2; ...     % slot number 24
        NaN; ...    % reserved
        NaN; ...    % reserved
        NaN];       % reserved
end

sat  = sat(:);
code = code(:);

if isempty(sat) || isempty(code), freq = []; return; end

% get observation code string
str = char(code2str(code));

% check satellite system
[sys, prn] = sat2prn(sat);

gps = sys == 'G';
glo = sys == 'R';
gal = sys == 'E';
qzs = sys == 'J';
bds = sys == 'C';
irn = sys == 'I';
sbs = sys == 'S';

% observation code to frequency
freq = NaN(length(code), 1);

% GPS (L1 / L2 / L5)
freq(str(:,2) == '1' & gps) = const.FREQ_L1;
freq(str(:,2) == '2' & gps) = const.FREQ_L2;
freq(str(:,2) == '5' & gps) = const.FREQ_L5;

% GLONASS (G1 / G2 / G3 / G1a / G2a)
freq(str(:,2) == '1' & glo) = const.FREQ_G1 + const.DFREQ_G1 * fcn(prn(str(:,2) == '1' & glo));
freq(str(:,2) == '2' & glo) = const.FREQ_G2 + const.DFREQ_G2 * fcn(prn(str(:,2) == '2' & glo));

freq(str(:,2) == '3' & glo) = const.FREQ_G3;
freq(str(:,2) == '4' & glo) = const.FREQ_G1A;
freq(str(:,2) == '6' & glo) = const.FREQ_G2A;

% Galileo (E1 / E5a / E5b / E5a+b / E6)
freq(str(:,2) == '1' & gal) = const.FREQ_E1;
freq(str(:,2) == '7' & gal) = const.FREQ_E5B;
freq(str(:,2) == '5' & gal) = const.FREQ_E5A;
freq(str(:,2) == '6' & gal) = const.FREQ_E6;
freq(str(:,2) == '8' & gal) = const.FREQ_E5AB;

% QZSS (L1 / L2 / L5 / LEX)
freq(str(:,2) == '1' & qzs) = const.FREQ_L1;
freq(str(:,2) == '2' & qzs) = const.FREQ_L2;
freq(str(:,2) == '5' & qzs) = const.FREQ_L5;
freq(str(:,2) == '6' & qzs) = const.FREQ_LEX;

% BeiDou (B1 / B1C / B2a / B2b / B2a+b / B3)
freq(str(:,2) == '1' & bds) = const.FREQ_B1C;
freq(str(:,2) == '2' & bds) = const.FREQ_B1;
freq(str(:,2) == '7' & bds) = const.FREQ_B2B;
freq(str(:,2) == '5' & bds) = const.FREQ_B2A;
freq(str(:,2) == '6' & bds) = const.FREQ_B3;
freq(str(:,2) == '8' & bds) = const.FREQ_B2AB;

% IRNSS (L5 / S)
freq(str(:,2) == '5' & irn) = const.FREQ_L5;
freq(str(:,2) == '9' & irn) = const.FREQ_S;

% SBAS (L1 / L5)
freq(str(:,2) == '1' & sbs) = const.FREQ_L1;
freq(str(:,2) == '5' & sbs) = const.FREQ_L5;