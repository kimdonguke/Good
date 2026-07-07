    function initconst()
% ==================================================================================================
% INITCONST
%   initialize constant struct
% ==================================================================================================

global const

%% processing mode
const.MODE = "GIB"; % gnss(G)/ins(I)/baro(B)

%% inertial
const.GRAVITY_OF_EARTH = 9.80665;
const.DCM_MATRIX = [0 0 -1; 1 0 0; 0 -1 0];
const.CutoffFreq = 2;
const.DownSampleFreq = 100;

%% android
const.mask_satnum_pos = 5;
const.mask_satnum_vel = 5;
const.mask_snr = 10;
const.mask_el = 10;
const.mask_pdop = 10;

% raim-fde
const.mask_respos = 10;
const.mask_resvel = 1;

% sdom
const.mask_sd_pmd_L1 = 10;
const.mask_sd_pmd_L2 = 10;
const.mask_sd_pmd_L5 = 10;
const.mask_sd_cmd_L1 = 1;
const.mask_sd_cmd_L2 = 1;
const.mask_sd_cmd_L5 = 1;

%% noise level
% gnss
const.noise_gps_L1 = 10;
const.noise_glo_L1 = 20;
const.noise_gal_L1 = 5;
const.noise_bds_L1 = 5;
const.noise_bds_L2 = 20;
const.noise_gps_L5 = 0.5;
const.noise_gal_L5 = 0.5;
const.noise_bds_L5 = 0.5;

% barometer
const.noise_baro = 0.3;

%% initconst
% second of week
const.WEEKSEC = 604800;

% gps time to unix time
const.GPST2UNIX = 315964800;

% speed of light
const.C_LIGHT = 299792458.0; % [m/s]

% radians to degree / degrees to radians
const.DEG2RAD = pi/180; % [rad/deg]
const.RAD2DEG = 180/pi; % [deg/rad]

% satellite system
const.SYS_NONE = 0; % none
const.SYS_GPS  = 1; % GPS
const.SYS_GLO  = 2; % GLONASS
const.SYS_GAL  = 3; % Galileo
const.SYS_QZS  = 4; % QZSS
const.SYS_BDS  = 5; % BDS
const.SYS_IRN  = 6; % IRNSS
const.SYS_SBS  = 7; % SBAS

% carrier frequency
const.FREQ_L1   = 1575.420E6;
const.FREQ_L2   = 1227.600E6;
const.FREQ_L5   = 1176.450E6;
const.FREQ_G1   = 1602.000E6;
const.FREQ_G2   = 1246.000E6;
const.DFREQ_G1  = 0.562500E6;
const.DFREQ_G2  = 0.437500E6;
const.FREQ_G3   = 1202.025E6;
const.FREQ_G1A  = 1600.995E6;
const.FREQ_G2A  = 1248.060E6;
const.FREQ_E1   = 1575.420E6;
const.FREQ_E5A  = 1176.450E6;
const.FREQ_E5B  = 1207.140E6;
const.FREQ_E5AB = 1191.795E6;
const.FREQ_E6   = 1278.750E6;
const.FREQ_LEX  = 1278.750E6;
const.FREQ_B1   = 1561.098E6;
const.FREQ_B1C  = 1575.420E6;
const.FREQ_B2A  = 1176.450E6;
const.FREQ_B2B  = 1207.140E6;
const.FREQ_B2AB = 1191.795E6;
const.FREQ_B3   = 1268.520E6;
const.FREQ_S    = 2492.028E6;

% number of frequencies of GLONASS
const.NFREQ_GLO = 2;

% measurement error scale factor
const.ERR_FACTOR_GPS = 1.0; % GPS
const.ERR_FACTOR_GLO = 1.5; % GLONASS
const.ERR_FACTOR_GAL = 1.0; % Galileo
const.ERR_FACTOR_QZS = 1.0; % QZSS
const.ERR_FACTOR_BDS = 1.0; % BDS
const.ERR_FACTOR_IRN = 1.5; % IRNSS
const.ERR_FACTOR_SBS = 3.0; % SBAS

% satellite PRN or slot number
const.PRN_GPS = (  1 :  32)'; % GPS
const.PRN_GLO = (  1 :  27)'; % GLONASS
const.PRN_GAL = (  1 :  36)'; % Galileo
const.PRN_QZS = (193 : 202)'; % QZSS
const.PRN_BDS = (  1 :  63)'; % BDS
const.PRN_IRN = (  1 :  14)'; % IRNSS
const.PRN_SBS = (120 : 158)'; % SBAS

