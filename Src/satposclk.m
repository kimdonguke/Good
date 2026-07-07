function [rs, dts, var, svh, tgd, iode] = satposclk(obs, nav)
% ==================================================================================================
% SATPOSCLKBRDC
%   compute satellite position and clock error with broadcast ephemeris
% ==================================================================================================

global const

nsat = size(obs, 1);

% search any pseudorange
pr = obs(:,4); % L1
for f = 2 : 5
    pr(isnan(pr) | pr == 0) = obs(isnan(pr) | pr == 0, 3 + f);
end

% GLONASS ?
sat = obs(:,3);
glo = sat2prn(sat) == 'R';

% compute approximate signal transmission time
sat_ = intersect(obs(obs(:,2) == 1, 3), obs(obs(:,2) == 2, 3));
txtime = obs(:,1);
txtime(ismember(obs(:,3), sat_) & obs(:,2) == 2, 1) = txtime(ismember(obs(:,3), sat_) & obs(:,2) == 1, 1);
txtime = txtime - pr / const.C_LIGHT;

% select valid broadcast ephemeris
iode = -ones(nsat, 1);
eph = seleph(txtime, nav, sat, iode);

% compute signal transmission time and correct satellite clock bias
txtime = obs(:,1) - pr / const.C_LIGHT;
txtime(~glo) = txtime(~glo) - eph2clk   (txtime(~glo), eph(~glo,:));
txtime( glo) = txtime( glo) - gloeph2clk(txtime( glo), eph( glo,:));

% compute satellite position and clock bias
rs  = NaN(nsat, 6);
dts = NaN(nsat, 2);
var = NaN(nsat, 1);

[rs(~glo, :), dts(~glo, :), var(~glo)] = eph2pos   (txtime(~glo), eph(~glo,:));
[rs( glo, :), dts( glo, :), var( glo)] = gloeph2pos(txtime( glo), eph( glo,:));

% compute satellite velocity and clock drift
% t_f = 0.01;
% t_b = -0.01;
% [rs_f(~glo, :), dts_f(~glo, :), var_f(~glo)] = eph2pos   (txtime(~glo)+t_f, eph(~glo,:));
% [rs_f( glo, :), dts_f( glo, :), var_f( glo)] = gloeph2pos(txtime( glo)+t_f, eph( glo,:));
% 
% [rs_b(~glo, :), dts_b(~glo, :), var_b(~glo)] = eph2pos   (txtime(~glo)+t_b, eph(~glo,:));
% [rs_b( glo, :), dts_b( glo, :), var_b( glo)] = gloeph2pos(txtime( glo)+t_b, eph( glo,:));
% 
% rs( :, 4:6) = (rs_f(:,1:3) - rs_b(:,1:3)) ./ (t_f-t_b);
% dts(:,   2) = (dts_f(:,1) - dts_b(:,1)) ./ (t_f-t_b);

% get TGD parameters
tgd = gettgd(eph);
    
% get satellite health flag
svh = NaN(nsat, 1);
svh(~glo) = eph(~glo, 27);
svh( glo) = eph( glo,  9);
svh(isnan(svh)) = 1;

% issue of data, ephemeris
iode = NaN(nsat, 1);
iode(~glo) = eph(~glo,  6);
iode( glo) = eph( glo, 18);

% select broadcast ephemeris -----------------------------------------------------------------------
function eph = seleph(time, nav, sat, iode)

global const

sys = sat2prn(sat);

% number of satellites
nsat = size(sat, 1);

% set maximum time difference to toe
tmax = NaN(nsat, 1);
tmax(sys == 'G') = const.MAX_DTOE_GPS;
tmax(sys == 'R') = const.MAX_DTOE_GLO;
tmax(sys == 'E') = const.MAX_DTOE_GAL;
tmax(sys == 'J') = const.MAX_DTOE_QZS;
tmax(sys == 'C') = const.MAX_DTOE_BDS;
tmax(sys == 'I') = const.MAX_DTOE_IRN;
tmax(sys == 'S') = const.MAX_DTOE_SBS;

