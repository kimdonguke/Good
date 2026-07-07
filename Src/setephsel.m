function setephsel(sys, sel)
% ==================================================================================================
% SETEPHSEL
%   set the selected satellite ephemeris for multiple ones
% ==================================================================================================

global ephsel
if isempty(ephsel) % default ephemeris selection
    ephsel = [0, 0, 0, 0, 0, 0, 0]; % [GPS, GLO, GAL, QZS, BDS, IRN, SBS]
end

sel(sel ~= 0) = 1;

switch sys
    case 'G', ephsel(1) = sel;
    case 'R', ephsel(2) = sel;
    case 'E', ephsel(3) = sel;
    case 'J', ephsel(4) = sel;
    case 'C', ephsel(5) = sel;
    case 'I', ephsel(6) = sel;
    case 'S', ephsel(7) = sel;
end