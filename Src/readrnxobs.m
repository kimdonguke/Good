function [obs, sta] = readrnxobs(files, opt)
% input:
%   files = RINEX observation data file to read
%     opt = RINEX observation code option
%
% output:
%   obs = observation data 
%       obs(:, 1)    = time
%       obs(:, 2)    = receiver number
%       obs(:, 3)    = satellite number
%       obs(:, 4: 8) = pseudorange [meters]
%       obs(:, 9:13) = carrier-phase [cycles]
%       obs(:,14:18) = doppler [Hz]
%       obs(:,19:23) = signal-to-noise ratio [dBHz]
%       obs(:,24:28) = loss-of-lock indicator
%       obs(:,29:33) = RINEX observation code
%   sta = station parameters
% 

if nargin < 2, opt = []; end

% check the input argument (char or string to cell)
if ischar(files) || ischar(files)
    files = {files};
end

% initialize outputs
obs = [];
sta = initsta(numel(files));

% loop over input files
for f = 1:numel(files)
    % get the file buffer
    [buff, lim] = getbuff(files{f});
    if isempty(buff), continue; end
    
%     fprintf('readrnxobs: reading rinex observation data file (rcv %02d) > %s\n', f, files{f});
    
    % read the file header
    [header, sta(f)] = readrnxobsh(buff, lim);
    if ~header.ver, continue; end
    
    % read the file body
    body = readrnxobsb(buff, lim, header);
    if isempty(body), continue; end
    
    % arrange observation data
    obs = [obs; arrangeobs(header, body, f, opt)]; %#ok<AGROW>
end

% sort observation data
obs = sortrows(obs, [1, 2, 3], 'ascend');

% get the file buffer and line information ---------------------------------------------------------
function [buff, lim] = getbuff(file)

% initialize outputs
buff = [];
lim  = [];

% open the file
fid = fopen(file, 'r');
if fid < 0
    fprintf('getbuff: rinex observation data file open error > %s\n', file);
    return;
end

% get file buffer and remove carriage return
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

% remove empty lines at the end of file
while (lim(end, 1) - lim(end - 1, 1)) < 2
    lim(end,:) = [];
end

if lim(end, 3) < 32
    buff = [buff repmat(' ', 1, 32 - lim(end, 3))];
end

% read the RINEX OBS header ------------------------------------------------------------------------
function [header, sta] = readrnxobsh(buff, lim)

header = struct('ver', 0, 'type', '', 'sys', '', 'obstype', {cell(7, 1)});
sta    = initsta(1);

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
        header.sys  = sscanf(line(41), '%c');
        
        if ~strcmpi(header.type, 'O')
            fprintf('readrnxobsh: invalid rinex file type > %s', header.type);
            header.ver = 0;
            return;
        end
        
        if ~ismember(header.sys, 'GREJCISM')
            fprintf('readrnxobsh: invalid rinex satellite system > %s', header.sys);
            header.ver = 0;
            return;
        end
        
    elseif contains(line, 'PGM / RUN BY / DATE')
    elseif contains(line, 'COMMENT')
    elseif contains(line, 'MARKER NAME')
        sta{1}.name = deblank(line(1:60));
        
    elseif contains(line, 'MARKER NUMBER')   
        sta{1}.marker = deblank(line(1:20));
        
    elseif contains(line, 'MARKER TYPE')
    elseif contains(line, 'OBSERVER / AGENCY')
    elseif contains(line, 'REC # / TYPE / VERS')
        sta{1}.recsno  = deblank(line( 1:20));
        sta{1}.rectype = deblank(line(21:40));
        sta{1}.recver  = deblank(line(41:60));
        
    elseif contains(line, 'ANT # / TYPE')
        sta{1}.antsno = deblank(line( 1:20));
        sta{1}.antdes = deblank(line(21:40));
        
    elseif contains(line, 'APPROX POSITION XYZ')
        sta{1}.pos = sscanf(line, '%f')';
        
    elseif contains(line, 'ANTENNA: DELTA H/E/N')
        del = sscanf(line, '%f')';
        sta{1}.del = [del(2), del(3), del(1)];
        
    elseif contains(line, 'WAVELENGTH FACT L1/2')
    elseif contains(line, '# / TYPES OF OBSERV')
        ntype = sscanf(line(1:6), '%d');
        for s = 1:7
            header.obstype{s} = cell(1, ntype);
        end
        
        syscodes = 'GREJCIS';
        for i = 1:ceil(ntype/9)
            if i > 1
                % read an additional line
                l = l + 1;
                line = buff(lim(l, 1):lim(l, 2));
            end
            
            for j = 1:min(ntype - 9*(i - 1), 9)
                for s = 1:7
                    header.obstype{s}{9*(i - 1) + j} = convcode(header.ver, syscodes(s), line((5:6) + 6*j));
                end
            end
        end
        
    elseif contains(line, 'SYS / # / OBS TYPES')
        sys = line(1);
        ntype = str2double(line(4:6));
        switch sys
            case 'G', s = 1; % GPS
            case 'R', s = 2; % GLONASS
            case 'E', s = 3; % Galileo
            case 'J', s = 4; % QZSS
            case 'C', s = 5; % BDS
            case 'I', s = 6; % IRNSS
            case 'S', s = 7; % SBAS
            otherwise
                fprintf('unknown satellite system identifier > %s', sys);
                header.ver = 0;
                return;
        end
        
        header.obstype{s} = cell(1, ntype);
        for i = 1:ceil(ntype/13)
            if i > 1
                % read an additional line
                l = l + 1;
                line = buff(lim(l, 1):lim(l, 2));
            end
            
            for j = 1:min(ntype - 13*(i - 1), 13)
                header.obstype{s}{13*(i - 1) + j} = line((4:6) + 4*j);
            end
        end
        
    elseif contains(line, 'INTERVAL')
    elseif contains(line, 'TIME OF FIRST OBS')
    elseif contains(line, 'TIME OF LAST OBS')
    elseif contains(line, 'RCV CLOCK OFFS APPL')
    elseif contains(line, 'SYS / DCBS APPLIED')
    elseif contains(line, 'SYS / PCVS APPLIED')
    elseif contains(line, 'SYS / SCALE FACTOR')
    elseif contains(line, 'SYS / PHASE SHIFT')
    elseif contains(line, 'GLONASS SLOT / FRQ #')
    elseif contains(line, 'GLONASS COD/PHS/BIS')
    elseif contains(line, 'LEAP SECONDS')
    elseif contains(line, '# OF SATELLITES')
    elseif contains(line, 'PRN / # OF OBS')
    elseif contains(line, 'END OF HEADER')
        break;
    end