% loop over all satellites
eph = NaN(nsat, 38);
for s = 1 : nsat
    ephs = nav.eph{sat(s)};
    if ~isempty(ephs)
        % check iode
        ephs(iode(s) >= 0 & iode(s) ~= ephs(:,6),:) = [];
        
        % select ephemeris type for Galileo
        if sys(s) == 'E'
            switch getephsel('E')
                case 0 % I/NAV
                    ephs = ephs(logical(bitand(ephs(:,23), 512)),:); % I/NAV
                case 1 % F/NAV
                    ephs = ephs(logical(bitand(ephs(:,23), 256)),:); % F/NAV
            end
            
            ephs = ephs(time(s) > ephs(:,33),:); % AOD > 0
        end
        
        % toe closet to time
        dtoe = abs(time(s) - ephs(:,33));
        
        % check tx time of message
%         dttr = time(s) - ephs(:,34);
%         dtoe(dttr < 0) = 1E6;
        
        [tmin, i] = min(dtoe);
        if tmin <= tmax(s), eph(s,:) = ephs(i,:); end
    end
end

% compute satellite position and clock error with kepler ephemeris ---------------------------------
function [rs, dts, var] = eph2pos(time, eph)

global const

C_LIGHT = const.C_LIGHT;

% number of satellites
nsat = size(eph, 1);

% satellite number with system
[sys, prn] = sat2prn(eph(:,1));

% check satellite system
gps = sys == 'G';
gal = sys == 'E';
qzs = sys == 'J';
bds = sys == 'C';
irn = sys == 'I';
geo = sys == 'C' & (prn <= 5 | prn >= 59);

% gravitaional constant
mu      = NaN(nsat, 1);
mu(gps) = const.MU_GPS;
mu(gal) = const.MU_GAL;
mu(qzs) = const.MU_QZS;
mu(bds) = const.MU_BDS;
mu(irn) = const.MU_IRN;

% Earth's angular rate
omge      = NaN(nsat, 1);
omge(gps) = const.OMGE_GPS;
omge(gal) = const.OMGE_GAL;
omge(qzs) = const.OMGE_QZS;
omge(bds) = const.OMGE_BDS;
omge(irn) = const.OMGE_IRN;

% time from ephemeris reference epoch (time - toe)
tk = time - eph(:,33);

% mean anomaly
Mk = eph(:,9) + (sqrt(mu./(eph(:,13).^2).^3) + eph(:,8)).*tk;

% kepler's equation
Ek  = Mk;
Ek0 = 0;
niter = 0;
while any(abs(Ek - Ek0)> 1E-14) & niter < const.MAX_ITER_KEPLER %#ok<AND2>
    Ek0 = Ek;
    Ek = Ek - (Ek - eph(:,11).*sin(Ek) - Mk)./(1 - eph(:,11).*cos(Ek));
    niter = niter + 1;
end

Ek(Ek <    0) = Ek(Ek <    0) + 2*pi;
Ek(Ek > 2*pi) = Ek(Ek > 2*pi) - 2*pi;

% argument of latitude, radius and inclination
sinEk = sin(Ek);
cosEk = cos(Ek);

vk = atan2((sqrt(1-eph(:,11).^2) .* sinEk), (cosEk - eph(:,11)));
uk = atan2(sqrt(1 - eph(:,11).^2).*sinEk, (cosEk - eph(:,11))) + eph(:,20);
rk = eph(:,13).^2.*(1 - eph(:,11).*cosEk);
ik = eph(:,18) + eph(:,22).*tk;

% corrected argument of latitude, radius and inclination
sin2uk = sin(2*uk);
cos2uk = cos(2*uk);

uk = uk + eph(:,12).*sin2uk + eph(:,10).*cos2uk;
rk = rk + eph(:, 7).*sin2uk + eph(:,19).*cos2uk;
ik = ik + eph(:,17).*sin2uk + eph(:,15).*cos2uk;

% satellite positions in orbital plane
xkp = rk.*cos(uk);
ykp = rk.*sin(uk);

% corrected longitude of ascending node
omgk       = NaN(nsat, 1);
omgk(~geo) = eph(~geo, 16) + (eph(~geo, 21) - omge(~geo)).*tk(~geo) - omge(~geo).*eph(~geo, 14);
omgk( geo) = eph( geo, 16) + (eph( geo, 21)             ).*tk( geo) - omge( geo).*eph( geo, 14);

% MEO/IGSO satellite positions in ECEF
rs = NaN(nsat, 3);

sinomgk = sin(omgk);
cosomgk = cos(omgk);
sinik   = sin(ik);
cosik   = cos(ik);

rs(~geo, 1) = xkp(~geo).*cosomgk(~geo) - ykp(~geo).*cosik(~geo).*sinomgk(~geo);
rs(~geo, 2) = xkp(~geo).*sinomgk(~geo) + ykp(~geo).*cosik(~geo).*cosomgk(~geo);
rs(~geo, 3) = ykp(~geo).*sinik(~geo);