% number of satellites for each satellite system
const.NSAT_GPS = length(const.PRN_GPS); % GPS
const.NSAT_GLO = length(const.PRN_GLO); % GLONASS
const.NSAT_GAL = length(const.PRN_GAL); % Galileo
const.NSAT_QZS = length(const.PRN_QZS); % QZSS
const.NSAT_BDS = length(const.PRN_BDS); % BDS
const.NSAT_IRN = length(const.PRN_IRN); % IRNSS
const.NSAT_SBS = length(const.PRN_SBS); % SBAS

% maximum number of satellites
const.MAX_SAT = ...
    const.NSAT_GPS + ...
    const.NSAT_GLO + ...
    const.NSAT_GAL + ...
    const.NSAT_QZS + ...
    const.NSAT_BDS + ...
    const.NSAT_IRN + ...
    const.NSAT_SBS;

% mapping table to convert satellite PRN or slot number to satellite index
const.PRN2SAT_GPS = const.PRN_GPS;
const.PRN2SAT_GLO = const.PRN_GLO + const.PRN2SAT_GPS(end);
const.PRN2SAT_GAL = const.PRN_GAL + const.PRN2SAT_GLO(end);
const.PRN2SAT_QZS = const.PRN_QZS + const.PRN2SAT_GAL(end) - const.PRN_QZS(1) + 1;
const.PRN2SAT_BDS = const.PRN_BDS + const.PRN2SAT_QZS(end);
const.PRN2SAT_IRN = const.PRN_IRN + const.PRN2SAT_BDS(end);
const.PRN2SAT_SBS = const.PRN_SBS + const.PRN2SAT_IRN(end) - const.PRN_SBS(1) + 1;

% mapping table to convert satellite index to satellite PRN or slot number
const.SAT2PRN = [...
    const.PRN_GPS; ...
    const.PRN_GLO; ...
    const.PRN_GAL; ...
    const.PRN_QZS; ...
    const.PRN_BDS; ...
    const.PRN_IRN; ...
    const.PRN_SBS];

% mapping table to convert satellite index to satellite system
const.SAT2SYS = [...
    repmat('G', const.NSAT_GPS, 1); ...
    repmat('R', const.NSAT_GLO, 1); ...
    repmat('E', const.NSAT_GAL, 1); ...
    repmat('J', const.NSAT_QZS, 1); ...
    repmat('C', const.NSAT_BDS, 1); ...
    repmat('I', const.NSAT_IRN, 1); ...
    repmat('S', const.NSAT_SBS, 1)];

% number of satellite systems
const.NSYS = 7; % GPS+GLO+GAL+QZS+BDS+IRN+SBS

% maximum number of receiver
const.MAX_RCV = 64;

% maximum time difference to GNSS Toe
const.MAX_DTOE_GPS =  7200; % GPS
const.MAX_DTOE_GLO =  1800; % GLONASS
const.MAX_DTOE_GAL = 14400; % Galileo
const.MAX_DTOE_QZS =  7200; % QZSS
const.MAX_DTOE_BDS = 21600; % BDS
const.MAX_DTOE_IRN =  7200; % IRNSS
const.MAX_DTOE_SBS =   360; % SBAS

