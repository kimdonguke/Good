function code = str2code(str)
% ==================================================================================================
% STR2CODE
%   convert observation code string to observation code
% ==================================================================================================

global const

str = string(str);
str = str(:);

[valid, idx] = ismember(str, const.CODE2STR);

code = NaN(numel(str), 1);
code(valid) = idx(valid);