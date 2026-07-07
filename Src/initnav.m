function nav = initnav()
% ==================================================================================================
% INITNAV
%   initialize navigation data struct
% ==================================================================================================

global const

nav.eph      = []; % broadcast ephemeris
nav.peph     = []; % precies ephemeris
nav.pclk     = []; % precise clock
nav.iono     = NaN(const.NSYS, 8);
nav.dutc     = NaN(const.NSYS, 4);
nav.glo_fcn  = NaN(32, 1);
nav.cbias    = NaN(const.MAX_SAT, 3);
nav.rbias    = NaN(const.MAX_RCV, 3, 2);
nav.pcvs     = initpcv(const.MAX_SAT);
nav.sbassat  = [];
nav.sbasiono = [];
nav.dgps     = [];
nav.ssr      = [];