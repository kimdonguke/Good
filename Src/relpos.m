function [dgnss, stat] = relpos(dgnss, obs, nav)
% ==================================================================================================
% RELPOS
%   relative positioning
% ==================================================================================================

global const

opt = dgnss.opt;

dgnss.sol.stat = const.SOLQ_DGPS;

nf = opt.nfreq;
nr = length(find(obs(:,2) == 1)); % # of rover observation data
nb = length(find(obs(:,2) == 2)); % # of base observation data

dt = obs(1, 1) - obs(nr+1, 1); % time difference between rover and base observations

y    = NaN(nr+nb, nf);  % un-differenced residuals
e    = NaN(nr+nb, 3);         % line of sight
azel = NaN(nr+nb, 2);         % azimuth and elevation
freq = NaN(size(obs, 1), nf); % carrier-frequency

dgnss.ssat.sys  = NaN(const.MAX_SAT, 1);
dgnss.ssat.vsat = zeros(const.MAX_SAT, 5);
dgnss.ssat.snr  = NaN(const.MAX_SAT, 5);

% compute satellite positions and clock error
[rs, dts, vareph, svh] = satposclk(obs, nav);

% UD (undifferenced) residuals for base station
if (all(dgnss.rb(1:3) == 0) || isempty(dgnss.rb(1:3)) || any(isnan(dgnss.rb(1:3))))
    disp('base position error'); stat = 0; return;
else
    [y(nr+1:end,:), e(nr+1:end,:), azel(nr+1:end,:), freq(nr+1:end,:)] = ...
        zdres(2, obs(nr+1:end,:), rs(nr+1:end,:), dts(nr+1:end,:), vareph(nr+1:end), svh(nr+1:end), nav, dgnss.rb(1:3), nf, opt);
end

% select common satellites between rover and base stations
[sat, ir, ib] = selsat(obs, nr, azel, opt);
if numel(sat(:)) < 4 + numel(opt.navsys) - 1
    disp('insufficient common satellites'); stat = 0; return;
end

% carrier frequency
dgnss.ssat.freq(sat, 1:nf) = freq(ib, 1:nf);

% temporal update of states
dgnss = udstate(dgnss);

% filter iterations
xp = dgnss.x;
Pp = dgnss.P;

