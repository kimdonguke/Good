function [llh] = xyz2llh(xyz)
% ==============================================================================
% XYZ2LLH Transform ECEF position to geodetic position
% ------------------------------------------------------------------------------
% Inputs:
%   xyz <n x 3 matrix> : ECEF position (X/Y/Z)
% ------------------------------------------------------------------------------
% Outputs:
%   llh <n x 3 matrix> : Geodetic position (latitude/longitude/height)
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

global const

n = size(xyz, 1);

e2 = const.FE_WGS84*(2 - const.FE_WGS84);
p  = sqrt(sum(xyz(:,1 : 2).^2, 2));
v  = const.RE_WGS84;
z  = xyz(:,3);
zk = zeros(n, 1);

while find(abs(z - zk) >= 1e-4)
   zk = z;
   sinphi = z./sqrt(p.^2 + z.^2);
   v = const.RE_WGS84./sqrt(1 - e2.*sinphi.^2);
   z = xyz(:,3) + v.*e2.*sinphi;
end

lat = atan(z./p);
lon = atan2(xyz(:,2), xyz(:,1));
hgt = sqrt(p.^2 + z.^2) - v;

lat(p <= 1E-12 & xyz(:,3) >  0) =  pi/2;
lat(p <= 1E-12 & xyz(:,3) <= 0) = -pi/2;
lon(p <= 1E-12) = 0;

llh = [lat, lon, hgt];