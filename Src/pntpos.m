function [sol, stat] = pntpos(obs, nav, opt)
% ==================================================================================================
% PNTPOS
%   compute receiver position, velocity and clock bias by point positioning with pseudorange and
%   doppler observables
% ==================================================================================================

global const
persistent sol0
if isempty(sol0), sol0 = initsol(1); end

sol = sol0;
sol.stat = const.SOLQ_NONE;
if size(obs, 1) <= 0
    disp('no observation data'); stat = 0; return;
end

sol.time = obs(1, 1);

% compute satellite position and clock error
[rs, dts, vareph, svh, tgd] = satposclk(obs, nav);

% estimate receiver position and clock error with pseudorange
[sol, vsat, resp, stat, azel] = estpos(sol, obs, nav, rs, dts, tgd, svh, vareph, opt);

% estimate receiver velocity with doppler
if (stat)
    sol = estvel(sol, obs, nav, rs, dts, vsat, azel, opt);
end

% estimate receiver position and clock bias --------------------------------------------------------
function [sol, vsat, resp, stat, azel] = estpos(sol, obs, nav, rs, dts, tgd, svh, vareph, opt)

global const
persistent x
if isempty(x), x = zeros(1, 8); end

% number of estimated parameters
if (true) % disable GPS-QZS time offset estimation
    nx = 4 + 4;
else % enable GPS-QZS time offset estimation
    nx = 4 + 5; %#ok<UNRCH>
end

% initial position and clock error
x(4:end) = zeros(1, 5);
if any(isnan(x)), x = zeros(1, 8); end

% least square iteration
for i = 1:const.MAX_ITER_LSQ
    % compute pseudorange residuals
    [v, var, H, azel, vsat, resp] = rescode(obs, nav, rs, dts, tgd, vareph, svh, x, opt);
    if length(v) < nx
        sol.stat = const.SOLQ_NONE; stat = 0;
        disp('estpos: lack of valid sats'); break;
    end
    
    % least square estimation
    [dx, Q] = lsq(v, H, diag(1./var));
    
    % update initial position and clock bias with least square solution
    x = x + dx';
    
    if (norm(dx) < 1E-4)
        sat = obs(vsat, 3);
        
        sol.type       = 0;
        sol.time       = obs(1, 1) - x(3)/const.C_LIGHT;
        sol.rr(1:3)    = x(1:3);
        sol.rr(4:6)    = zeros(1, 3);
        sol.dtr(1:5)   = x(4:8)/const.C_LIGHT;
        sol.qr(1:3)    = diag(Q(1:3, 1:3));
        sol.qr(4:6)    = [Q(1,2), Q(2,3), Q(3,1)];
        sol.sataz(sat) = azel(vsat, 1);
        sol.satel(sat) = azel(vsat, 2);
        sol.nsat       = length(find(v ~= 0 & ~isnan(v)));
        sol.ratio      = 0;
        sol.age        = 0;

        % validate solution (Chi-square test)
        stat = valsol(azel(vsat,:), v./sqrt(var), nx, opt);
        if (stat), sol.stat = const.SOLQ_SINGLE; end
        break;
    end
end

if (i >= const.MAX_ITER_LSQ)
    sol.stat = const.SOLQ_NONE; stat = 0;
    disp('estpos: least square iteration divergent');
end

% compute pseudorange residuals --------------------------------------------------------------------
function [v, var, H, azel, vsat, resp] = rescode(obs, nav, rs, dts, tgd, veph, svh, x, opt)

global const

sat  = obs(:,3);
sys  = sat2prn(sat);
nsat = length(sat(:));
time = obs(1, 1);

% receiver position and clock error
rr  = x(1:3);
dtr = x(4:8);

% convert ECEF position to geodetic position
llh = xyz2llh(rr);

% compute geometric distance and line of sight
[r, e] = geodist(rs(:,1:3), rr);

% compute azimuth and elevation angle
azel = satazel(rs(:,1:3), rr);

% compute ionospheric correction
[diono, viono] = ionocorr(time, nav, llh, azel, opt.iono);

freq  = code2freq(sat, obs(:,29));
diono = diono.*(const.FREQ_L1./freq).^2;
viono = viono.*(const.FREQ_L1./freq).^2;

% compute tropospheric correction
[dtropo, vtropo] = tropocorr(time, llh, azel, opt.tropo);

% get pseudorange with code bias correction
[P, vcode] = prange(obs, nav, tgd, opt);

% compute pseudorange residual
v = P - (r + dtr(1) - const.C_LIGHT*dts(:,1) + diono + dtropo);

