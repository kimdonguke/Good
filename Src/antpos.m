function [opt, stat] = antpos(sta, rcv, opt)

if (any(isnan(sta{rcv}.pos)) || all(sta{rcv}.pos == 0) || numel(sta) < rcv)
    fprintf('no position in rinex obs header'); stat = 0;
else
    % antenna delta
    if (sta{rcv}.deltype == 0) % e/n/u
        del = [sta{rcv}.del(1:2), sta{rcv}.del(3) + sta{rcv}.hgt];
        xyz = enu2xyz(del, sta{rcv}.pos);
    else % x/y/z
        xyz = sta{rcv}.pos + sta{rcv}.del;
    end
    
    if (rcv == 1) % rover
        opt.rr = reshape(xyz(:), 1, 3);
    else % base
        opt.rb(1:3) = reshape(xyz(:), 1, 3);
    end
    
    stat = 1;
end