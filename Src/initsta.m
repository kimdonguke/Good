function sta = initsta(n)
% ==================================================================================================
% INITSTA
%   initialize station parameter struct
% ==================================================================================================

sta.name         = '';          % marker name
sta.marker       = '';          % marker number
sta.antdes       = '';          % antenna descriptor
sta.antsno       = '';          % antenna serial number
sta.rectype      = '';          % receiver type
sta.recver       = '';          % receiver firmware version
sta.recsno       = '';          % receiver serial number
sta.antsetup     = 0;           % antenna setup ID
sta.itrf         = 0;           % ITRF realization year
sta.deltype      = 0;           % antenna delta type (0: e/n/u | 1: x/y/z)
sta.pos          = zeros(1, 3); % antenna position (ECEF) [m]
sta.del          = zeros(1, 3); % antenna position delta (e/n/u or x/y/z) [m]
sta.hgt          = 0;           % antenna height [m]
sta.glo_cp_align = 0;           % GLONASS code-phase alignment (0: no | 1: yes)
sta.glo_cp_bias  = zeros(1, 4); % GLONASS code-phase biases [1C, 1P, 2C, 2P] [m]

sta = repmat({sta}, n, 1);