% receiver clock offset and GNSS time system off correction
gps = sys == 'G';
glo = sys == 'R';
gal = sys == 'E';
qzs = sys == 'J';
bds = sys == 'C';
irn = sys == 'I';

v(glo) = v(glo) - dtr(2); % GPS-GLO time offset
v(gal) = v(gal) - dtr(3); % GPS-GAL time offset
v(bds) = v(bds) - dtr(4); % GPS-BDS time offset
v(irn) = v(irn) - dtr(5); % GPS-IRN time offset

% build design matrix (observation matrix)
H = zeros(size(obs, 1), 8);
H(:,1:3) = -e;

H(gps, 4) = 1; % GPS
H(glo, 5) = 1; % GPS-GAL
H(gal, 6) = 1; % GPS-GAL
H(qzs, 4) = 1; % QZS (GPS)
H(bds, 7) = 1; % GPS-BDS
H(irn, 8) = 1; % GPS-IRN

% variance of pseudorange error
var = varmeas(azel(:,2), sys, opt) + veph + vcode + viono + vtropo;

% test elevation mask and excluded satellite
valid = azel(:,2) >= opt.elmask & testsat(sat, veph, svh, opt);
valid = valid & (~isnan(v) & v ~= 0);

v    = v(valid,:);
var  = var(valid,:);
H    = H(valid,:);

% valid satellite flag and code residual
vsat = false(nsat, 1);
resp = NaN(nsat, 1);

vsat(valid) = true;
resp(valid) = v;

% constraint to avoid rank-deficient
if ~any(gps(valid))
    v   = [v; 0];
    var = [var; 0.01];
    H   = [H; zeros(1, 3), 1, zeros(1, 4)];
end

if ~any(glo(valid))
    v   = [v; 0];
    var = [var; 0.01];
    H   = [H; zeros(1, 4), 1, 0, 0, 0];
end

if ~any(gal(valid))
    v   = [v; 0];
    var = [var; 0.01];
    H   = [H; zeros(1, 4), 0, 1, 0, 0];
end

if ~any(bds(valid))
    v   = [v; 0];
    var = [var; 0.01];
    H   = [H; zeros(1, 4), 0, 0, 1, 0];
end

if ~any(irn(valid))
    v   = [v; 0];
    var = [var; 0.01];
    H   = [H; zeros(1, 4), 0, 0, 0, 1];
end

% pseudorange with code bias correction ------------------------------------------------------------
function [pr, var] = prange(obs, nav, tgd, opt)

global const

sat  = obs(:,3);
sys  = sat2prn(sat);
code = obs(:,29:33);
nsat = length(sys);

% check satellite system
gps = sys == 'G';
glo = sys == 'R';
gal = sys == 'E';
qzs = sys == 'J';
bds = sys == 'C';
irn = sys == 'I';

% P1-C1, P2-C2 DCB correction
% TBD

% pseudorange measurement with code bias correction
P1 = obs(:,4); % L1
P2 = obs(:,5); % L2
P1(P1 == 0) = NaN;
P2(P2 == 0) = NaN;

pr = NaN(nsat, 1);

