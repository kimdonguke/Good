function [sol] = dgnsspos(obss, navs, revs, opt)

global const

% get the number of epochs to process
time = unique(obss(obss(:,2) == 1, 1));
nepoch = length(time(:));
if (~nepoch)
    disp('no observation data for rover');
    return;
end

fprintf('dgnsspos: # of epoch to process = %d\n', nepoch);

% mask observation data
obss = maskobs(obss, opt);

% initialization
sol   = initsol(nepoch);
dgnss = initdgnss(opt);

% set epoch order
if (revs) % backward
    epoch = nepoch:-1:1;
else % forward
    epoch = 1:1:nepoch;
end

% set base station position
dgnss.rb = [opt.rb(1:3), zeros(1, 3)];

% temporary processing options
opt_ = opt;
opt_.iono  = const.IONOOPT_BRDC;
opt_.tropo = const.TROPOOPT_SAAS;

% loop over epochs
solk = initsol(1);
for k = epoch    
    % get the observation data in current epoch
    obsk = getobs(obss, time(k), opt.maxage);
    
    % count rover and base observations
    nr = length(find(obsk(:,2) == 1));
    nb = length(find(obsk(:,2) == 2));
    
    % previous epoch time
    t = dgnss.sol.time;
    
    % single point positioning
    if k == 1 || k == nepoch || all(solk.rr(1:3) == 0) || any(isnan(solk.rr(1:3)))
        [solk, stat] = pntpos(obsk(1:nr,:), navs, opt_);
        if (~stat || solk.stat == const.SOLQ_NONE)
            fprintf('single point positioning error\n');
            ngps = length(find(obsk(1:nr, 3) <= 32));
            if ngps >= 4
                disp('try spp using only GPS satellites');
                opt_.navsys = 'G';
                [solk, stat] = pntpos(obsk(1:nr,:), navs, opt_);
                opt_ = opt;
                
                if (~stat || solk.stat == const.SOLQ_NONE)
                    solk = initsol(1);
                    continue;
                end
            else
                solk = initsol(1);
                continue;
            end            
        end
    end
    
    dgnss.sol.rr(1:3) = solk.rr(1:3);
    dgnss.sol.rr(4:6) = solk.rr(4:6);
    
    % time difference between current and previous epochs
    if (t), dgnss.tt = dgnss.sol.time - t; end
    
    % check number of base observation and age of differential
    if (nb == 0)
        fprintf('no base observation data\n'); continue;
    end
    
    dgnss.sol.age = obsk(1, 1) - obsk(nr+1, 1);
    if (dgnss.sol.age > opt.maxage)
        fprintf('age of differential error (age = %.1fs)\n', dgnss.sol.age); continue;
    end
    
    % relative positioning
    [dgnss, stat] = relpos(dgnss, obsk, navs);
%     [dgnss, stat] = relposvel(dgnss, obsk, navs);
    
    % solution in current epoch
    sol.time(k) = dgnss.sol.time;
    if (stat)
        solk = dgnss.sol;
    else
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
    sol.dop(k, 1:4) = solk.dop(1:4);
end

1;

% get the observation data by time -----------------------------------------------------------------
function [obs] = getobs(obss, time, maxage)

% get rover observation data
obsr = obss(obss(:,2) == 1 & obss(:,1) == time,:);

% get base observation data
if ~isempty(obsr)
    %obsb = obss(obss(:,2) == 2,:);
    %obsb = obss(obss(:,2) == 2 & obss(:,1) <= time,:);
    %obsb = obsb(obsr(1, 1) >= obsb(:,1) & (obsr(1, 1) - obsb(:,1)) <= maxage,:);
    obsb = obss(obss(:,2) == 2 & (obsr(1, 1) - obss(:,1)) >= 0 & (obsr(1, 1) - obss(:,1)) <= maxage,:);
    [~, idx] = unique(obsb(:,1), 'rows');
    if (length(idx) > 1)
        obsb = obsb(idx(end):end,:);
    end
else
    obsb = [];
end

% sort observation data by time, receiver and satellite index
obs = sortrows([obsr; obsb], [2, 1, 3], 'ascend');

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