function enu = xyz2enu(xyz, org)
% ==============================================================================
% XYZ2ENU Transform ECEF coordinate to local tangent coordinate
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

tmpxyz = xyz;
tmporg = org;

nsat = size(xyz, 1);

dxyz = tmpxyz - tmporg(ones(size(xyz, 1), 1),:);

llh = xyz2llh(org);

sinphi = sin(llh(:,1));
cosphi = cos(llh(:,1));
sinlam = sin(llh(:,2));
coslam = cos(llh(:,2));

R = [-sinlam             coslam            0     ; ...
     -sinphi .* coslam  -sinphi .* sinlam  cosphi; ...
      cosphi .* coslam   cosphi .* sinlam  sinphi];
  
enu = R * dxyz';
enu = enu';
