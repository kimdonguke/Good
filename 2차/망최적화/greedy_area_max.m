function [isRef, info] = greedy_area_max(lon, lat, maxBaseKm, boundaryShrink)
% GREEDY_AREA_MAX  감시가능망 "면적" 최대화 (greedy_monitor_net 의 래퍼)
%   objective='area' 로 greedy_monitor_net 을 호출한다. 자세한 설명은 그쪽 참고.
    if nargin < 3; maxBaseKm = [];      end
    if nargin < 4; boundaryShrink = []; end
    [isRef, info] = greedy_monitor_net(lon, lat, maxBaseKm, boundaryShrink, 'area');
end
