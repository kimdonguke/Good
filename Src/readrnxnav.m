function [eph, iono, dutc] = readrnxnav(files)

% check the input argument (char or string to cell)
if ischar(files) || ischar(files)
    files = {files};
end

% initialize outputs
eph  = [];
iono = NaN(7, 8);
dutc = NaN(7, 4);

% loop over input files
for f = 1:numel(files)
    % get the file buffer
    [buff, lim] = getbuff(files{f});
    if isempty(buff), continue; end
    
%     fprintf('readrnxnav: reading rinex navigation message file > %s\n', files{f});
    
    % read the file header
    header = readrnxnavh(buff, lim);
    if ~header.ver, continue; end
    
    % update ionospheric corrrection parameters and delta-UTC parameters
    for s = 1:7
        if any(isnan(iono(s,:))) || all(iono(s,:) == 0), iono(s,:) = header.iono(s,:); end
        if any(isnan(dutc(s,:))) || all(dutc(s,:) == 0), dutc(s,:) = header.dutc(s,:); end
    end
    
    % read the file body
    body = readrnxnavb(buff, lim, header);
    
    % decode broadcast ephemeris
    eph = [eph; decodeeph(header, body)]; %#ok<AGROW>
end

% sort broadcast ephemeris
eph = sorteph(eph);

% get the file buffer and line information ---------------------------------------------------------
function [buff, lim] = getbuff(file)

% initialize outputs
buff = [];
lim  = [];

% open the file
fid = fopen(file, 'r');
if fid < 0
    fprintf('getbuff: rinex navigation message file open error > %s\n', file);
    return;
end

% get the file buffer and remove carriage return
buff = fread(fid, '*char')';
buff(buff == char(13)) = [];

% close the file
fclose(fid);

% find new line separators
nlpos = regexp(buff, '\n')';
if nlpos(end) < numel(buff)
    nlpos = [nlpos; numel(buff)];
end

% build the matrix containing the line information
lim(:,1) = [1; nlpos(1:end - 1) + 1]; % start
lim(:,2) = nlpos - 1;                 % end
lim(:,3) = lim(:,2) - lim(:,1);       % length

while lim(end, 3) < 3
    lim(end,:) = [];
end

% remove empty lines at the end of the file
while (lim(end, 1) - lim(end - 1, 1)) < 2
    lim(end,:) = [];
end

% read the RINEX NAV header ------------------------------------------------------------------------
function [header] = readrnxnavh(buff, lim)

header = struct('ver', 0, 'type', '', 'sys', '', 'iono', NaN(7, 8), 'dutc', NaN(7, 4));

% loop over all header lines
l = 0;
while l < size(lim, 1)
    % read a line
    l = l + 1;
    line = buff(lim(l, 1):lim(l, 2));
    
    % parse the header information
    if contains(line, 'RINEX VERSION / TYPE')
        header.ver  = sscanf(line(1:9), '%f');
        header.type = sscanf(line(21), '%c');
        
        if ~ismember(header.type, 'NHGL')
            fprintf('readrnxnavh: invalid rinex file type > %s', header.type);
            header.ver = 0;
            return;
        end
        
        if header.ver < 3 % version 2.xx
            switch header.type
                case 'N', header.sys = 'G'; % GPS
                case 'G', header.sys = 'R'; % GLONASS
                case 'L', header.sys = 'E'; % Galileo
                case 'H', header.sys = 'S'; % SBAS
            end
        else % version 3.xx
            header.sys = sscanf(line(41), '%c');
        end
        
        if ~ismember(header.sys, 'GREJCISM')
            fprintf('readrnxnavh: invalid RINEX satellite system > %s', header.sys);
            header.ver = 0;
            return;
        end
        
    elseif contains(line, 'PGM / RUN BY / DATE')
    elseif contains(line, 'COMMENT')
    elseif contains(line, 'ION ALPHA')
        header.iono(1, 1:4) = cell2mat(textscan(line(3:50), '%f %f %f %f'));
        
    elseif contains(line, 'ION BETA')
        header.iono(1, 5:8) = cell2mat(textscan(line(3:50), '%f %f %f %f'));
        
    elseif contains(line, 'IONOSPHERIC CORR')
        type  = deblank(line(1:4));
        param = sscanf(line(5:53), '%f');
        
        switch type
            case 'GPSA', header.iono(1, 1:4) = param;
            case 'GPSB', header.iono(1, 5:8) = param;
            case 'QZSA', header.iono(4, 1:4) = param;
            case 'QZSB', header.iono(4, 5:8) = param;
            case 'BDSA', header.iono(5, 1:4) = param;
            case 'BDSB', header.iono(5, 5:8) = param;
            case 'IRNA', header.iono(6, 1:4) = param;
            case 'IRNB', header.iono(6, 5:8) = param;
            case 'GAL',  header.iono(3, 1:3) = param;
        end
        
    elseif contains(line, 'DELTA-UTC: A0,A1,T,W')
        header.dutc(1, 1:4) = cell2mat(textscan(line(3:59), '%f %f %f %f'));
        
    elseif contains(line, 'TIME SYSTEM CORR')
        type  = deblank(line(1:4));
        param = sscanf(line(5:50), '%f');
        
        switch type
            case 'GPUT', header.dutc(1, 1:4) = param;
            case 'GLUT', header.dutc(2, 1:4) = param;
            case 'GAUT', header.dutc(3, 1:4) = param;
            case 'BDUT', header.dutc(4, 1:4) = param;
            case 'QZUT', header.dutc(5, 1:4) = param;
            case 'IRUT', header.dutc(6, 1:4) = param;
            case 'SBUT', header.dutc(7, 1:4) = param;
        end
        
    elseif contains(line, 'LEAP SECONDS')
    elseif contains(line, 'END OF HEADER')
        break;
    end
