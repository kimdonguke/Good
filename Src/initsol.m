function sol = initsol(n)
% ==================================================================================================
% INITSOL
%   initialize solution struct
% ==================================================================================================

global const

sol.time  = zeros(n, 1);            % solution time in GPST [s]
sol.rr    = zeros(n, 6);            % receiver position and velocity [m | m/s]
sol.qr    = zeros(n, 6);            % receiver position variance-covariance [m^2]
sol.qv    = zeros(n, 6);            % receiver velocity variance-covariance [m^2/s^2]
sol.dtr   = zeros(n, 5);            % receiver clock bias to time systems [s]
sol.stat  = zeros(n, 1);            % solution status (SOLQ_?)
sol.sataz = NaN(n, const.MAX_SAT);  % satellite azimuth angle [deg]
sol.satel = NaN(n, const.MAX_SAT);  % satellite elevation angle [deg]
sol.nsat  = zeros(n, 1);            % number of valid satellites
sol.age   = zeros(n, 1);            % age of differential [s]
sol.ratio = zeros(n, 1);            % AR ratio for validation test
sol.thres = zeros(n, 1);            % AR ratio threshold for validation test
sol.dop   = zeros(n, 4);            % DOP values (GDOP / PDOP / HDOP / VDOP)