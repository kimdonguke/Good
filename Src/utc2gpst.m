function [gpst] = utc2gpst(utc)
% ==============================================================================
% UTC2GPST Convert standard time in UTC time to standard time in GPS time
% ------------------------------------------------------------------------------
% Inputs:
%   utc <n x 1 matrix> : Standard time in UTC time
% ------------------------------------------------------------------------------
% Outputs:
%   gpst <n x 1 matrix> : Standard time in GPS time
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

persistent leaps

if isempty(leaps)
    leaps{ 1} = [cal2time([2017, 1, 1, 0, 0, 0]), -18];
    leaps{ 2} = [cal2time([2015, 7, 1, 0, 0, 0]), -17];
    leaps{ 3} = [cal2time([2012, 7, 1, 0, 0, 0]), -16];
    leaps{ 4} = [cal2time([2009, 1, 1, 0, 0, 0]), -15];
    leaps{ 5} = [cal2time([2006, 1, 1, 0, 0, 0]), -14];
    leaps{ 6} = [cal2time([1999, 1, 1, 0, 0, 0]), -13];
    leaps{ 7} = [cal2time([1997, 7, 1, 0, 0, 0]), -12];
    leaps{ 8} = [cal2time([1996, 1, 1, 0, 0, 0]), -11];
    leaps{ 9} = [cal2time([1994, 7, 1, 0, 0, 0]), -10];
    leaps{10} = [cal2time([1993, 7, 1, 0, 0, 0]),  -9];
    leaps{11} = [cal2time([1992, 7, 1, 0, 0, 0]),  -8];
    leaps{12} = [cal2time([1991, 1, 1, 0, 0, 0]),  -7];
    leaps{13} = [cal2time([1990, 1, 1, 0, 0, 0]),  -6];
    leaps{14} = [cal2time([1988, 1, 1, 0, 0, 0]),  -5];
    leaps{15} = [cal2time([1985, 7, 1, 0, 0, 0]),  -4];
    leaps{16} = [cal2time([1983, 7, 1, 0, 0, 0]),  -3];
    leaps{17} = [cal2time([1982, 7, 1, 0, 0, 0]),  -2];
    leaps{18} = [cal2time([1981, 7, 1, 0, 0, 0]),  -1];
end

gpst = NaN(length(utc(:)), 1);
for i = 1 : length(gpst)
    for j = 1 : numel(leaps)
        if (utc - leaps{j}(1)) >= 0
            gpst(i) = utc(i) - leaps{j}(2);
            break;
        end
    end
end