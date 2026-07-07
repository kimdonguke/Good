function [r, e] = geodist(rs, rr)
% ==============================================================================
% GEODIST Compute geometric distance and line-of-sight vector
% ------------------------------------------------------------------------------
% Inputs:
%   rs <n x 3> : Satellite position (ECEF XYZ at transmission time) [m]
%   
%   rr <1 x 3> : Receiver position (ECEF XYZ at reception time) [m]
% ------------------------------------------------------------------------------
% Outputs:
%   r <n x 1> : geometric distance [m]
%
%   e <n x 3> : line-of-sight vector
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

e = rs - rr(ones(size(rs, 1), 1),:);
r = sqrt(sum(e.^2, 2));
e = e./r;
r = r + const.OMGE_GPS.*(rs(:,1).*rr(:,2) - rs(:,2).*rr(:,1))./const.C_LIGHT;