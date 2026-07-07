function [pcv] = readatx(file)

global const

% check the input argument (cell -> char)
if iscell(file)
    file = file{1};
end

% get the file buffer and line information
[buff, lim] = getbuff(file);
if isempty(buff), pcv = {}; return; end

fprintf('readatx: reading antex file > %s\n', file);

% remove comment line
cmtline = (buff((lim(:,1) + 60)) == 'C')';
rmline  = lim(:,3) < 63;
lim(cmtline | rmline,:) = [];

% frequency to index
freq2idx{const.SYS_GPS} = [1, 2, 0, 0, 3];             % GPS
freq2idx{const.SYS_GLO} = [1, 2, 3, 1, 0, 2];          % GLONASS
freq2idx{const.SYS_GAL} = [1, 0, 0, 0, 3, 4, 2, 5];    % Galileo
freq2idx{const.SYS_QZS} = [1, 2, 0, 0, 3, 4];          % QZSS
freq2idx{const.SYS_BDS} = [1, 1, 0, 0, 3, 4, 2, 5];    % BDS
freq2idx{const.SYS_IRN} = [0, 0, 0, 0, 1, 0, 0, 0, 2]; % IRNSS
freq2idx{const.SYS_SBS} = [1, 0, 0, 0, 2];             % SBAS

% initialization
nant = numel(find((buff((lim(:,1) + 60)) == 'T') & (buff((lim(:,1) + 67)) == 'S')));
pcv = initpcv(nant);

% loop over all lines
l = 0;
n = 0;
start = 0;
freq  = 0;
idx   = 0;
while l < size(lim, 1)
    % read a line
    l = l + 1;
    line = buff(lim(l, 1):lim(l, 2));
    
    if contains(line, 'START OF ANTENNA')
        n = n + 1;
        start = 1;
    end
    
    if contains(line, 'END OF ANTENNA')
        start = 0;
    end
    
    if ~start, continue; end
    
    if contains(line, 'TYPE / SERIAL NO')
        pcv{n}.type = deblank(line( 1:20));
        pcv{n}.code = deblank(line(21:40));
        
        if ~isempty(pcv{n}.code) % satellite antenna
            sys = pcv{n}.code(1);
            prn = sscanf(pcv{n}.code(2:3), '%d') + 192*(sys == 'J') + 100*(sys == 'S');
            
            if sys == 'G' && ~ismember(prn, const.PRN_GPS), start = 0; end
            if sys == 'R' && ~ismember(prn, const.PRN_GLO), start = 0; end
            if sys == 'E' && ~ismember(prn, const.PRN_GAL), start = 0; end
            if sys == 'J' && ~ismember(prn, const.PRN_QZS), start = 0; end
            if sys == 'C' && ~ismember(prn, const.PRN_BDS), start = 0; end
            if sys == 'I' && ~ismember(prn, const.PRN_IRN), start = 0; end
            if sys == 'S' && ~ismember(prn, const.PRN_SBS), start = 0; end
            
            if start
                switch sys
                    case 'G', pcv{n}.sat = const.PRN2SAT_GPS(prn);
                    case 'R', pcv{n}.sat = const.PRN2SAT_GLO(prn);
                    case 'E', pcv{n}.sat = const.PRN2SAT_GAL(prn);
                    case 'J', pcv{n}.sat = const.PRN2SAT_QZS(prn - const.PRN_QZS(1) + 1);
                    case 'C', pcv{n}.sat = const.PRN2SAT_BDS(prn);
                    case 'I', pcv{n}.sat = const.PRN2SAT_IRN(prn);
                    case 'S', pcv{n}.sat = const.PRN2SAT_SBS(prn - const.PRN_SBS(1) + 1);
                    otherwise
                        start = 0;
                        continue;
                end
            else
                pcv{n}.sat = NaN;
                continue;
            end
        else % receiver antenna
            pcv{n}.sat = 0;
        end
        
    elseif contains(line, 'DAZI')        
    elseif contains(line, 'ZEN1 / ZEN2 / DZEN')
        zen1 = sscanf(line( 3: 8), '%f');
        zen2 = sscanf(line( 9:14), '%f');
        dzen = sscanf(line(15:20), '%f');
        
    elseif contains(line, 'VALID FROM')
        pcv{n}.ts = cal2time(cell2mat(textscan(line(1:43), '%f %f %f %f %f %f')));
        
    elseif contains(line, 'VALID UNTIL')
        pcv{n}.te = cal2time(cell2mat(textscan(line(1:43), '%f %f %f %f %f %f')));
        
    elseif contains(line, 'START OF FREQUENCY')
        sys  = line(4);
        freq = sscanf(line(5:6), '%f');
        if freq
            switch sys
                case 'G', idx = freq2idx{const.SYS_GPS}(freq);
                case 'R', idx = freq2idx{const.SYS_GLO}(freq);
                case 'E', idx = freq2idx{const.SYS_GAL}(freq);
                case 'J', idx = freq2idx{const.SYS_QZS}(freq);
                case 'C', idx = freq2idx{const.SYS_BDS}(freq);
                case 'I', idx = freq2idx{const.SYS_IRN}(freq);
                case 'S', idx = freq2idx{const.SYS_SBS}(freq);
                otherwise
                    start = 0;
                    freq  = 0;
                    idx   = 0;
                    continue;
            end
        end
        
    elseif contains(line, 'NORTH / EAST / UP')
        off = cell2mat(textscan(line(1:30), '%f %f %f'))*1E-3;
        if length(off) ~= 3, start = 0; end
        if freq && idx
            if isempty(pcv{n}.code) % receiver antenna
                % n/e/u -> e/n/u
                if (strcmp(sys, 'G')) % read only antenna parameters for GPS
                    pcv{n}.off(1:3, idx) = [off(2), off(1), off(3)];
                else
                    if (any(isnan(pcv{n}.off(1:3, idx))))
                        pcv{n}.off(1:3, idx) = [off(2), off(1), off(3)];
                    end
                end
            else % satellite antenna
                % x/y/z
                pcv{n}.off(1:3, idx) = off;
            end
        end
        
    elseif contains(line, 'NOAZI') && dzen
        nvar = length(zen1:dzen:zen2);
        if length(line) < (nvar*8) + 8
            continue;
        else
            % read only non-azimuth dependent parameters
            if sys == 'G'
                var = sscanf(line(9:(nvar*8) + 8), '%f')'*1E-3;
                if (length(var) ~= nvar)
                    continue;
                end

                if (freq && idx)
                    pcv{n}.var(1:length(var), idx) = var;
                end
            end
        end
        
    elseif contains(line, 'END OF FREQUENCY')
        freq = 0;
        idx  = 0;
    end
end

% use L2 parameters if no PCV data for L3, L4, L5
for p = 1:nant
    for f = 3:5
        if (any(isnan(pcv{p}.off(1:3, f))))
            pcv{p}.off(1: 3, f) = pcv{p}.off(1: 3, 2);
            pcv{p}.var(1:19, f) = pcv{p}.var(1:19, 2);
        end
    end
end

% remove invalid antenna parameters
idx = cellfun(@(c) isempty(c.type), pcv) | cellfun(@(c) isnan(c.sat), pcv);
pcv(idx) = [];

% get the file buffer and line information ---------------------------------------------------------
function [buff, lim] = getbuff(file)

% initialize outputs
buff = [];
lim  = [];

% open the file
fid = fopen(file, 'r');
if fid < 0
    fprintf('getbuff: antex file open error > %s\n', file);
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