% observation code
const.CODE_NONE =  0; % obs code: none or unknown
const.CODE_L1C  =  1; % obs code: L1C/A,G1C/A,E1C (GPS,GLO,GAL,QZS,SBS)
const.CODE_L1P  =  2; % obs code: L1P,G1P,B1P (GPS,GLO,BDS)
const.CODE_L1W  =  3; % obs code: L1 Ztrack (GPS)
const.CODE_L1Y  =  4; % obs code: L1Y        (GPS)
const.CODE_L1M  =  5; % obs code: L1M        (GPS)
const.CODE_L1N  =  6; % obs code: L1codeless,B1codeless (GPS,BDS)
const.CODE_L1S  =  7; % obs code: L1C(D)     (GPS,QZS)
const.CODE_L1L  =  8; % obs code: L1C(P)     (GPS,QZS)
const.CODE_L1E  =  9; % (not used)
const.CODE_L1A  = 10; % obs code: E1A,B1A    (GAL,BDS)
const.CODE_L1B  = 11; % obs code: E1B        (GAL)
const.CODE_L1X  = 12; % obs code: E1B+C,L1C(D+P),B1D+P (GAL,QZS,BDS)
const.CODE_L1Z  = 13; % obs code: E1A+B+C,L1S (GAL,QZS)
const.CODE_L2C  = 14; % obs code: L2C/A,G1C/A (GPS,GLO)
const.CODE_L2D  = 15; % obs code: L2 L1C/A(P2P1) (GPS)
const.CODE_L2S  = 16; % obs code: L2C(M)     (GPS,QZS)
const.CODE_L2L  = 17; % obs code: L2C(L)     (GPS,QZS)
const.CODE_L2X  = 18; % obs code: L2C(M+L),B1_2I+Q (GPS,QZS,BDS)
const.CODE_L2P  = 19; % obs code: L2P,G2P    (GPS,GLO)
const.CODE_L2W  = 20; % obs code: L2 Ztrack (GPS)
const.CODE_L2Y  = 21; % obs code: L2Y        (GPS)
const.CODE_L2M  = 22; % obs code: L2M        (GPS)
const.CODE_L2N  = 23; % obs code: L2codeless (GPS)
const.CODE_L5I  = 24; % obs code: L5I,E5aI   (GPS,GAL,QZS,SBS)
const.CODE_L5Q  = 25; % obs code: L5Q,E5aQ   (GPS,GAL,QZS,SBS)
const.CODE_L5X  = 26; % obs code: L5I+Q,E5aI+Q,L5B+C,B2aD+P (GPS,GAL,QZS,IRN,SBS,BDS)
const.CODE_L7I  = 27; % obs code: E5bI,B2bI  (GAL,BDS)
const.CODE_L7Q  = 28; % obs code: E5bQ,B2bQ  (GAL,BDS)
const.CODE_L7X  = 29; % obs code: E5bI+Q,B2bI+Q (GAL,BDS)
const.CODE_L6A  = 30; % obs code: E6A,B3A    (GAL,BDS)
const.CODE_L6B  = 31; % obs code: E6B        (GAL)
const.CODE_L6C  = 32; % obs code: E6C        (GAL)
const.CODE_L6X  = 33; % obs code: E6B+C,LEXS+L,B3I+Q (GAL,QZS,BDS)
const.CODE_L6Z  = 34; % obs code: E6A+B+C,L6D+E (GAL,QZS)
const.CODE_L6S  = 35; % obs code: L6S        (QZS)
const.CODE_L6L  = 36; % obs code: L6L        (QZS)
const.CODE_L8I  = 37; % obs code: E5abI      (GAL)
const.CODE_L8Q  = 38; % obs code: E5abQ      (GAL)
const.CODE_L8X  = 39; % obs code: E5abI+Q,B2abD+P (GAL,BDS)
const.CODE_L2I  = 40; % obs code: B1_2I      (BDS)
const.CODE_L2Q  = 41; % obs code: B1_2Q      (BDS)
const.CODE_L6I  = 42; % obs code: B3I        (BDS)
const.CODE_L6Q  = 43; % obs code: B3Q        (BDS)
const.CODE_L3I  = 44; % obs code: G3I        (GLO)
const.CODE_L3Q  = 45; % obs code: G3Q        (GLO)
const.CODE_L3X  = 46; % obs code: G3I+Q      (GLO)
const.CODE_L1I  = 47; % obs code: B1I        (BDS) (obsolute)
const.CODE_L1Q  = 48; % obs code: B1Q        (BDS) (obsolute)
const.CODE_L5A  = 49; % obs code: L5A SPS    (IRN)
const.CODE_L5B  = 50; % obs code: L5B RS(D)  (IRN)
const.CODE_L5C  = 51; % obs code: L5C RS(P)  (IRN)
const.CODE_L9A  = 52; % obs code: SA SPS     (IRN)
const.CODE_L9B  = 53; % obs code: SB RS(D)   (IRN)
const.CODE_L9C  = 54; % obs code: SC RS(P)   (IRN)
const.CODE_L9X  = 55; % obs code: SB+C       (IRN)
const.CODE_L1D  = 56; % obs code: B1D        (BDS)
const.CODE_L5D  = 57; % obs code: L5D(L5S),B2aD (QZS,BDS)
const.CODE_L5P  = 58; % obs code: L5P(L5S),B2aP (QZS,BDS)
const.CODE_L5Z  = 59; % obs code: L5D+P(L5S) (QZS)
const.CODE_L6E  = 60; % obs code: L6E        (QZS)
const.CODE_L7D  = 61; % obs code: B2bD       (BDS)
const.CODE_L7P  = 62; % obs code: B2bP       (BDS)
const.CODE_L7Z  = 63; % obs code: B2bD+P     (BDS)
const.CODE_L8D  = 64; % obs code: B2abD      (BDS)
const.CODE_L8P  = 65; % obs code: B2abP      (BDS)
const.CODE_L4A  = 66; % obs code: G1aL1OCd   (GLO)
const.CODE_L4B  = 67; % obs code: G1aL1OCd   (GLO)
const.CODE_L4X  = 68; % obs code: G1al1OCd+p (GLO)
const.MAX_CODE  = 68; % max number of obs code