if (opt.iono == const.IONOOPT_IFLC) % dual-frequency
    gamma = NaN(nsat, 1);
    % GPS & QZSS
    gamma(gps | qzs) = (const.FREQ_L1/const.FREQ_L2)^2; % L1-L2
    pr(gps | qzs) = (P2(gps | qzs) - gamma(gps | qzs).*P1(gps | qzs))./(1 - gamma(gps | qzs));
    
    % GLONASS
    gamma(glo) = (const.FREQ_G1/const.FREQ_G2)^2; % G1-G2
    pr(glo) = (P2(glo) - gamma(glo).*P1(glo))./(1 - gamma(glo));
    
    % Galileo
    gamma(gal) = (const.FREQ_E1/const.FREQ_E5B)^2; % E1-E5b
    if getephsel('E') % F/NAV
        P2(gal) = P2(gal) - (tgd(gal, 1) - tgd(gal, 2))*const.C_LIGHT; % BGD E5a/E1 - BGD E5b/E1
    end
    pr(gal) = (P2(gal) - gamma(gal).*P1(gal))./(1 - gamma(gal));
    
    % BDS
    B1I = ... % BDS B1I ?
        code(:,1) == const.CODE_L2I | ...
        code(:,1) == const.CODE_L2Q | ...
        code(:,1) == const.CODE_L2X;
    
    B1C = ... % BDS B1C ?
        code(:,1) == const.CODE_L1D | ...
        code(:,1) == const.CODE_L1P | ...
        code(:,1) == const.CODE_L1X | ...
        code(:,1) == const.CODE_L1A | ...
        code(:,1) == const.CODE_L1N;
    
    gamma(bds & B1I) = (const.FREQ_B1/const.FREQ_B2B)^2; % B1I-B2
    gamma(bds & B1C) = (const.FREQ_B1C/const.FREQ_B2B)^2; % B1C-B2
    
    pr(bds & B1I) = ...
        ((P2(bds & B1I) - gamma(bds & B1I).*P1(bds & B1I)) - ...
        (tgd(bds & B1I, 2) - gamma(bds & B1I).*tgd(bds & B1I, 1))*const.C_LIGHT)./(1 - gamma(bds & B1I));
    
    pr(bds & B1C) = ...
        ((P2(bds & B1C) - gamma(bds & B1C).*P1(bds & B1C)) - ...
        (tgd(bds & B1C, 2) - gamma(bds & B1C).*tgd(bds & B1C, 3))*const.C_LIGHT)./(1 - gamma(bds & B1C));
    
    pr(bds & ~B1I & ~B1C) = ...
        ((P2(bds & ~B1I & ~B1C) - gamma(bds & ~B1I & ~B1C).*P1(bds & ~B1I & ~B1C)) - ...
        (tgd(bds & ~B1I & ~B1C, 2) - gamma(bds & ~B1I & ~B1C).*(tgd(bds & ~B1I & ~B1C, 3) + tgd(bds & ~B1I & ~B1C, 5)))*const.C_LIGHT)./(1 - gamma(bds & ~B1I & ~B1C));
    
    % IRNSS
    gamma(irn) = (const.FREQ_L5/const.FREQ_S)^2; % L5-S
    pr(irn) = (P2(irn) - gamma(irn).*P1(irn))./(1 - gamma(irn));
        
    % standard deviation of code bias error correction
    var = zeros(nsat, 1);
    
    pr(isnan(P2) | isnan(P1) | P1 == 0 | P2 == 0) = NaN;
    
else % single-frequency
    % GPS & QZSS
    pr(gps | qzs) = P1(gps | qzs) - tgd(gps | qzs, 1)*const.C_LIGHT; % TGD
    
    % GLONASS
    pr(glo) = P1(glo) - tgd(glo, 1)./((const.FREQ_G1 / const.FREQ_G2)^2 - 1)*const.C_LIGHT; % -dtaun
    
    % Galileo
    if getephsel('E') % F/NAV
        pr(gal) = P1(gal) - tgd(gal, 1)*const.C_LIGHT; % BGD E5a/E1
    else % I/NAV
        pr(gal) = P1(gal) - tgd(gal, 2)*const.C_LIGHT; % BGD E5b/E1
    end
    
    % BDS
    B1I = ... % BDS B1I ?
        code(:,1) == const.CODE_L2I | ...
        code(:,1) == const.CODE_L2Q | ...
        code(:,1) == const.CODE_L2X;
    
    B1C = ... % BDS B1C ?
        code(:,1) == const.CODE_L1D | ...
        code(:,1) == const.CODE_L1P | ...
        code(:,1) == const.CODE_L1X | ...
        code(:,1) == const.CODE_L1A | ...
        code(:,1) == const.CODE_L1N;
    
    pr(bds & B1I) = P1(bds & B1I) - tgd(bds & B1I, 1)*const.C_LIGHT; % TGD B1I
    pr(bds & B1C) = P1(bds & B1C) - tgd(bds & B1C, 3)*const.C_LIGHT; % TGD B1C
    pr(bds & ~B1I & ~B1C) = P1(bds & ~B1I & ~B1C) - (tgd(bds & ~B1I & ~B1C, 3) + tgd(bds & ~B1I & ~B1C, 5))*const.C_LIGHT;
    
    % IRNSS
    pr(irn) = P1(irn) - tgd(irn, 1).*(const.FREQ_S/const.FREQ_L5)^2*const.C_LIGHT; % TGD
    
    % variance of code bias error correction
    var = (const.ERR_CBIAS*ones(nsat, 1)).^2;
end

% compute ionospheric correction -------------------------------------------------------------------
function [iono, var] = ionocorr(time, nav, llh, azel, ionoopt)

global const

switch ionoopt
    case const.IONOOPT_BRDC % GPS broadcast ionosphere model (klobuchar model)
        iono = ionomodel(time, nav.iono(1, 1:8), llh, azel);
        var  = (iono*const.ERR_FACTOR_BRDCI).^2;
        
    otherwise % no correction or iono-free linear combination
        nsat = size(azel, 1);
        iono = zeros(nsat, 1);
        if (ionoopt == const.IONOOPT_OFF)
            var = const.ERR_IONO^2*ones(nsat, 1);
        else
            var = zeros(nsat, 1);
        end
end