% GEO satellite positions in ECEF
xgk = xkp(geo).*cosomgk(geo) - ykp(geo).*cosik(geo).*sinomgk(geo);
ygk = xkp(geo).*sinomgk(geo) + ykp(geo).*cosik(geo).*cosomgk(geo);
zgk = ykp(geo).*sinik(geo);

sinok = sin(omge(geo).*tk(geo));
cosok = cos(omge(geo).*tk(geo));

rs(geo, 1) =  xgk.*cosok + ygk.*sinok.*cosd(-5) + zgk.*sinok.*sind(-5);
rs(geo, 2) = -xgk.*sinok + ygk.*cosok.*cosd(-5) + zgk.*cosok.*sind(-5);
rs(geo, 3) = -ygk.*sind(-5) + zgk.*cosd(-5);

% satellite velocity in ECEF
Ek_dot = (sqrt(mu./(eph(:,13).^2).^3) + eph(:,8)) ./ (1 - eph(:,11) .* cosEk);
Phik_dot = (sin(vk) ./ sinEk) .* Ek_dot;

deltauk_dot = 2 * (eph(:,12) .* cos2uk - eph(:, 10) .* sin2uk) .* Phik_dot;
deltark_dot = 2 * (eph(:, 7) .* cos2uk - eph(:,19) .* sin2uk) .* Phik_dot;
deltaik_dot = 2 * (eph(:,17) .* cos2uk - eph(:,15) .* sin2uk) .* Phik_dot;

rk_dot = (eph(:,13).^2 .* eph(:,11) .* sinEk) .* Ek_dot + deltark_dot;
uk_dot = Phik_dot + deltauk_dot;
ik_dot = eph(:,22) + deltaik_dot;

xkp_dot = rk_dot .* cos(uk) - rk .* uk_dot .* sin(uk);
ykp_dot = rk_dot .* sin(uk) + rk .* uk_dot .* cos(uk);

omgk_dot = eph(:,21) - omge;

rs(:, 4) = xkp_dot .* cosomgk - ykp_dot .* cosik .* sinomgk + ik_dot .* ykp .* sinik .* sinomgk - omgk_dot .* rs(:, 2);
rs(:, 5) = xkp_dot .* sinomgk + ykp_dot .* cosik .* cosomgk - ik_dot .* ykp .* sinik .* cosomgk + omgk_dot .* rs(:, 1);
rs(:, 6) = ykp_dot .* sinik + ik_dot .* ykp .* cosik;

% time from ephemeris reference epoch (time - toc)
tk = time - eph(:,32);

% satellite clock bias correction with relativity correction
dts_temp = eph(:,3) + eph(:,4).*tk + eph(:,5).*tk.^2;
dts(:,1) = dts_temp - 2.*sqrt(mu.*eph(:,13).^2).*eph(:,11).*sinEk/C_LIGHT/C_LIGHT;

% satellite clock drift
dts(:,2) = eph(:, 4) + 2*eph(:, 5).*tk;

% satellite position and clock error variance
var = vareph(eph);

% compute satellite position and clock error (GLONASS) ---------------------------------------------
function [rs, dts, var] = gloeph2pos(time, eph)

global const

TSTEP = const.TSTEP;

% number of satellites
nsat = size(eph, 1);

% time from ephemeris reference epoch
tk = time - eph(:,33);

% satellite position in ECEF
rs = NaN(nsat, 3);
tt = TSTEP*ones(nsat, 1);

x   = [eph(:,[6, 10, 14]), eph(:,[7, 11, 15])];
acc = eph(:,[8, 12, 16]);

while any(abs(tk) > 1E-9)
    tt(tk <  0) = -TSTEP;
    tt(tk >= 0) =  TSTEP;
    tt(abs(tk) < TSTEP) = tk(abs(tk) < TSTEP);
        
    x = gloorbit(tt, x, acc);
    
    tk = tk - tt;
end

rs(:,1:3) = x(:,1:3);
rs(:,4:6) = x(:,4:6);

% satellite clock bias
tk = time - eph(:,32);
dts(:,1) = -eph(:,3) + eph(:,4).*tk;
dts(:,2) = eph(:,4);

% satellite position and clock error variance
var = const.ERREPH_GLO^2*ones(nsat, 1);

