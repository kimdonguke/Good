function pcv = initpcv(n)
% ==================================================================================================
% INITPCV
%   initialize antenna parameters struct
% ==================================================================================================

pcv.sat  = NaN;        % satellite index (0: receiver)
pcv.type = '';         % antenna type
pcv.code = '';         % serial number or satellite code
pcv.ts   = NaN;        % valid time (start)
pcv.te   = NaN;        % valid time (end)
pcv.off  = NaN( 3, 5); % phase center offset (receiver: e/n/u | satellite: x/y/z) [m]
pcv.var  = NaN(19, 5); % phaes center variation [m]
                       % elevation angle = 90, 85, ..., 0 [deg]
                       % nadir angle = 0, 1, 2, 3, 4, ... [deg]
                       
pcv = repmat({pcv}, n, 1);