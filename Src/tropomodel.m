function tropo = tropomodel(time, llh, azel, humi)
% ==============================================================================
% TROPOMODEL Compute tropospheric delay by standard atmosphere and saastamoinen
%            model
% ------------------------------------------------------------------------------
% Inputs:
% ------------------------------------------------------------------------------
% Outputs:
% ------------------------------------------------------------------------------
% References:
%   -
% ------------------------------------------------------------------------------
% Author:
%   Cheolsoon Lim (csleem@sju.ac.kr)
% ------------------------------------------------------------------------------
% History:
%   -
% ==============================================================================

temp0 = 15; % temparature at sea level

hgt = llh(3);
if (hgt < -100 || hgt > 1E4)
    tropo = zeros(size(azel, 1), 1);
    return;
end

% standard atmosphere
if llh(3) < 0
    hgt = 0;
else
    hgt = llh(3);
end

pres = 1013.25*(1.0 - 2.2557E-5*hgt)^5.2568;
temp = temp0 - 6.5E-3*hgt + 273.16;
e    = 6.108*humi*exp((17.15*temp - 4684.0)/(temp - 38.45));

% dry and wet delay
z = pi/2.0 - azel(:,2);
dry = 0.0022768*pres/(1.0 - 0.00266*cos(2.0*llh(1)) - 0.00028*hgt/1E3)./cos(z);
wet = 0.002277*(1255.0/temp + 0.05)*e./cos(z);

% total delay
tropo = dry + wet;
tropo(azel(:,2) <= 0) = 0;