end

% convert the RINEX observation type (version 2 -> version 3) --------------------------------------
function [type3] = convcode(ver, sys, type2)

type3 = repmat(' ', 1, 3);

if strcmp(type2, 'P1')
    if strcmp(sys, 'G')
        type3 = 'C1W';
    elseif strcmp(sys, 'R')
        type3 = 'C1P';
    end
    
elseif strcmp(type2, 'P2')
    if strcmp(sys, 'G')
        type3 = 'C2W';
    elseif strcmp(sys, 'R')
        type3 = 'C2P';
    end
    
elseif strcmp(type2, 'C1')
    if ver >= 2.12
        return;
    elseif strcmp(sys, 'G')
        type3 = 'C1C';
    elseif strcmp(sys, 'R')
        type3 = 'C1C';
    elseif strcmp(sys, 'E')
        type3 = 'C1X';
    elseif strcmp(sys, 'J')
        type3 = 'C1C';
    elseif strcmp(sys, 'S')
        type3 = 'C1C';
    end
    
elseif strcmp(type2, 'C2')
    if strcmp(sys, 'G')
        if ver >= 2.12
            type3 = 'C2W';
        else
            type3 = 'C2X';
        end
    elseif strcmp(sys, 'R')
        type3 = 'C2C';
    elseif strcmp(sys, 'J')
        type3 = 'C2X';
    elseif strcmp(sys, 'C')
        type3 = 'C2X';
    end
    
elseif ver >= 2.12 && type2(2) == 'A'
    if strcmp(sys, 'G')
        type3 = [type2(1), '1C'];
    elseif strcmp(sys, 'R')
        type3 = [type2(1), '1C'];
    elseif strcmp(sys, 'J')
        type3 = [type2(1), '1C'];
    elseif strcmp(sys, 'S')
        type3 = [type2(1), '1C'];
    end
    
elseif ver >= 2.12 && type2(2) == 'B'
    if strcmp(sys, 'G')
        type3 = [type2(1), '1X'];
    elseif strcmp(sys, 'J')
        type3 = [type2(1), '1X'];
    end
    
elseif ver >= 2.12 && type2(2) == 'C'
    if strcmp(sys, 'G')
        type3 = [type2(1), '2X'];
    elseif strcmp(sys, 'J')
        type3 = [type2(1), '2X'];
    end
elseif ver >= 2.12 && type2(2) == 'D'
    if strcmp(sys, 'R')
        type3 = [type2(1), '2C'];
    end
    
