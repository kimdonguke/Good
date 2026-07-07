function [dgnss] = initdgnss(popt)
% ==================================================================================================
% INITRTK
%   initialize rtk control/result struct
% ==================================================================================================

global const

dgnss.sol  = initsol(1);  % solution struct
dgnss.rb   = zeros(1, 6); % base position and velocity [m | m/s]
dgnss.opt  = popt;        % processing options struct
dgnss.tt   = 0;           % time difference between current and previous epochs [s]

dgnss.x  = zeros(6, 1);      % float states
dgnss.P  = zeros(6, 6); % float states covariance

% satellite status struct
dgnss.ssat.sys   = NaN(const.MAX_SAT, 1);      % navigation system
dgnss.ssat.vs    = NaN(const.MAX_SAT, 1);      % valid satellite flag for SPP
dgnss.ssat.azel  = NaN(const.MAX_SAT, 2);      % satellite azimuth and elevation angles [rad]
dgnss.ssat.resp  = NaN(const.MAX_SAT, 5);      % residuals of pseudorange [m]
dgnss.ssat.resc  = NaN(const.MAX_SAT, 5);      % residuals of carrier-phase [m]
dgnss.ssat.vsat  = NaN(const.MAX_SAT, 5);      % valid satellite flag for DGPS / RTK / PPP
dgnss.ssat.snr   = NaN(const.MAX_SAT, 5);      % signal strength [dBHz]
dgnss.ssat.fix   = NaN(const.MAX_SAT, 5);      % ambiguity fix flag (1: float | 2: fix | 3: hold)
dgnss.ssat.slip  = zeros(const.MAX_SAT, 5, 2); % cycle slip flag (rover and base)
dgnss.ssat.half  = zeros(const.MAX_SAT, 5);    % half cycle valid flag
dgnss.ssat.lock  = zeros(const.MAX_SAT, 5);    % lock count of carrier-phase
dgnss.ssat.outc  = -popt.minlock*ones(const.MAX_SAT, 5);    % outage count of carrier-phase
dgnss.ssat.slipc = zeros(const.MAX_SAT, 5);    % cycle slip count
dgnss.ssat.rejc  = zeros(const.MAX_SAT, 5);    % rejection count
dgnss.ssat.gf    = zeros(const.MAX_SAT, 4);    % geometry-free phase [m]
dgnss.ssat.mw    = zeros(const.MAX_SAT, 4);    % melbourne-wubbena linear combination [m]
dgnss.ssat.phw   = zeros(const.MAX_SAT, 1);    % phase windup [cycles]
dgnss.ssat.pt    = NaN(const.MAX_SAT, 5, 2);   % previous carrier-phase time
dgnss.ssat.ph    = NaN(const.MAX_SAT, 5, 2);   % previous carrier-phase observable [cycle]