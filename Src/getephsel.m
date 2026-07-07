function [sel] = getephsel(sys)
% ==================================================================================================
% GETEPHSEL
%   get the selected satellite ephemeris
% ==================================================================================================

global ephsel
if isempty(ephsel) % default ephemeris selection
    ephsel = [0, 0, 0, 0, 0, 0, 0]; % [GPS, GLO, GAL, QZS, BDS, IRN, SBS]
end

sys = sys(:);

gps = sys == 'G'; % GPS
glo = sys == 'R'; % GLONASS
gal = sys == 'E'; % Galileo
qzs = sys == 'J'; % QZSS
bds = sys == 'C'; % BDS
irn = sys == 'I'; % IRNSS
sbs = sys == 'S'; % SBAS

sel = zeros(length(sys(:)), 1);
sel(gps) = ephsel(1);
sel(glo) = ephsel(2);
sel(gal) = ephsel(3);
sel(qzs) = ephsel(4);
sel(bds) = ephsel(5);
sel(irn) = ephsel(6);
sel(sbs) = ephsel(7);