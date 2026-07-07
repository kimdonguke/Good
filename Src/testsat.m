function [valid] = testsat(sat, var, svh, opt)

global const

sat = sat(:); var = var(:); svh = svh(:);
sys = char(sat2prn(sat));

valid = true(length(sat), 1);

% excluded satellite
valid(opt.exsats(sat) == 1) = false;

% unselected satellite system
valid(~matches(string(sys), string(opt.navsys(:)))) = false;

% ephemeris unavailable or unhealthy
valid(svh ~= 0 | isnan(svh)) = false;

% invalid URA or SISA value
valid(var < 0 | var > const.MAX_VAR_EPH | isnan(var)) = false;

% included satellite
valid(opt.exsats(sat) == 2) = true;