for i = 1:opt.niter
    % UD (undifferenced) residuals for rover
    if (all(xp(1:3) == 0) || isempty(xp(1:3)) || any(isnan(xp(1:3))))
        disp('rover position error'); dgnss.sol.stat = const.SOLQ_NONE; break;
    else
        [y(1:nr,:), e(1:nr,:), azel(1:nr,:), freq(1:nr,:)] = ...
            zdres(1, obs(1:nr,:), rs(1:nr,:), dts(1:nr,:), vareph(1:nr), svh(1:nr), nav, xp(1:3)', nf, opt);
    end
    
    % DD (double-differenced) residuals and partial derivatives
    [dgnss, v, R, H, resp] = ddres(dgnss, dt, xp, sat, ir, ib, y, e, azel, nf);
    if (length(v) < 1)
        disp('no valid double-differenced residuals'); dgnss.sol.stat = const.SOLQ_NONE; break;
    end
    
    % kalman filter measurement update
    [x, P] = udmeas(xp, Pp, H, v, R);
end

if (dgnss.sol.stat ~= const.SOLQ_NONE) && ~(all(x(1:3) == 0) || isempty(x(1:3)) || any(isnan(x(1:3))))
    % post-fit residuals for float solution
    [y(1:nr,:), e(1:nr,:), azel(1:nr,:)] = ...
        zdres(1, obs(1:nr,:), rs(1:nr,:), dts(1:nr,:), vareph(1:nr), svh(1:nr), nav, x(1:3)', nf, opt);
    
    [dgnss, v, R, ~, resp, vsat] = ddres(dgnss, dt, x, sat, ir, ib, y, e, azel, nf);
    
    % validation of float solution
    if (valsol(v, R, 4.0))
        % update state and covariance matrix
        dgnss.x = x;
        dgnss.P = P;
        
        % number of valid satellites
        valid = vsat(:,1:nf);
        dgnss.sol.nsat = length(find(valid(:,1))); % valid satellite count by L1
        
        % lack of valid satellites
        if (dgnss.sol.nsat < 4)
            dgnss.sol.stat = const.SOLQ_NONE;
        end
    end
end

% satellite azimuth and elevation angles
dgnss.sol.sataz(sat) = azel(ir, 1);
dgnss.sol.satel(sat) = azel(ir, 2);

% save solution status
dgnss.sol.rr(1:3) = dgnss.x(1:3);
dgnss.sol.qr(1:3) = diag(dgnss.P(1:3, 1:3));
dgnss.sol.qr(4:6) = [dgnss.P(1, 2), dgnss.P(2, 3), dgnss.P(3, 1)];

stat = dgnss.sol.stat ~= const.SOLQ_NONE;

% UD (undifferenced) phase and code residuals ------------------------------------------------------
function [y, e, azel, freq] = zdres(rcv, obs, rs, dts, veph, svh, nav, rr, nf, opt)

global const

n = size(obs, 1);

% geodetic coordinates
llh = xyz2llh(rr);

% compute geometric distance
[r, e] = geodist(rs(:,1:3), rr);

% compute azimuth and elevation angle
azel = satazel(rs(:,1:3), rr);

% satellite clock error
r = r - const.C_LIGHT*dts(:,1);

% tropospheric delay model (hydrostatic)
zhd = tropomodel(obs(1, 1), llh, [zeros(n, 1), pi/180*90*ones(n, 1)], 0);
r = r + tropomapf(obs(:,1), llh, azel).*zhd;

% receiver antenna phase center correction
dant = antmodel(opt.pcvr{rcv}, opt.antdel{rcv}, azel, opt.posopt(2));

% undifferenced phase and code residuals for satellite
[y, freq] = zdres_sat(r, obs, dant, nf);

% test elevation mask and excluded satellites
valid = azel(:,2) > opt.elmask & testsat(obs(:,3), veph, svh, opt);
y(~valid,:) = NaN;

% receiver antenna model ---------------------------------------------------------------------------
function [dant] = antmodel(pcvr, del, azel, opt)

e = [sin(azel(:,1)).*cos(azel(:,2)), cos(azel(:,1)).*cos(azel(:,2)), sin(azel(:,2))];

dant = zeros(size(azel, 1), 5);
for f = 1:5
    if (~isempty(pcvr.off(:,f)) && all(~isnan(pcvr.off(:,f))))
        dant(:,f) = -e*(pcvr.off(:,f)); % phase center offset
%         dant(:,f) = -e*(pcvr.off(:,f) + del(:)); % phase center offset
        if (opt) % phase center variation
            dant(:,f) = dant(:,f) + interp1(0:5:90, pcvr.var(:,f), 90-azel(:,2)*180/pi);
        end
    end
end

% undifference phase and code residuals for satellite ----------------------------------------------
function [y, freq] = zdres_sat(r, obs, dant, nf)

y    = NaN(size(obs, 1), nf);
sat  = obs(:,3);
code = obs(:,29:33);
freq = NaN(size(obs, 1), nf);

for f = 1:nf
    freq(:,f) = code2freq(sat, code(:,f));
    pr = obs(:,4+(f - 1));
    valid = ~isnan(pr) & pr ~= 0; % code valid
    
    % residuals = observable - model
    y(valid, f) = pr(valid) - r(valid) - dant(valid, f);
end

% select common satellites between rover and base stations -----------------------------------------
function [sat, ir, ib] = selsat(obs, nr, azel, opt)

% index of rover observation
[sat, ~, ib] = intersect(obs(1:nr,3), obs(nr+1:end,3));

% check elevation angle
abvmask = azel(ib+nr, 2) > opt.elmask; % elevation angle at base station

sat = sat(abvmask);
ib  = ib(abvmask) + nr;

% index of base observation
[~, ir] = intersect(obs(1:nr,3), sat);

% kalman filter measurement update -----------------------------------------------------------------
function [x, P] = udmeas(xp, Pp, H, v, R)

x = xp;
P = Pp;

i = find(xp ~= 0 & diag(Pp) > 0);

xp = xp(i);
Pp = Pp(i, i);
H  = H(:,i);

K = Pp*H'/(H*Pp*H' + R);

x(i) = xp + K*v;
P(i, i) = (eye(length(i)) - K*H)*Pp;

% temporal update of states ------------------------------------------------------------------------
function [dgnss] = udstate(dgnss)

VAR_POS = 30^2; % initial variance of position [m^2]

[dgnss] = initx(dgnss, dgnss.sol.rr(1:3), VAR_POS, 1:3);

% DD (double-differenced) phase and code residuals -------------------------------------------------
function [dgnss, v, R, H, resp, vsat] = ddres(dgnss, dt, x, sat, ir, ib, y, e, azel, nf)

global const

% satellite system
sys = sat2prn(sat);
gps = sys == 'G';
glo = sys == 'R';
gal = sys == 'E';
qzs = sys == 'J';
bds = sys == 'C';
irn = sys == 'I';

% baseline length
bl = norm(x(1:3) - dgnss.rb(1:3)');

% initialize some stuff
dgnss.ssat.resp = NaN(const.MAX_SAT, 5);
dgnss.ssat.resc = NaN(const.MAX_SAT, 5);
dgnss.ssat.vsat = false(const.MAX_SAT, 5);

% single-differneced residuals
v = y(ir,:) - y(ib,:);

% single-differenced measurement error variances
verr = varmeas(sys, azel(ir, 2), bl, dt, nf, dgnss.opt);

% loop over frequencies
nsat = length(sat);

H = zeros(nsat*nf, 3);	 % partial derivatives
R = zeros(nsat*nf, nsat*nf); % measurement error variance-covariance
vsat = zeros(nsat, nf);
resp = zeros(nsat, nf);

ref = []; % index of reference satellite
for f = 1:nf
    % search reference satellite with highest elevation
    el = azel(ir, 2).*(~isnan(sum(v(:,f), 2)));
    
    [~, refgps] = max(el(gps)); refgps = refgps + find(gps, 1) - 1;
    [~, refglo] = max(el(glo)); refglo = refglo + find(glo, 1) - 1;
    [~, refgal] = max(el(gal)); refgal = refgal + find(gal, 1) - 1;
    [~, refqzs] = max(el(qzs)); refqzs = refqzs + find(qzs, 1) - 1;
    [~, refbds] = max(el(bds)); refbds = refbds + find(bds, 1) - 1;
    [~, refirn] = max(el(irn)); refirn = refirn + find(irn, 1) - 1;
    
    ref = [ref; refgps; refglo; refgal; refqzs; refbds; refirn];

    % double-differenced residuals
    v(gps, f) = v(refgps, f) - v(gps, f);
    v(glo, f) = v(refglo, f) - v(glo, f);
    v(gal, f) = v(refgal, f) - v(gal, f);
    v(qzs, f) = v(refqzs, f) - v(qzs, f);
    v(bds, f) = v(refbds, f) - v(bds, f);
    v(irn, f) = v(refirn, f) - v(irn, f);
    
    % partial derivatives by rover position
    igps = find(gps);
    iglo = find(glo);
    igal = find(gal);
    iqzs = find(qzs);
    ibds = find(bds);
    iirn = find(irn);
    
    H((f - 1)*nsat + igps, 1:3) = e(ir(gps),:) - e(ir(refgps),:);
    H((f - 1)*nsat + iglo, 1:3) = e(ir(glo),:) - e(ir(refglo),:);
    H((f - 1)*nsat + igal, 1:3) = e(ir(gal),:) - e(ir(refgal),:);
    H((f - 1)*nsat + iqzs, 1:3) = e(ir(qzs),:) - e(ir(refqzs),:);
    H((f - 1)*nsat + ibds, 1:3) = e(ir(bds),:) - e(ir(refbds),:);
    H((f - 1)*nsat + iirn, 1:3) = e(ir(irn),:) - e(ir(refirn),:);
    
    % save double-differenced code residuals
    resp(:,f) = v(:,f);
    
    % valid flags
    vsat(~isnan(v(:,f)), f) = 1;

    % double-differenced measurement error variance-covariance
    R((f - 1)*nsat + igps, (f - 1)*nsat + igps) = diag(verr(igps, f)) + verr(refgps, f);
    R((f - 1)*nsat + iglo, (f - 1)*nsat + iglo) = diag(verr(iglo, f)) + verr(refglo, f);
    R((f - 1)*nsat + igal, (f - 1)*nsat + igal) = diag(verr(igal, f)) + verr(refgal, f);
    R((f - 1)*nsat + iqzs, (f - 1)*nsat + iqzs) = diag(verr(iqzs, f)) + verr(refqzs, f);
    R((f - 1)*nsat + ibds, (f - 1)*nsat + ibds) = diag(verr(ibds, f)) + verr(refbds, f);
    R((f - 1)*nsat + iirn, (f - 1)*nsat + iirn) = diag(verr(iirn, f)) + verr(refirn, f);
end

valid = ~isnan(v) & v ~= 0; % no reference satellites with valid obs
valid = valid(:);

v = v(valid);
H = H(valid,:);
R = R(valid, valid);

% single-differenced measurement error variance ----------------------------------------------------
function [var] = varmeas(sys, el, bl, dt, nf, opt)

global const

% check satellite system
gps = sys == 'G';
glo = sys == 'R';
gal = sys == 'E';
qzs = sys == 'J';
bds = sys == 'C';
irn = sys == 'I';
sbs = sys == 'S';

% compute error variance
nsat = length(sys);

sf = ones(nsat, nf).*opt.errratio(1:nf);
sf(gps,:) = const.ERR_FACTOR_GPS * sf(gps,:);
sf(glo,:) = const.ERR_FACTOR_GLO * sf(glo,:);
sf(gal,:) = const.ERR_FACTOR_GAL * sf(gal,:);
sf(qzs,:) = const.ERR_FACTOR_QZS * sf(qzs,:);
sf(bds,:) = const.ERR_FACTOR_BDS * sf(bds,:);
sf(irn,:) = const.ERR_FACTOR_IRN * sf(irn,:);
sf(sbs,:) = const.ERR_FACTOR_SBS * sf(sbs,:);

a = sf*opt.err(2);
b = sf*opt.err(3);
c = (opt.err(4)*bl/1E4)*ones(nsat, nf);
d = (opt.satclkstab*const.C_LIGHT*dt)*ones(nsat, nf);

var = 2*(a.^2 + (b.^2./(sin(el)).^2) + c.^2 + d.^2);

% validation of solution (TBC) ---------------------------------------------------------------------
function [stat] = valsol(v, R, thres)

invalid = (v.*v) > thres^2*diag(R);
stat = true;
if (any(invalid))
    %stat = false;
end

% initialize state and covariance ------------------------------------------------------------------
function [dgnss] = initx(dgnss, xi, var, i)
i = i(:)';
dgnss.x(i) = xi(:);
for k = i
    dgnss.P(k,:)  = 0;
    dgnss.P(:,k)  = 0;
    dgnss.P(k, k) = var;
end