% GLONASS position and velocity by numerical integration -------------------------------------------
function [x] = gloorbit(t, x, acc)

w = x;

k1 = deq(w, acc); w = x + k1.*t/2;
k2 = deq(w, acc); w = x + k2.*t/2;
k3 = deq(w, acc); w = x + k3.*t;
k4 = deq(w, acc); x = x + (k1 + 2*k2 + 2*k3 + k4).*t/6;

% GLONASS orbit differential equations -------------------------------------------------------------
function xdot = deq(x, acc)

global const

J2_GLO = const.J2_GLO; MU_GLO = const.MU_GLO; RE_GLO = const.RE_GLO; OMGE_GLO = const.OMGE_GLO;

r2 = sum(x(:,1:3).^2, 2);
r3 = r2 .* sqrt(r2);

a = 1.5*J2_GLO*MU_GLO*RE_GLO^2./r2./r3;
b = 5*x(:,3).^2./r2;
c = -MU_GLO./r3 - a.*(1 - b);

xdot    = zeros(size(x, 1), 6);
xdot(:,1) = x(:,4);
xdot(:,2) = x(:,5);
xdot(:,3) = x(:,6);
xdot(:,4) = (c + OMGE_GLO^2).*x(:,1) + 2 * OMGE_GLO.*x(:,5) + acc(:,1);
xdot(:,5) = (c + OMGE_GLO^2).*x(:,2) - 2 * OMGE_GLO.*x(:,4) + acc(:,2);
xdot(:,6) = (c - 2.*a).*x(:,3) + acc(:,3);

% GPS/GAL/QZS/BDS/IRN broadcast clock to satellite clock bias --------------------------------------
function [dts] = eph2clk(time, eph)

tk = time - eph(:,32);
for i = 1 : 2
    tk = time - eph(:,32) - (eph(:,3) + eph(:,4).*tk + eph(:,5).*tk.^2);
end
dts = eph(:,3) + eph(:,4).*tk + eph(:,5).*tk.^2;

% GLONASS broadcast clock to satellite clock bias --------------------------------------------------
function [dts] = gloeph2clk(time, eph)

tk = time - eph(:,32);
for i = 1 : 2
    tk = time - eph(:,32) - (-eph(:,3) + eph(:,4) .* tk);
end
dts = -eph(:,3) + eph(:,4) .* tk;

% get TGD parameters -------------------------------------------------------------------------------
function [tgd] = gettgd(eph)

sys = sat2prn(eph(:,1));

% initialization
tgd = zeros(length(sys(:)), 6);

% check satellite system
gps = sys == 'G';
gal = sys == 'E';
qzs = sys == 'J';
bds = sys == 'C';
irn = sys == 'I';

% GPS / QZSS / IRNSS
tgd(gps | qzs | irn, 1) = eph(gps | qzs | irn, 28); % TGD

% Galileo
tgd(gal, 1) = eph(gal, 28); % BGD E5a/E1
tgd(gal, 2) = eph(gal, 29); % BGD E5b/E1

% BDS
tgd(bds, 1) = eph(bds, 28); % TGD1 B1/B3
tgd(bds, 2) = eph(bds, 29); % TGD2 B2/B3

% ephemeris variance by URA or SISA index ----------------------------------------------------------
function [var] = vareph(eph)

global const

% invalid ephemeris
invalid = isnan(sum(eph, 2));
idx = eph(:,26);
idx(invalid) = -1;

% Galileo ?
gal = sat2prn(eph(:,1)) == 'E';

% initialization
var = NaN(length(idx), 1);

% URA index to variance
idx(~gal & (idx < 0 | idx > 15)) = 15;

var(~gal) = const.URA_EPH(idx(~gal)).^2;

% SISA index to variance
var(gal & (idx >=   0 & idx <=  49)) = (idx(gal & (idx >=   0 & idx <=  49))*0.01).^2;
var(gal & (idx >   49 & idx <=  74)) = (0.5 + (idx(gal & (idx >   49 & idx <=  74)) -  50)*0.02).^2;
var(gal & (idx >   74 & idx <=  99)) = (1.0 + (idx(gal & (idx >   74 & idx <=  99)) -  75)*0.04).^2;
var(gal & (idx >   99 & idx <= 125)) = (2.0 + (idx(gal & (idx >   99 & idx <= 125)) - 100)*0.16).^2;
var(gal & idx > 125) = (const.ERREPH_GAL_NAPA)^2;