% compute tropospheric correction ------------------------------------------------------------------
function [tropo, var] = tropocorr(time, llh, azel, tropoopt)

global const

switch tropoopt
    case {const.TROPOOPT_SAAS, const.TROPOOPT_EST, const.TROPOOPT_ESTG} % Saatamoinen model
        tropo = tropomodel(time, llh, azel, const.REL_HUMI);
        var   = (const.ERR_SAAS./(sin(azel(:,2)) + 0.1)).^2;
        
    otherwise % no correction
        nsat  = size(azel, 1);
        tropo = zeros(nsat, 1);
        if (tropoopt == const.TROPOOPT_OFF)
            var = const.ERR_TROPO^2*ones(nsat, 1);
        else
            var = zeros(nsat, 1);
        end
end

% compute pseudorange measurement error variance ---------------------------------------------------
function [var] = varmeas(el, sys, opt)

global const

nsat = length(sys(:));

sf = NaN(nsat, 1);
sf(sys == 'G') = const.ERR_FACTOR_GPS;
sf(sys == 'R') = const.ERR_FACTOR_GLO;
sf(sys == 'E') = const.ERR_FACTOR_GAL;
sf(sys == 'J') = const.ERR_FACTOR_QZS;
sf(sys == 'C') = const.ERR_FACTOR_BDS;
sf(sys == 'I') = const.ERR_FACTOR_IRN;
sf(sys == 'S') = const.ERR_FACTOR_SBS;

el(el < const.MIN_EL) = const.MIN_EL;

var = sf.^2.*opt.err(1)^2.*(opt.err(2)^2 + opt.err(3)^2./sin(el)); % single-frequency
if (opt.iono == const.IONOOPT_IFLC) % iono-free (dual-frequency)
    var = 9*var;
end

% validate solution --------------------------------------------------------------------------------
function [stat] = valsol(azel, v, nx, opt)

stat = 1;
return;

% Chi-square validation of code residuals
vv = v'*v;
nv = length(v);
if (nv > nx && vv > chi2inv(0.999, nv - nx)) % alpha = 0.001
    fprintf('valsol: chi-square error\n'); stat = 0; return;
end

% large GDOP check
dop = dops(azel, opt.elmask);
if (isnan(dop(1)) || dop(1) <= 0 || dop(1) > opt.maxgdop)
    fprintf('valsol: gdop error\n'); stat = 0; return
end

stat = 1;

% estimate receiver velocity -----------------------------------------------------------------------
function sol = estvel(sol, obs, nav, rs, dts, vsat, azel, opt)

global const

% initial position and clock error
x = zeros(1, 4);

% least square iteration
for i = 1:const.MAX_ITER_LSQ
    % compute pseudorange residuals
    [v, var, H] = resdop(obs, nav, rs, dts, sol.rr(1:3), vsat, azel, x, opt);
    if length(v) < 4
        sol.stat = const.SOLQ_NONE;
        break;
    end
    
    % least square estimation
    [dx, Q] = lsq(v, H, diag(1./var));
    
    % update initial position and clock bias with least square solution
    x = x + dx';
    
    if (norm(dx) < 1E-6)
        sol.rr(4:6)  = x(1:3);
        break;
    end
end

if (i >= const.MAX_ITER_LSQ)
    sol.stat = const.SOLQ_NONE;
    disp('least square iteration divergent');
end

% compute range rate residual ----------------------------------------------------------------------
function [v, var, H] = resdop(obs, nav, rs, dts, rr, vsat, azel, x, opt)

global const

sat = obs(:,3);
nsat = length(sat);

% convert ECEF position to geodetic position
llh = xyz2llh(rr);

% LOS (line-of-sight) vector in ECEF
[~, e] = geodist(rs(:,1:3), rr);

% satellite velocity relative to receiver in ECEF
vs = rs(:,4:6) - x(1:3);

% range rate with earth rotation correction
rate = NaN(nsat, 1);
for i = 1 : nsat
    rate(i,:) = e(i,:)*vs(i,:)'+const.OMGE_GPS/const.C_LIGHT*(rs(i,5)*rr(1) + rs(i,2)*x(1) - rs(i,4)*rr(2) - rs(i,1)*x(2));
end

% variance of range rate error (m/s)
if opt.err(5) <= 0
    var = ones(nsat, 1);
else
    var = (opt.err(5)*nav.lam(sat, 1)).^2;
end

% range rate residual
v = -obs(:,14).*nav.lam(sat, 1) - (rate + x(4) - const.C_LIGHT*dts(:,2));

% design matrix
H = [-e, ones(nsat, 1)];

% valid = vsat(sat, 1);
% 
% v = v(valid);
% H = H(valid,:);
% var = var(valid);