% mapping table to covert observation code to observation code string
const.CODE2STR = [...
    "L1C"; ...
    "L1P"; ...
    "L1W"; ...
    "L1Y"; ...
    "L1M"; ...
    "L1N"; ...
    "L1S"; ...
    "L1L"; ...
    "L1E"; ...
    "L1A"; ...
    "L1B"; ...
    "L1X"; ...
    "L1Z"; ...
    "L2C"; ...
    "L2D"; ...
    "L2S"; ...
    "L2L"; ...
    "L2X"; ...
    "L2P"; ...
    "L2W"; ...
    "L2Y"; ...
    "L2M"; ...
    "L2N"; ...
    "L5I"; ...
    "L5Q"; ...
    "L5X"; ...
    "L7I"; ...
    "L7Q"; ...
    "L7X"; ...
    "L6A"; ...
    "L6B"; ...
    "L6C"; ...
    "L6X"; ...
    "L6Z"; ...
    "L6S"; ...
    "L6L"; ...
    "L8I"; ...
    "L8Q"; ...
    "L8X"; ...
    "L2I"; ...
    "L2Q"; ...
    "L6I"; ...
    "L6Q"; ...
    "L3I"; ...
    "L3Q"; ...
    "L3X"; ...
    "L1I"; ...
    "L1Q"; ...
    "L5A"; ...
    "L5B"; ...
    "L5C"; ...
    "L9A"; ...
    "L9B"; ...
    "L9C"; ...
    "L9X"; ...
    "L1D"; ...
    "L5D"; ...
    "L5P"; ...
    "L5Z"; ...
    "L6E"; ...
    "L7D"; ...
    "L7P"; ...
    "L7Z"; ...
    "L8D"; ...
    "L8P"; ...
    "L4A"; ...
    "L4B"; ...
    "L4X"];

% positioning mode
const.POSMODE_SINGLE     = 0; % single
const.POSMODE_DGPS       = 1; % DGPS/DGNSS
const.POSMODE_KINEMA     = 2; % kinematic
const.POSMODE_STATIC     = 3; % static
const.POSMODE_MOVEB      = 4; % moving-base
const.POSMODE_FIXED      = 5; % fixed
const.POSMODE_PPP_KINEMA = 6; % PPP-kinematic
const.POSMODE_PPP_STATIC = 7; % PPP-static
const.POSMODE_PPP_FIXED  = 8; % PPP-fixed

% ionosphere option
const.IONOOPT_OFF  = 0;   % No ionospheric correction
const.IONOOPT_BRDC = 1;   % Klobuchar model
const.IONOOPT_IFLC = 3;   % Ionofree linear combination
const.IONOOPT_EST  = 4;   % estimation

% troposphere option
const.TROPOOPT_OFF  = 0;  % No correction
const.TROPOOPT_SAAS = 1;  % Saastamoinen model
const.TROPOOPT_EST  = 3;  % ZTD estimation
const.TROPOOPT_ESTG = 4;  % ZTD + grid estimation

% time system
const.TSYS_GPS = 0; % GPS time
const.TSYS_UTC = 1; % UTC
const.TSYS_GLO = 2; % GLONASS time
const.TSYS_GAL = 3; % Galileo time
const.TSYS_QZS = 4; % QZSS time
const.TSYS_BDS = 5; % BDS time
const.TSYS_IRN = 6; % IRNSS time

% satellite ephemeris and clock option
const.EPHOPT_BRDC   = 0;  % Broadcast ephemeris and clock
const.EPHOPT_PREC   = 1;  % Precise ephemeris and clock

% ambiguity resolution mode
const.ARMODE_OFF     = 0;     % Off
const.ARMODE_CONT    = 1;     % Continuous
const.ARMODE_INST    = 2;     % Instantaneous
const.ARMODE_FIXHOLD = 3;     % Fix and hold

