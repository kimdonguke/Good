function [mapfd, mapfw] = tropomapf(time, llh, azel)
% ==================================================================================================
% TROPOMAF compute tropospheric mapping function by NMF
% ==================================================================================================

hgts = [2.53E-5, 5.49E-3, 1.14E-3];
lats = [0, 15, 30, 45, 60, 75, 90];
coef = [...
    1.2769934E-3, 1.2769934E-3, 1.2683230E-3, 1.2465397E-3, 1.2196049E-3, 1.2045996E-3, 1.2045996E-3; ...
    2.9153695E-3, 2.9153695E-3, 2.9152299E-3, 2.9288445E-3, 2.9022565E-3, 2.9024912E-3, 2.9024912E-3; ...
    62.610505E-3, 62.610505E-3, 62.837393E-3, 63.721774E-3, 63.824265E-3, 64.258455E-3, 64.258455E-3; ...
    0.0000000E-0, 0.0000000E-0, 1.2709626E-5, 2.6523662E-5, 3.4000452E-5, 4.1202191E-5, 4.1202191E-5; ...
    0.0000000E-0, 0.0000000E-0, 2.1414979E-5, 3.0160779E-5, 7.2562722E-5, 11.723375E-5, 11.723375E-5; ...
    0.0000000E-0, 0.0000000E-0, 9.0128400E-5, 4.3497037E-5, 84.795348E-5, 170.37206E-5, 170.37206E-5; ...
    5.8021897E-4, 5.8021897E-4, 5.6794847E-4, 5.8118019E-4, 5.9727542E-4, 6.1641693E-4, 6.1641693E-4; ...
    1.4275268E-3, 1.4275268E-3, 1.5138625E-3, 1.4572752E-3, 1.5007428E-3, 1.7599082E-3, 1.7599082E-3; ...
    4.3472961E-2, 4.3472961E-2, 4.6729510E-2, 4.3908931E-2, 4.4626982E-2, 5.4736038E-2, 5.4736038E-2];

lat = llh(1)*180/pi;
hgt = llh(3);

% year from doy 28, added half a year for southern latitues
y = (time2doy(time) - 28)/365.25;
if lat < 0, y = y + 0.5; end

% mapping function
el   = azel(:,2);
lat  = abs(lat);
cosy = cos(2*pi*y);

ah = interp1(lats, coef(1,:), lat) - interp1(lats, coef(4,:), lat)*cosy;
bh = interp1(lats, coef(2,:), lat) - interp1(lats, coef(5,:), lat)*cosy;
ch = interp1(lats, coef(3,:), lat) - interp1(lats, coef(6,:), lat)*cosy;

aw = interp1(lats, coef(7,:), lat);
bw = interp1(lats, coef(8,:), lat);
cw = interp1(lats, coef(9,:), lat);

% ellipsoidal height is used instead of height above sea level
dm = (1./sin(el) - mapf(el, hgts(1), hgts(2), hgts(3)))*hgt/1E3;

mapfd = mapf(el, ah, bh, ch) + dm;  % dry mapping function
mapfw = mapf(el, aw, bw, cw);       % wet mapping function

% mapping function ---------------------------------------------------------------------------------
function [func] = mapf(el, a, b, c)

sinel = sin(el);
func = (1 + a./(1 + b./(1 + c)))./(sinel + (a./(sinel + b./(sinel + c))));