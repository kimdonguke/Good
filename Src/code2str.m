function str = code2str(code)
% ==================================================================================================
% CODE2STR
%   convert observation code to observation code string
% ==================================================================================================

global const

code = code(:);

valid = code >= 1 & code <= length(const.CODE2STR);

str = strings(length(code), 1);
str(valid) = const.CODE2STR(code(valid));