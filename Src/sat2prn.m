function [sys, prn] = sat2prn(sat)
% ==================================================================================================
% SAT2PRN
%   convert satellite index satellite system with PRN or slot number
% ==================================================================================================

global const

sat = sat(:);

valid = sat >= 1 & sat <= length(const.SAT2PRN);

sys = NaN(length(sat), 1);
prn = NaN(length(sat), 1);
sys(valid) = const.SAT2SYS(sat(valid));
prn(valid) = const.SAT2PRN(sat(valid));