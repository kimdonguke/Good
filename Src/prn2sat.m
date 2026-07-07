function sat = prn2sat(sys, prn)
% ==================================================================================================
% PRN2SAT
%   convert satellite system with PRN or slot number to satellite index
% ==================================================================================================

global const

sys = sys(:);
prn = prn(:);

gps = sys == 'G';
glo = sys == 'R';
gal = sys == 'E';
qzs = sys == 'J';
bds = sys == 'C';
irn = sys == 'I';
sbs = sys == 'S';

sat = NaN(length(sys), 1);
sat(gps) = const.PRN2SAT_GPS(prn(gps));
sat(glo) = const.PRN2SAT_GLO(prn(glo));
sat(gal) = const.PRN2SAT_GAL(prn(gal));
sat(qzs) = const.PRN2SAT_QZS(prn(qzs) - const.PRN_QZS(1) + 1);
sat(bds) = const.PRN2SAT_BDS(prn(bds));
sat(irn) = const.PRN2SAT_IRN(prn(irn));
sat(sbs) = const.PRN2SAT_SBS(prn(sbs) - const.PRN_SBS(1) + 1);