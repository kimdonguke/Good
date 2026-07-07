function [lam,gamma] = satwavelen(nav)

global const

lam   = NaN(221, 7);
gamma = NaN(221, 7);

%% gps
lam(  1: 32, 1) = const.C_LIGHT / const.FREQ_L1;
lam(  1: 32, 2) = const.C_LIGHT / const.FREQ_L2;
lam(  1: 32, 3) = const.C_LIGHT / const.FREQ_L5;

gamma(  1: 32, 1) = const.FREQ_L1^2/const.FREQ_L1^2;
gamma(  1: 32, 2) = const.FREQ_L1^2/const.FREQ_L2^2;
gamma(  1: 32, 3) = const.FREQ_L1^2/const.FREQ_L5^2;

%% glo
for k = 33:59
    if ~isempty(nav.eph{k,1})
        lam(k, 1) = const.C_LIGHT ./ (const.FREQ_G1 + const.DFREQ_G1 * nav.eph{k,1}(1,13));
        lam(k, 2) = const.C_LIGHT ./ (const.FREQ_G2 + const.DFREQ_G2 * nav.eph{k,1}(1,13));
    end
end

gamma( 33: 59, 1) = const.FREQ_G1^2/const.FREQ_G1^2;
gamma( 33: 59, 2) = const.FREQ_G1^2/const.FREQ_G2^2;

% lam( 33: 59, 1) = const.C_LIGHT ./ (const.FREQ_G1 + const.DFREQ_G1 * nav.eph(:,13));
% lam( 33: 59, 2) = const.C_LIGHT ./ (const.FREQ_G2 + const.DFREQ_G2 * nav.eph(:,13));
% lam( 33: 59, 3) = const.C_LIGHT ./ (const.FREQ_G3);

%% gal
lam( 60: 95, 1) = const.C_LIGHT / const.FREQ_E1;
lam( 60: 95, 3) = const.C_LIGHT / const.FREQ_E5A;
% lam( 60: 95, 4) = const.C_LIGHT / const.FREQ_E5B;
% lam( 60: 95, 5) = const.C_LIGHT / const.FREQ_E5AB;
% lam( 60: 95, 6) = const.C_LIGHT / const.FREQ_E6;

gamma( 60: 95, 1) = const.FREQ_E1^2/const.FREQ_E1^2;
gamma( 60: 95, 3) = const.FREQ_E1^2/const.FREQ_E5A^2;

%% qzs
% lam( 96:105, 1) = const.C_LIGHT / const.FREQ_L1;
% lam( 96:105, 2) = const.C_LIGHT / const.FREQ_L2;
% lam( 96:105, 3) = const.C_LIGHT / const.FREQ_L5;
% lam( 96:105, 4) = const.C_LIGHT / const.FREQ_L6;

%% bds
lam(106:168, 1) = const.C_LIGHT / const.FREQ_B1;
lam(106:168, 2) = const.C_LIGHT / const.FREQ_B3;
lam(106:168, 3) = const.C_LIGHT / const.FREQ_B2A;

gamma(106:168, 1) = const.FREQ_B1^2/const.FREQ_B1^2;
gamma(106:168, 2) = const.FREQ_B1^2/const.FREQ_B3^2;
gamma(106:168, 3) = const.FREQ_B1^2/const.FREQ_B2A^2;

%% irn
% lam(169:182, 1) = const.C_LIGHT / const.FREQ_L1;
% lam(169:182, 2) = const.C_LIGHT / const.FREQ_L2;
% lam(169:182, 3) = const.C_LIGHT / const.FREQ_L5;

%% sbs
% lam(183:221, 1) = const.C_LIGHT / const.FREQ_L1;
% lam(183:221, 3) = const.C_LIGHT / const.FREQ_L5;

end