elseif ver >= 2.12 && type2(2) == '1'
    if strcmp(sys, 'G')
        type3 = [type2(1), '1W'];
    elseif strcmp(sys, 'R')
        type3 = [type2(1), '1P'];
    elseif strcmp(sys, 'E')
        type3 = [type2(1), '1X'];
    elseif strcmp(sys, 'C')
        type3 = [type2(1), '2X'];
    end
    
elseif type2(2) == '1'
    if strcmp(sys, 'G')
        type3 = [type2(1), '1C'];
    elseif strcmp(sys, 'R')
        type3 = [type2(1), '1C'];
    elseif strcmp(sys, 'E')
        type3 = [type2(1), '1X'];
    elseif strcmp(sys, 'J')
        type3 = [type2(1), '1C'];
    elseif strcmp(sys, 'S')
        type3 = [type2(1), '1C'];
    end
    
elseif type2(2) == '2'
    if strcmp(sys, 'G')
        type3 = [type2(1), '2W'];
    elseif strcmp(sys, 'R')
        type3 = [type2(1), '2P'];
    elseif strcmp(sys, 'J')
        type3 = [type2(1), '2X'];
    elseif strcmp(sys, 'C')
        type3 = [type2(1), '2X'];
    end
    
elseif type2(2) == '5'
    if strcmp(sys, 'G')
        type3 = [type2(1), '5X'];
    elseif strcmp(sys, 'E')
        type3 = [type2(1), '5X'];
    elseif strcmp(sys, 'J')
        type3 = [type2(1), '5X'];
    elseif strcmp(sys, 'S')
        type3 = [type2(1), '5X'];
    end
    
elseif type2(2) == '6'
    if strcmp(sys, 'E')
        type3 = [type2(1), '6X'];
    elseif strcmp(sys, 'J')
        type3 = [type2(1), '6X'];
    elseif strcmp(sys, 'C')
        type3 = [type2(1), '6X'];
    end
    
elseif type2(2) == '7'
    if strcmp(sys, 'E')
        type3 = [type2(1), '7X'];
    elseif strcmp(sys, 'C')
        type3 = [type2(1), '7X'];
    end
    
elseif type2(2) == '8'
    if strcmp(sys, 'E')
        type3 = [type2(1), '8X'];
    end
end

% read the RINEX OBS body --------------------------------------------------------------------------
function [body] = readrnxobsb(buff, lim, header)

% skip header lines
l = 0;
while l < size(lim, 1)
    l = l + 1;
    line = buff(lim(l, 1):lim(l, 2));
    if contains(line, 'END OF HEADER')
        break;
    end
end

% remove comment lines
cmtpos = repmat(lim(:,1), 1, 7) + repmat(60:66, size(lim, 1), 1);
idx = find(cmtpos(:,end) > numel(buff), 1, 'first');
if not(isempty(idx))
    cmtpos(idx:end,:) = [];
end

cmtline = sum(buff(cmtpos) == repmat('COMMENT', size(cmtpos, 1), 1), 2) == 7;
cmtline(1:l) = false; % keep header lines
lim(cmtline,:) = [];
if lim(end, 3) < 32
    buff = [buff, repmat(' ', 1, 32 - lim(end, 3))];
end

