function [sol] = sppos(obss, navs, opt)

global const

% get the number of epochs to process
time = unique(obss(obss(:,2) == 1, 1));
nepoch = length(time(:));
if (~nepoch)
    disp('no observation data');
    return;
end

fprintf('sppos: # of epoch to process = %d\n', nepoch);

% mask observation data
obss = maskobs(obss, opt);

% initialization
sol = initsol(nepoch);

% temporary processing options
opt_ = opt;

% loop over epochs
for k = 1:1:nepoch    
    % get the observation data in current epoch
    obsk = getobs(obss, time(k));
    if isempty(obsk)
        fprintf('no observation data in current epoch: %d\n', k);
    end
    
    % single point positioning
%     [solk, stat] = pntpos(obsk, navs, opt_);
%     if (~stat || solk.stat == const.SOLQ_NONE)
%         fprintf('single point positioning error\n');
%         continue;
%     end
    
    [solk, stat] = pntpos(obsk, navs, opt_);
    if (~stat || solk.stat == const.SOLQ_NONE)
        fprintf('single point positioning error\n');
        gps = find(obsk(:,3) <= 32);
        if length(gps) >= 4
            disp('try spp using only GPS satellites');
            opt_.navsys = 'G';
            [solk, stat] = pntpos(obsk(gps,:), navs, opt_);
            opt_ = opt;
            
            if (~stat || solk.stat == const.SOLQ_NONE)
                continue;
            end
        else
            continue;
        end
    end
    
    % solution in current epoch
    sol.time(k) = solk.time;
    if (~stat)
        solk = initsol(1);
    end
    
    sol.rr(k, 1:6)  = solk.rr(1:6);
    sol.qr(k, 1:6)  = solk.qr(1:6);
    sol.qv(k, 1:6)  = solk.qv(1:6);
    sol.dtr(k, 1:5) = solk.dtr(1:5);
    sol.stat(k)     = solk.stat;
    sol.sataz(k,:)  = solk.sataz;
    sol.satel(k,:)  = solk.satel;
    sol.nsat(k)     = solk.nsat;
    sol.age(k)      = solk.age;
    sol.ratio(k)    = solk.ratio;
    sol.thres(k)    = solk.thres;
    sol.dop(k, 1:4) = solk.dop(1:4);
end

1;

% get the observation data by time -----------------------------------------------------------------
function [obs] = getobs(obss, time)

% get rover observation data
obs = obss(obss(:,2) == 1 & obss(:,1) == time,:);

% sort observation data by time, receiver and satellite index
obs = sortrows(obs, [1, 3], 'ascend');

% mask observation data by navigation system and excluded satellite flag ---------------------------
function [obs] = maskobs(obs, opt)

sys = sat2prn(obs(:,3));

% unselected navigation system
disabled = false(length(sys), 1);

if (~ismember('G', opt.navsys)), disabled = disabled | sys == 'G'; end
if (~ismember('R', opt.navsys)), disabled = disabled | sys == 'R'; end
if (~ismember('E', opt.navsys)), disabled = disabled | sys == 'E'; end
if (~ismember('J', opt.navsys)), disabled = disabled | sys == 'J'; end
if (~ismember('C', opt.navsys)), disabled = disabled | sys == 'C'; end
if (~ismember('I', opt.navsys)), disabled = disabled | sys == 'I'; end
if (~ismember('S', opt.navsys)), disabled = disabled | sys == 'S'; end

obs(disabled,:) = [];

% exclued satellites
excluded = opt.exsats(obs(:,3)) == 1;
excluded = excluded(:);
obs(excluded,:) = [];