function [iono] = ionomodel(time, param, llh, azel)
% ==================================================================================================
% IONOMODEL
%   compute ionospheric delay by broadcast ionosphere model (klobuchar model)
% ==================================================================================================

global const

persistent defparam
if isempty(defparam)
    defparam = [... % 2004/1/1
        0.1118E-07, -0.7451E-08, -0.5961E-07, 0.1192E-06, ...
        0.1167E+06, -0.2294E+06, -0.1311E+06, 0.1049E+07];
end

if any(isnan(param)) || all(param == 0), param = defparam; end

if (llh(3) < 1E-3)
    iono = zeros(size(azel, 1), 1);
    return;
end

% earth centered angle (semi-circle)
psi = 0.0137./(azel(:,2)./pi + 0.11) - 0.022;

% subionospheric latitude and longitude (semi-circle)
phi = llh(:,1)./pi + psi.*cos(azel(:,1));
lam = llh(:,2)./pi + psi.*sin(azel(:,1))./cos(phi*pi);

phi(phi >  0.416) =  0.416;
phi(phi < -0.416) = -0.416;

% geomagnetic latitude (semi-circle)
phi = phi + 0.064.*cos((lam - 1.617)*pi);

% local time
[~, tow] = time2gpst(time);

tt = mod(43200*lam + tow, 86400);

% slant factor
f = 1 + 16.*(0.53 - azel(:,2)/pi).^3;

% ionospheric delay
amp = param(1) + phi.*(param(2) + phi.*(param(3) + phi.*param(4)));
per = param(5) + phi.*(param(6) + phi.*(param(7) + phi.*param(8)));

amp(amp < 0) = 0;
per(per < 72000) = 72000;

x = 2 * pi * (tt - 50400) ./ per;

i = abs(x) < 1.57;

iono = NaN(size(azel, 1), 1);
iono( i) = const.C_LIGHT.*f(i).*(5E-9 + amp(i).*(1 + x(i).^2.*(-0.5 + x(i).^2/24)));
iono(~i) = const.C_LIGHT.*f(~i).*5E-9;