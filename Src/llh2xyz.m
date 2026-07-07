function xyz = llh2xyz(llh)
%LLH2XYZ  Convert from latitude, longitude and height
%         to ECEF cartesian coordinates.  WGS-84
%
%	xyz = LLH2XYZ(llh)
%
%	llh(1) = latitude in radians
%	llh(2) = longitude in radians
%	llh(3) = height above ellipsoid in meters
%
%	xyz(1) = ECEF x-coordinate in meters
%	xyz(2) = ECEF y-coordinate in meters
%	xyz(3) = ECEF z-coordinate in meters

%	Reference: Understanding GPS: Principles and Applications,
%	           Elliott D. Kaplan, Editor, Artech House Publishers,
%	           Boston, 1996.
%
%	M. & S. Braasch 10-96
%	Copyright (c) 1996 by GPSoft
%	All Rights Reserved.

lat = llh(:,1);
lon = llh(:,2);
hgt = llh(:,3);

a = 6378137.0000;	% earth semimajor axis in meters
b = 6356752.3142;	% earth semiminor axis in meters
e = sqrt (1-(b/a).^2);

sinlat = sin(lat);
coslat = cos(lat);
coslon = cos(lon);
sinlon = sin(lon);
tanlat2 = (tan(lat)).^2;
tmp = 1 - e*e;
tmpden = sqrt(1 + tmp*tanlat2);

x = (a*coslon)./tmpden + hgt.*coslon.*coslat;

y = (a*sinlon)./tmpden + hgt.*sinlon.*coslat;

tmp2 = sqrt(1 - e*e*sinlat.*sinlat);
z = (a*tmp.*sinlat)./tmp2 + hgt.*sinlat;

xyz(:,1) = x;
xyz(:,2) = y;
xyz(:,3) = z;