% GLONASS ambiguity resolution mode
const.GLOARMODE_OFF     = 0;
const.GLOARMODE_ON      = 1;
const.GLOARMODE_AUTOCAL = 2;
const.GLOARMODE_FIXHOLD = 3;

% position type for fixed or relative mode
const.POSTYPE_XYZ    = 0; % x/y/z
const.POSTYPE_SINGLE = 1; % average of single point positioning solution
const.POSTYPE_RINEX  = 2; % RINEX header
const.POSTYPE_RTCM   = 3; % RTCM or raw station position

% solution status
const.SOLQ_NONE   = 0;    % No solution
const.SOLQ_FIX    = 1;    % Fixed ambiguity
const.SOLQ_FLOAT  = 2;    % Float ambiguity
const.SOLQ_SBAS   = 3;    % SBAS
const.SOLQ_DGPS   = 4;    % DGPS/DGNSS
const.SOLQ_SINGLE = 5;    % Single
const.SOLQ_PPP    = 6;    % PPP

% Earth's semimajor axis
const.RE_WGS84 = 6378137.0;   % WGS84
const.RE_GLO   = 6378136.0;   % PZ90.02

% Earth's flattening
const.FE_WGS84 = 1.0 / 298.257223563; % WGS84

% Earth's gravitational constant
const.MU_GPS = 3.986005000E14; % GPS
const.MU_GLO = 3.986004400E14; % GLONASS
const.MU_GAL = 3.986004418E14; % Galileo
const.MU_QZS = 3.986005000E14; % QZSS
const.MU_BDS = 3.986004418E14; % BDS
const.MU_IRN = 3.986005000E14; % IRNSS
const.MU_SBS = 3.986005000E14; % SBAS

% Earth's angular velocity
const.OMGE_GPS = 7.2921151467E-5; % GPS
const.OMGE_GLO = 7.2921150000E-5; % GLONASS
const.OMGE_GAL = 7.2921151467E-5; % Galileo
const.OMGE_QZS = 7.2921151467E-5; % QZSS
const.OMGE_BDS = 7.2921150000E-5; % BDS
const.OMGE_IRN = 7.2921151467E-5; % IRNSS
const.OMGE_SBS = 7.2921151467E-5; % SBAS

% error standard deviation
const.ERR_IONO  = 5.0;    % ionospheric delay
const.ERR_TROPO = 3.0;    % tropospheric delay
const.ERR_SAAS  = 0.3;    % Saastamoinen model
const.ERR_CBIAS = 0.3;    % code bias error

% relative humidity for Saastamoinen model
const.REL_HUMI = 0.7;

% minimum elevation angle for pseudorange measurement error
const.MIN_EL = 5*pi/180;

% error factor of broadcast ionosphere model
const.ERR_FACTOR_BRDCI = 0.5;

% maximum variance of ephemeris error to reject satellite [m^2]
const.MAX_VAR_EPH = 300^2;

% maximum number of iterations for least squares
const.MAX_ITER_LSQ = 10;

% ionospheric height [m]
const.H_IONO = 350E3;

% maximum number of iteration of kepler equation
const.MAX_ITER_KEPLER = 30;

% error of GLONASS broadcast ephemeris and clock [m]
const.ERREPH_GLO = 5;

% integration step of GLONASS broadcast ephemeris [s]
const.TSTEP = 60;

% second zonal harmonic of geopotential
const.J2_GLO = 1.08262575E-3;

% error of Galileo broadcast ephemeris and clock for NAPA [m]
const.ERREPH_GAL_NAPA = 500;

% error of broadcast clock [m]
const.STD_BRDCCLK = 30;

% order of polynomial interpolation
const.N_MAX = 10;

% maximum time difference to precise ephemeris time [s]
const.MAX_DTE = 900;

% extrapolation error for precise ephemeris and clock
const.EXTERR_EPH = 5E-7; % [m/s^2]
const.EXTERR_CLK = 1E-3; % [m/s]

% Galileo navigation type
const.GAL_NAV = 0; % 0: I/NAV | 1: F/NAV

% URA values
const.URA_EPH = [2.4, 3.4, 4.85, 6.85, 9.65, 13.65, 24.0, 48.0, 96.0, 192.0, 384.0, 768.0, 1536.0, 3072.0, 6144.0, 0.0];

% URA nominal values
const.URA_NOMINAL = [2.0, 2.8, 4.0, 5.7, 8.0, 11.3, 16.0, 32.0, 64.0, 128.0, 256.0, 512.0, 1024.0, 2048.0, 4096.0, 8192.0];