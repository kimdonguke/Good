function [nav, popt] = setpcv(time, pcvss, pcvrs, nav, sta, popt)

global const
% set satellite antenna parameters
for sat = 1:const.MAX_SAT
    sys = sat2prn(sat);
    if ~ismember(sys, popt.navsys), continue; end
    pcv = searchpcv(time, sat, '', pcvss);
    if (pcv{1}.sat ~= 0)
        fprintf('setpcv: set satellite antenna PCV: sat %d\n', sat);
        nav.pcvs(sat) = pcv;
    else
        fprintf('setpcv: no satellite antenna PCV: sat %d\n', sat);
    end
end

% set receiver antenna parameters
for i = 1:numel(sta)
    if isempty(popt.anttype{i}), continue; end    
    if strcmp(popt.anttype{i}, '*')
        popt.anttype{i} = sta{i}.antdes;
        popt.staname{i} = sta{i}.name;
        if sta{i}.deltype == 1 % x/y/z
            if all(sta{i}.pos(1:3) ~= 0) && all(~isnan(sta{i}.pos(1:3)))
                enu = xyz2enu(sta{i}.pos(1:3) + sta{i}.del(1:3), sta{i}.pos(1:3));
            else
                enu = zeros(1, 3);
            end
        else % e/n/u
            enu = sta{i}.del(1:3);
        end
        
        popt.antdel{i}(1:3) = reshape(enu(:), 1, 3);
    end
    
    % search receiver antenna parameter
    pcv = searchpcv(time, 0, popt.anttype{i}, pcvrs);
    if (~isempty(pcv{1}.type) && pcv{1}.sat == 0)
        fprintf('setpcv: set receiver antenna PCV: %s\n', popt.anttype{i});
        popt.pcvr(i) = pcv;
    else
        fprintf('setpcv: no receiver antenna PCV: %s\n', popt.anttype{i});
    end
end

% serach antenna parameters ------------------------------------------------------------------------
function [pcv] = searchpcv(time, sat, type, pcvs)

pcv = initpcv(1);
if (sat) % satellite
    idx = find(sat == cellfun(@(c) c.sat, pcvs));
    if ~isempty(idx)
        pcv_ = pcvs(idx);
        for i = 1:numel(pcv_)
            if pcv_{i}.ts > time, continue; end
            if ~isnan(pcv_{i}.te) && pcv_{i}.te < time, continue; end
            pcv = pcv_(i);
        end
    end
else % receiver
    % receiver antenna with radome
    [found, idx] = ismember(type, cellfun(@(c) c.type, pcvs, 'UniformOutput', false));
    if (found)
        pcv = pcvs(idx);
    else
        type = split(type);
        type = [type{1}, pad('NONE', 20 - length(type{1}), 'left')];
        % receiver antenna without radome
        [found, idx] = ismember(type, cellfun(@(c) c.type, pcvs, 'UniformOutput', false));
        if (found)
            fprintf('searchpcv: PCV without radome is used type = %s', type);
            pcv = pcvs(idx);
        end
    end
end