end

% read the RINEX NAV body --------------------------------------------------------------------------
function [body] = readrnxnavb(buff, lim, header)

% check format version
switch fix(header.ver)
    case 2, v3 = false; % version 2.xx
    case 3, v3 = true;  % version 3.xx
    otherwise
        fprintf('readrnxnavb: invalid rinex version > %.2f', header.ver);
        body = [];
        return;
end

% skip the header lines
l = 0;
while l <= size(lim, 1)
    l = l + 1;
    line = buff(lim(l, 1):lim(l, 2));
    if contains(line, 'END OF HEADER')
        break;
    end
end

% find all the epoch lines
epline = find([...
    false(l, 1); ...
    (buff(lim(l + 1:end, 1) + 1 + v3) ~= ' ')'  & ...
    (buff(lim(l + 1:end, 1) + 2 + v3) == ' ')']);

% get number of ephemerides
neph = numel(epline);

% extract all epoch times
epoch = buff(repmat(lim(epline, 1), 1, 19) + repmat(3:21, neph, 1) + v3)';

if (v3)
    epoch = cell2mat(textscan(epoch, '%4f %2f %2f %2f %2f %2f'));
else
    % convert 2-digit year to 4-digit year
    epoch      = cell2mat(textscan(epoch, '%2f %2f %2f %2f %2f %5.1f'));
    epoch(:,1) = epoch(:,1) + 1900 + 100*(epoch(:,1) < 80);
end

% extract all satllite number with system
sats = buff(repmat(lim(epline, 1), 1, 2 + v3) + repmat(0:(1 + v3), neph, 1))';
sats(sats(:) == ' ') = '0';

if (v3)
    sys = double(sats(1,:))';
    prn = sscanf(sats(2:3,:), '%02d');
else
    sys = double(header.sys)*ones(neph, 1);
    prn = sscanf(sats, '%02d');
end

satid = [sys(:), prn(:)];

% extract all broadcast clock records
svclock = buff(repmat(lim(epline, 1), 1, 57) + repmat(22:78, neph, 1) + v3)';
svclock = cell2mat(textscan(svclock, '%19.12f %19.12f %19.12f'));

% create the empty data record
record0 = ['   ', repmat(' 0.000000000000D+00', 1, 4)];
if (v3)
    record0 = [' ', record0];
end

% initialize matrix containing broadcast orbit records
svorbit = NaN(neph, 28);

% loop over all ephemerides
for e = 1:neph
    % read 3 lines
    for o = 1:3
        record = record0;
        record(1:lim(epline(e) + o, 3) + 1) = ...
            buff((lim(epline(e) + o, 1):lim(epline(e) + o, 2)));
        
        % fill empty fields with zero
        record(record == 32) = record0(record == 32);
        
        % convert string to float
        svorbit(e, 4*o - 3:4*o) = ...
            cell2mat(textscan(record, '%19.12f %19.12f %19.12f %19.12f'));
    end
    
    % read additional 4 lines for GPS/Galileo/QZSS/BDS/IRNSS
    if sys(e) ~= 'R' && sys(e) ~= 'S'
        for o = 4:7
            record = record0;
            record(1:lim(epline(e) + o, 3) + 1) = ...
                buff((lim(epline(e) + o, 1):lim(epline(e) + o, 2)));
            
            % fill empty fields with zero
            record(record == 32) = record0(record == 32);
            
            % convert string to float
            svorbit(e, 4*o - 3:4*o) = ...
                cell2mat(textscan(record, '%19.12f %19.12f %19.12f %19.12f'));
        end
    end
end

% make output struct
body = struct('epoch', epoch, 'satid', satid, 'svclock', svclock, 'svorbit', svorbit);

% decode broadcast ephemeris -----------------------------------------------------------------------
function [eph] = decodeeph(header, body)

global const

% check satellite system
gps = body.satid(:,1) == 'G';
glo = body.satid(:,1) == 'R';
gal = body.satid(:,1) == 'E';
qzs = body.satid(:,1) == 'J';
bds = body.satid(:,1) == 'C';
irn = body.satid(:,1) == 'I';
sbs = body.satid(:,1) == 'S';

% convert epoch time (date/time) to week and time-of-week (Toc)
[week, tocs] = time2gpst(cal2time(body.epoch));

% restore the broadcast PRN for QZSS and SBAS satellites
body.satid(qzs, 2) = body.satid(qzs, 2) + const.PRN_QZS(1) - 1;
body.satid(sbs, 2) = body.satid(sbs, 2) + 100;

% convert satellite number with system to satellite index
sat      = NaN(size(body.satid, 1), 1);
sat(gps) = const.PRN2SAT_GPS(body.satid(gps, 2));
sat(glo) = const.PRN2SAT_GLO(body.satid(glo, 2));
sat(gal) = const.PRN2SAT_GAL(body.satid(gal, 2));
sat(qzs) = const.PRN2SAT_QZS(body.satid(qzs, 2) - const.PRN_QZS(1) + 1);
sat(bds) = const.PRN2SAT_BDS(body.satid(bds, 2));
sat(irn) = const.PRN2SAT_IRN(body.satid(irn, 2));
% sat(sbs) = const.PRN2SAT_SBS(body.satid(sbs, 2) - const.PRN_SBS(1) + 1);

% initialize matrix containing broasdcast ephemeris and clock parameters
eph = NaN(size(body.epoch, 1), 38);

% decode kepler ephemeris (GPS/Galileo/QZSS/BDS/IRNSS)
kepler = gps | gal | qzs | bds | irn;

if any(kepler)
    eph(kepler, 1)     = sat(kepler,:);
    eph(kepler, 2)     = tocs(kepler,:);
    eph(kepler, 3:5)   = body.svclock(kepler,:);
    eph(kepler, 6:end) = [body.svorbit(kepler, 1:end - 2), zeros(length(find(kepler)), 7)];
    
    % convert week and toc, toe, tom to UNIX time
    flag = gps | gal | qzs | irn;
    
    eph(flag, 32) = gpst2time(eph(flag, 24), eph(flag,  2)); % toc
    eph(flag, 33) = gpst2time(eph(flag, 24), eph(flag, 14)); % toe
    eph(flag, 34) = gpst2time(eph(flag, 24), eph(flag, 30)); % tom
    eph(bds, 32)  = bdt2time(eph(bds, 24), eph(bds,  2));    % toc
    eph(bds, 33)  = bdt2time(eph(bds, 24), eph(bds, 14));    % toe
    eph(bds, 34)  = bdt2time(eph(bds, 24), eph(bds, 30));    % tom
    
    % convert BDT to GPST
    eph(bds, 32) = eph(bds, 32) + 14;
    eph(bds, 33) = eph(bds, 33) + 14;
    eph(bds, 34) = eph(bds, 34) + 14;
    
    % adjust week handover
    eph(kepler, 33) = adjweek(eph(kepler, 33), eph(kepler, 32));
    eph(kepler, 34) = adjweek(eph(kepler, 34), eph(kepler, 32));
    
    % set fit interval
    eph(gps & eph(:,31) == 0, 31) = 4; % GPS
    eph(qzs & eph(:,31) == 0, 31) = 2; % QZSS
    eph(qzs & eph(:,31) == 1, 31) = 4; % QZSS
    
    % convert URA value to URA index
    eph(gps | qzs | bds | irn, 26) = uraindex(eph(gps | qzs | bds | irn, 26));
    eph(gal, 26) = sisaindex(eph(gal, 26));
end

% decode GLONASS ephemeris
if any(glo)
    eph(glo, 1)     = sat(glo,:);
    eph(glo, 2)     = tocs(glo,:);
    eph(glo, 3:5)   = body.svclock(glo,:);
    eph(glo, 3)     = -eph(glo, 3);
    eph(glo, 6:end) = [body.svorbit(glo, 1:end - 2), zeros(length(find(glo)), 7)];
    
    % satellite position, velocity and acceleration
    eph(glo, [6:8, 10:12, 14:16]) = eph(glo, [6:8, 10:12, 14:16])*1E3;
    
    % compute the Toc rounded by 15 min in UTC time
    toc = gpst2time(week(glo), floor((tocs(glo) + 450)/900)*900);
    dow = floor(tocs(glo)/86400);
    
    % compute time of frame in UTC time
    switch fix(header.ver)
        case 2
            tod = body.svclock(glo, 3);
        case 3
            tod = mod(body.svclock(glo, 3), 86400);
    end
    
    % convert UTC to GPST
    eph(glo, 32) = utc2gpst(toc); % toc
    eph(glo, 33) = utc2gpst(toc); % toe
    eph(glo, 34) = utc2gpst(adjday(gpst2time(week(glo), dow*86400 + tod), toc)); % message frame time
    
    % compute IODE = tb (7 bits), tb = index of UTC + 3H within current day
    eph(glo, 18) = floor((mod(tocs(glo) + 10800, 86400)/900.0) + 0.5);
end

% decode SBAS ephemeris
if any(sbs)
    eph(sbs, 1)       = sat(sbs,:);
    eph(sbs, 2)       = tocs(sbs,:);
    eph(sbs, 3:5)   = body.svclock(sbs,:);
    eph(sbs, 6:end) = [body.svorbit(sbs, 1:end - 2), zeros(length(find(sbs)), 7)];
    
    % satellite position, velocity and acceleration
    eph(sbs, [6:8, 10:12, 14:16]) = eph(sbs, [6:8, 10:12, 14:16])*1E3;
    
    % convert week and toc, toe, tom to UNIX time
    eph(sbs, 32) = gpst2time(week(sbs), tocs(sbs)); % toc
    eph(sbs, 33) = gpst2time(week(sbs), tocs(sbs)); % toe
    eph(sbs, 34) = gpst2time(week(sbs), body.svclock(sbs, 3)); % tom
    
    % adjust week handover
    eph(sbs, 33) = adjweek(eph(sbs, 33), eph(sbs, 32));
    eph(sbs, 34) = adjweek(eph(sbs, 34), eph(sbs, 32));
end

% adjust time considering week handover ------------------------------------------------------------
function [time1] = adjweek(time1, time2)

time1 = time1(:);
time2 = time2(:);

dt = time1 - time2;

time1(dt < -302400) = time1(dt < -302400) + 604800;
time1(dt >  302400) = time1(dt >  302400) - 604800;

% adjust time considering day handover -------------------------------------------------------------
function [time1] = adjday(time1, time2)

time1 = time1(:);
time2 = time2(:);

dt = time1 - time2;

time1(dt < -43200) = time1(dt < -43200) + 86400;
time1(dt >  43200) = time1(dt >  43200) - 86400;

% convert URA value to index -----------------------------------------------------------------------
function [idx] = uraindex(val)

global const

n    = size(val, 1);
dura = const.URA_EPH(ones(n, 1),:) - val;

idx  = NaN(n, 1);
for i = 1:n
    try
        idx(i) = find(dura(i,:) >= 0, 1);
    catch
        idx(i) = 16;
    end
end

% convert Galileo SISA value to index --------------------------------------------------------------
function [idx] = sisaindex(val)

idx = NaN(size(val, 1), 1);
idx(val >= 0.0 & val <= 0.5) = floor( val(val >= 0.0 & val <= 0.5)/0.01);
idx(val >  0.5 & val <= 1.0) = floor((val(val >  0.5 & val <= 1.0) - 0.5)/0.02) + 50;
idx(val >  1.0 & val <= 2.0) = floor((val(val >  1.0 & val <= 2.0) - 1.0)/0.04) + 75;
idx(val >  2.0 & val <= 6.0) = floor(floor((val(val > 2.0 & val <= 6.0) - 2.0))/0.16) + 100;
idx(val <  0.0 | val >  6.0) = 255; % unknown or NAPA

% sort broadcast ephemeris -------------------------------------------------------------------------
function out = sorteph(in)

global const

in  = sortrows(in, [1, 34, 33], 'descend');
out = cell(const.MAX_SAT, 1);
for i = 1:numel(out)
    out{i} = in(in(:,1) == i,:);
end