% parse EPOCH and OBSERVATION records
switch fix(header.ver)
    case 2 % version 2.xx
        % find all EPOCH record lines
        epline = find([...
            false(l, 1); ...
            (buff(lim(l + 1:end, 1) + 2) ~= ' ')'  & ...
            (buff(lim(l + 1:end, 1) + 3) == ' ')'  & ...
            (buff(lim(l + 1:end, 1) + 28) <= '1')' & ...
            lim(l + 1:end, 3) > 25]);
        
        % number of epochs
        nepoch = numel(epline);
        
        % extract all the epoch times
        eptime = buff(repmat(lim(epline, 1), 1, 25) + repmat(1:25, nepoch, 1))';
        eptime = cell2mat(textscan(eptime, '%2f %2f %2f %2f %2f %10.7f'));
        
        % convert 2-digit year to 4-digit year
        eptime(:,1) = eptime(:,1) + 1900 + 100*(eptime(:,1) < 80);
        
        % get the number of satellite per epoch
        nspe = sscanf(buff(repmat(lim(epline, 1), 1, 3) + repmat(29:31, nepoch, 1))', '%d');
        
        % get the number of observation types
        ntype = max(cellfun(@numel, header.obstype));
        
        % get the number of lines per satellite
        nlps = ceil(ntype/5);
        
        % create the empty OBSERVATION record
        record0 = repmat('         0.00000', 1, ntype);
        
        % set masks to extract observable, LLI and SSI
        % mask(1,:): observable (pseudorange, carrier-phase, doppler, SNR)
        % mask(2,:): loss of lock indicator (LLI)
        % mask(3,:): signal strength indicator (SSI) (currently not used)
        mask = [...
            repmat(logical([ true(1, 14), false, false]), 1, ntype); ...
            repmat(logical([false(1, 14),  true, false]), 1, ntype); ...
            repmat(logical([false(1, 14), false,  true]), 1, ntype)];
        
        % initialize matrices containing EPOCH and OBSERVATION records
        epoch = NaN(sum(nspe), 6);
        satid = NaN(sum(nspe), 2);
        obs   = NaN(sum(nspe), ntype);
        lli   = NaN(sum(nspe), ntype);
        
        % loop over all epochs
        nobs = 0;
        for e = 1:nepoch
            % get the number of satellites in current epoch
            nsat = nspe(e);
            
            % get the number of lines to read to parse the list of satellites
            n = ceil(nsat/12);
            
            % get the list of satellite IDs (satellite number with system ID)
            sats = buff(lim(epline(e) + (0:n - 1), 1) + repmat(32:67, n, 1))';
            sats = sats(:)';
            sats = sats(1:3*nsat);
            sats = reshape(sats, 3, nsat);
            sats(sats == 32) = '0';
            
            if ~strcmp(header.sys, 'M')
                sys = double(header.sys)*ones(nsat, 1);
            else
                sys = double(sats(1,:)');
            end
            
            prn = sscanf(sats(2:3,:), '%02d');
            
            % loop over all satellites in current epoch
            for s = 1:nsat
                j = epline(e) + n + (s - 1)*nlps;
                record = record0(1:16*ntype);
                for o = 0:nlps - 1
                    try
                        record(80*o + (1:lim(j + o, 3) + 1)) = buff(lim(j + o, 1):lim(j + o, 2));
                    catch
                        % empty last lines
                    end
                end
                
                % fill empty fields with zero
                record(record == 32) = record0(record == 32);
                
                % convert string to float
                obs(nobs + s,:)  = sscanf(record(mask(1,:)), '%f');
                lli(nobs + s,: ) = record(mask(2,:)) - 48; % fast conversion
                
                % receiver sampling time and satellite ID
                epoch(nobs + s,:) = eptime(e,:);
                satid(nobs + s,:) = [sys(s), prn(s)];
            end
            
            nobs = nobs + s;
        end
        
    case 3 % version 3.xx
        % fine all epoch record lines
        epline = find([...
            false(l, 1); ...
            (buff(lim(l + 1:end, 1)) == '>')']);
        
        % get the number of epochs
        nepoch = numel(epline);
        
        % get all the number of satellites
        nspe = sscanf(buff(repmat(lim(epline, 1), 1, 3) + repmat(32:34, nepoch, 1))', '%d');
        
        % get all the epoch time (date and time)
        eptime = buff(repmat(lim(epline, 1), 1, 27) + repmat(2:28, nepoch, 1))';
        eptime = cell2mat(textscan(eptime, '%4f %2f %2f %2f %2f %10.7f'));
        
        % get the number of observation types
        ntype = max(cellfun(@numel, header.obstype));
        
        % create the empty OBSERVATION record
        record0 = repmat('         0.00000', 1, ntype);
        
        % set masks to extract observable, LLI and SSI
        % mask(1,:): observable (pseudorange, carrier-phase, doppler, SNR)
        % mask(2,:): loss of lock indicator (LLI)
        % mask(3,:): signal strength indicator (SSI) (currently not used)
        mask = [...
            repmat(logical([ true(1, 14), false, false]), 1, ntype); ...
            repmat(logical([false(1, 14),  true, false]), 1, ntype); ...
            repmat(logical([false(1, 14), false,  true]), 1, ntype)];
        
        % initialize the struct containing EPOCH and OBSERVATION records
        epoch = NaN(sum(nspe), 6);
        satid = NaN(sum(nspe), 2);
        obs   = NaN(sum(nspe), ntype);
        lli   = NaN(sum(nspe), ntype);
        
        % loop over all epochs
        nobs = 0;
        for e = 1:nepoch
            for s = 1:nspe(e)
                line = buff(lim(epline(e) + s, 1):lim(epline(e) + s, 2));
                
                % get the satellite number and system
                sys = double(line(1));
                prn = sscanf(line(2:3), '%02d');
                
                % get the measurements, the LLI and SNR
                record = record0(1:16*ntype);
                record(1:length(line(4:end))) = line(4:end);
                
                % fill empty fields with zero
                record(record == 32) = record0(record == 32);
                
                % convert string to float
                obs(nobs + s,:) = sscanf(record(mask(1,:)), '%f');
                lli(nobs + s,:) = record(mask(2,:)) - 48; % fast conversion
                
                % receiver sampling time and satellite ID
                epoch(nobs + s,:) = eptime(e,:);
                satid(nobs + s,:) = [sys, prn];
            end
            
            nobs = nobs + s;
        end
    otherwise
        fprintf('readrnxobsb: invalid rinex version > %.2f', header.ver);
        body = [];
        return;
end

% make output struct
body = struct('epoch', epoch, 'satid', satid, 'obs', obs, 'lli', lli);

% arrange observation data by types ----------------------------------------------------------------
function [obs] = arrangeobs(header, body, rcv, opt)

global const

% default RINEX observation code priority
% original
% freqs{1} = '125';   % GPS
% freqs{2} = '123';   % GLONASS
% freqs{3} = '17658'; % Galileo
% freqs{4} = '1256';  % QZSS
% freqs{5} = '276';   % BeiDou-2
% freqs{6} = '17658'; % BeiDou-3
% freqs{7} = '59';    % IRNSS
% freqs{8} = '15';    % SBAS

% edit
% freqs{1} = '125';   % GPS
% freqs{2} = '123';   % GLONASS
% freqs{3} = '17658'; % Galileo
% freqs{4} = '1256';  % QZSS
% freqs{5} = '12758'; % BeiDou-2
% freqs{6} = '12758'; % BeiDou-3
% freqs{7} = '59';    % IRNSS
% freqs{8} = '15';    % SBAS

% edit-241023
freqs{1} = '125';   % GPS
freqs{2} = '123';   % GLONASS
freqs{3} = '175'; % Galileo
freqs{4} = '1256';  % QZSS
freqs{5} = '12'; % BeiDou-2
freqs{6} = '125'; % BeiDou-3
freqs{7} = '59';    % IRNSS
freqs{8} = '15';    % SBAS

attrs{1} = {'CPYWMNSLX', 'PYWCMNDLSX', 'IQX'};
attrs{2} = {'CP', 'PC', 'IQX'};
attrs{3} = {'CABXZ', 'IQX', 'ABCXZ', 'IQX', 'IQX'};
attrs{4} = {'CSLXZ', 'LSX', 'IQXDPZ', 'LSXEZ'};
attrs{5} = {'IQX', 'IQX', 'IQXA'};
attrs{6} = {'IDPX', 'IDPZ', 'IQXA', 'IDPX', 'IDPX'};
attrs{7} = {'ABCX', 'ABCX'};
attrs{8} = {'C', 'IQX'};

% set the observation code priority by opt
if ~isempty(opt)
    opt = split(opt, ':');
    for k = 1:numel(opt)
        optk = opt{k};
        j = strfind(optk, '-');
        if isempty(j) || ~j || j >= length(optk), continue; end
        tmp = optk(j+1:end);
        if isempty(tmp), continue; end
        if     contains(optk, 'GPS' ), i = 1; 
        elseif contains(optk, 'GLO' ), i = 2;
        elseif contains(optk, 'GAL' ), i = 3;
        elseif contains(optk, 'QZS' ), i = 4;
        elseif contains(optk, 'BDS2'), i = 5;
        elseif contains(optk, 'BDS3'), i = 6;
        elseif contains(optk, 'IRN' ), i = 7;
        elseif contains(optk, 'SBS' ), i = 8;
        else,  continue;
        end
        
        selected = ismember(freqs{i}, tmp);
        freqs{i} = freqs{i}(selected);
        attrs{i} = attrs{i}(selected);
    end
end


% remove duplicated observation data
[~, idx] = unique([body.epoch, body.satid], 'rows');

body.epoch = body.epoch(idx,:);
body.satid = body.satid(idx,:);
body.obs   = body.obs(idx,:);
body.lli   = body.lli(idx,:);

% check the satellite system
gps = body.satid(:,1) == 'G';
glo = body.satid(:,1) == 'R';
gal = body.satid(:,1) == 'E';
qzs = body.satid(:,1) == 'J';
bds = body.satid(:,1) == 'C';
irn = body.satid(:,1) == 'I';
sbs = body.satid(:,1) == 'S';

% restore the broadcast PRN for QZSS and SBAS satellites
body.satid(qzs, 2) = body.satid(qzs, 2) + const.PRN_QZS(1) - 1;
body.satid(sbs, 2) = body.satid(sbs, 2) + 100;

% convert the satellite number with system identifier to satellite index
sat      = NaN(size(body.satid, 1), 1);
sat(gps) = const.PRN2SAT_GPS(body.satid(gps, 2));
sat(glo) = const.PRN2SAT_GLO(body.satid(glo, 2));
sat(gal) = const.PRN2SAT_GAL(body.satid(gal, 2));
sat(qzs) = const.PRN2SAT_QZS(body.satid(qzs, 2) - const.PRN_QZS(1) + 1);
sat(bds) = const.PRN2SAT_BDS(body.satid(bds, 2));
sat(irn) = const.PRN2SAT_IRN(body.satid(irn, 2));
sat(sbs) = const.PRN2SAT_SBS(body.satid(sbs, 2) - const.PRN_SBS(1) + 1);

% convert the epoch time (date/time) to time
time = cal2time(body.epoch);

% arrange the observation data
obs = NaN(length(time), 33);
obs(:,1) = time;
obs(:,2) = rcv;
obs(:,3) = sat;

% GPS
freq = freqs{1}; attr = attrs{1};
% freq = '125';
% attr = {'CPYWMNSLX', 'PYWCMNDLSX', 'IQX'};
for f = 1:length(freq)
    for a = attr{f}
        idx_pr  = find(strcmp(header.obstype{const.SYS_GPS}, ['C', freq(f), a]), 1);
        idx_cp  = find(strcmp(header.obstype{const.SYS_GPS}, ['L', freq(f), a]), 1);
        idx_dp  = find(strcmp(header.obstype{const.SYS_GPS}, ['D', freq(f), a]), 1);
        idx_snr = find(strcmp(header.obstype{const.SYS_GPS}, ['S', freq(f), a]), 1);
        
        if (~isempty(idx_pr) && ~isempty(idx_cp))
            obs(gps,  3 + f) = body.obs(gps, idx_pr);               % pseudorange
            obs(gps,  8 + f) = body.obs(gps, idx_cp);               % carrier-phase
            obs(gps, 23 + f) = bitand(body.lli(gps, idx_cp), 3);    % LLI
            obs(gps, 28 + f) = str2code(['L', freq(f), a]);         % observation code
            
            if (~isempty(idx_dp))
                obs(gps, 13 + f) = body.obs(gps, idx_dp); % doppler              
            end
            
            if (~isempty(idx_snr))
                obs(gps, 18 + f) = body.obs(gps, idx_snr); % SNR
            end
            
            break;
        end
    end
end

% GLONASS
freq = freqs{2}; attr = attrs{2};
% freq = '123';
% attr = {'CP', 'PC', 'IQX'};
for f = 1:length(freq)
    for a = attr{f}
        idx_pr  = find(strcmp(header.obstype{const.SYS_GLO}, ['C', freq(f), a]), 1);
        idx_cp  = find(strcmp(header.obstype{const.SYS_GLO}, ['L', freq(f), a]), 1);
        idx_dp  = find(strcmp(header.obstype{const.SYS_GLO}, ['D', freq(f), a]), 1);
        idx_snr = find(strcmp(header.obstype{const.SYS_GLO}, ['S', freq(f), a]), 1);
        
        if (~isempty(idx_pr) && ~isempty(idx_cp))
            obs(glo,  3 + f) = body.obs(glo, idx_pr);               % pseudorange
            obs(glo,  8 + f) = body.obs(glo, idx_cp);               % carrier-phase
            obs(glo, 23 + f) = bitand(body.lli(glo, idx_cp), 3);    % LLI
            obs(glo, 28 + f) = str2code(['L', freq(f), a]);         % observation code
            
            if (~isempty(idx_dp))
                obs(glo, 13 + f) = body.obs(glo, idx_dp); % doppler
            end
            
            if (~isempty(idx_snr))
                obs(glo, 18 + f) = body.obs(glo, idx_snr); % SNR
            end
            
            break;
        end
    end
end

% Galileo
freq = freqs{3}; attr = attrs{3};
% freq = '17658'; % origin
% attr = {'CABXZ', 'IQX', 'ABCXZ', 'IQX', 'IQX'};
% freq = '18657'; % modified for NGII data processing
% attr = {'CABXZ', 'IQX', 'ABCXZ', 'IQX', 'IQX'};
for f = 1:length(freq)
    for a = attr{f}
        idx_pr  = find(strcmp(header.obstype{const.SYS_GAL}, ['C', freq(f), a]), 1);
        idx_cp  = find(strcmp(header.obstype{const.SYS_GAL}, ['L', freq(f), a]), 1);
        idx_dp  = find(strcmp(header.obstype{const.SYS_GAL}, ['D', freq(f), a]), 1);
        idx_snr = find(strcmp(header.obstype{const.SYS_GAL}, ['S', freq(f), a]), 1);
        
        if (~isempty(idx_pr) && ~isempty(idx_cp))
            obs(gal,  3 + f) = body.obs(gal, idx_pr);               % pseudorange
            obs(gal,  8 + f) = body.obs(gal, idx_cp);               % carrier-phase
            obs(gal, 23 + f) = bitand(body.lli(gal, idx_cp), 3);    % LLI
            obs(gal, 28 + f) = str2code(['L', freq(f), a]);         % observation code
            
            if (~isempty(idx_dp))
                obs(gal, 13 + f) = body.obs(gal, idx_dp); % doppler
            end
            
            if (~isempty(idx_snr))
                obs(gal, 18 + f) = body.obs(gal, idx_snr); % SNR
            end
            
            break;
        end
    end
end

% QZSS
freq = freqs{4}; attr = attrs{4};
% freq = '1256';
% attr = {'CSLXZ', 'LSX', 'IQXDPZ', 'LSXEZ'};
for f = 1:length(freq)
    for a = attr{f}
        idx_pr  = find(strcmp(header.obstype{const.SYS_QZS}, ['C', freq(f), a]), 1);
        idx_cp  = find(strcmp(header.obstype{const.SYS_QZS}, ['L', freq(f), a]), 1);
        idx_dp  = find(strcmp(header.obstype{const.SYS_QZS}, ['D', freq(f), a]), 1);
        idx_snr = find(strcmp(header.obstype{const.SYS_QZS}, ['S', freq(f), a]), 1);
        
        if (~isempty(idx_pr) && ~isempty(idx_cp))
            obs(qzs,  3 + f) = body.obs(qzs, idx_pr);               % pseudorange
            obs(qzs,  8 + f) = body.obs(qzs, idx_cp);               % carrier-phase
            obs(qzs, 23 + f) = bitand(body.lli(qzs, idx_cp), 3);    % LLI
            obs(qzs, 28 + f) = str2code(['L', freq(f), a]);         % observation code
            
            if (~isempty(idx_dp))
                obs(qzs, 13 + f) = body.obs(qzs, idx_dp); % doppler
            end
            
            if (~isempty(idx_snr))
                obs(qzs, 18 + f) = body.obs(qzs, idx_snr); % SNR
            end
            
            break;
        end
    end
end

% BDS
% change BDS B1 to B2 (RINEX v3.02 only)
if (header.ver == 3.02)
    for i = 1:numel(header.obstype{const.SYS_BDS})
        if header.obstype{const.SYS_BDS}{i}(2) == '1'
            header.obstype{const.SYS_BDS}{i}(2) = '2';
        end
    end
end

% BDS-2
freq = freqs{5}; attr = attrs{5};
bds2 = bds & ismember(body.satid(:,2), 1:16);
% freq = '276';
% attr = {'IQX', 'IQX', 'IQXA'};
for f = 1:length(freq)
    for a = attr{f}
        idx_pr  = find(strcmp(header.obstype{const.SYS_BDS}, ['C', freq(f), a]), 1);
        idx_cp  = find(strcmp(header.obstype{const.SYS_BDS}, ['L', freq(f), a]), 1);
        idx_dp  = find(strcmp(header.obstype{const.SYS_BDS}, ['D', freq(f), a]), 1);
        idx_snr = find(strcmp(header.obstype{const.SYS_BDS}, ['S', freq(f), a]), 1);
        
        if (~isempty(idx_pr) && ~isempty(idx_cp))
            obs(bds2,  3 + f) = body.obs(bds2, idx_pr);               % pseudorange
            obs(bds2,  8 + f) = body.obs(bds2, idx_cp);               % carrier-phase
            obs(bds2, 23 + f) = bitand(body.lli(bds2, idx_cp), 3);    % LLI
            obs(bds2, 28 + f) = str2code(['L', freq(f), a]);         % observation code
            
            if (~isempty(idx_dp))
                obs(bds2, 13 + f) = body.obs(bds2, idx_dp); % doppler
            end
            
            if (~isempty(idx_snr))
                obs(bds2, 18 + f) = body.obs(bds2, idx_snr); % SNR
            end
            break;
        end
    end
end

% BDS-3

%% original
freq = freqs{6}; attr = attrs{6};
bds3 = bds & ismember(body.satid(:,2), [19:46, 56:61]);
% freq = '17658';
% attr = {'DPX', 'DPZ', 'IQXA', 'DPX', 'DPX'};

%% edit
% freq = '2';
% bds3 = bds & ismember(body.satid(:,2), [19:46, 56:61]);
% attr = {'IQX', 'IQX', 'IQX', 'IQX', 'IQX'};

for f = 1:length(freq)
    for a = attr{f}
        idx_pr  = find(strcmp(header.obstype{const.SYS_BDS}, ['C', freq(f), a]), 1);
        idx_cp  = find(strcmp(header.obstype{const.SYS_BDS}, ['L', freq(f), a]), 1);
        idx_dp  = find(strcmp(header.obstype{const.SYS_BDS}, ['D', freq(f), a]), 1);
        idx_snr = find(strcmp(header.obstype{const.SYS_BDS}, ['S', freq(f), a]), 1);
        
        if (~isempty(idx_pr) && ~isempty(idx_cp))
            obs(bds3,  3 + f) = body.obs(bds3, idx_pr);               % pseudorange
            obs(bds3,  8 + f) = body.obs(bds3, idx_cp);               % carrier-phase
            obs(bds3, 23 + f) = bitand(body.lli(bds3, idx_cp), 3);    % LLI
            obs(bds3, 28 + f) = str2code(['L', freq(f), a]);         % observation code
            
            if (~isempty(idx_dp))
                obs(bds3, 13 + f) = body.obs(bds3, idx_dp); % doppler
            end
            
            if (~isempty(idx_snr))
                obs(bds3, 18 + f) = body.obs(bds3, idx_snr); % SNR
            end
            break;
        end
    end
end

% IRNSS
freq = freqs{7}; attr = attrs{7};
% freq = '59';
% attr = {'ABCX', 'ABCX'};
for f = 1:length(freq)
    for a = attr{f}
        idx_pr  = find(strcmp(header.obstype{const.SYS_IRN}, ['C', freq(f), a]), 1);
        idx_cp  = find(strcmp(header.obstype{const.SYS_IRN}, ['L', freq(f), a]), 1);
        idx_dp  = find(strcmp(header.obstype{const.SYS_IRN}, ['D', freq(f), a]), 1);
        idx_snr = find(strcmp(header.obstype{const.SYS_IRN}, ['S', freq(f), a]), 1);
        
        if (~isempty(idx_pr) && ~isempty(idx_cp))
            obs(irn,  3 + f) = body.obs(irn, idx_pr);               % pseudorange
            obs(irn,  8 + f) = body.obs(irn, idx_cp);               % carrier-phase
            obs(irn, 23 + f) = bitand(body.lli(irn, idx_cp), 3);    % LLI
            obs(irn, 28 + f) = str2code(['L', freq(f), a]);         % observation code
            
            if (~isempty(idx_dp))
                obs(irn, 13 + f) = body.obs(irn, idx_dp); % doppler
            end
            
            if (~isempty(idx_snr))
                obs(irn, 18 + f) = body.obs(irn, idx_snr); % SNR
            end
            
            break;
        end
    end
end

% SBAS
freq = freqs{8}; attr = attrs{8};
% freq = '15';
% attr = {'C', 'IQX'};
for f = 1:length(freq)
    for a = attr{f}
        idx_pr  = find(strcmp(header.obstype{const.SYS_SBS}, ['C', freq(f), a]), 1);
        idx_cp  = find(strcmp(header.obstype{const.SYS_SBS}, ['L', freq(f), a]), 1);
        idx_dp  = find(strcmp(header.obstype{const.SYS_SBS}, ['D', freq(f), a]), 1);
        idx_snr = find(strcmp(header.obstype{const.SYS_SBS}, ['S', freq(f), a]), 1);
        
        if (~isempty(idx_pr) && ~isempty(idx_cp))
            obs(sbs,  3 + f) = body.obs(sbs, idx_pr);               % pseudorange
            obs(sbs,  8 + f) = body.obs(sbs, idx_cp);               % carrier-phase
            obs(sbs, 23 + f) = bitand(body.lli(sbs, idx_cp), 3);    % LLI
            obs(sbs, 28 + f) = str2code(['L', freq(f), a]);         % observation code
            
            if (~isempty(idx_dp))
                obs(sbs, 13 + f) = body.obs(sbs, idx_dp); % doppler
            end
            
            if (~isempty(idx_snr))
                obs(sbs, 18 + f) = body.obs(sbs, idx_snr); % SNR
            end
            
            break;
        end
    end
end

% set NaN to zeros
obs(isnan(obs)) = 0;