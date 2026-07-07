function [sol] = combsol(solf, solb)
% ==================================================================================================
% COMBSOL
%   combine forward and backward solutions
% ==================================================================================================

global const

nepoch = length(solf.time);
if (nepoch ~= length(solb.time))
    fprintf('# of forward and backward solutions are different\n'); sol = []; return;
end

sol = initsol(nepoch);

% smoothed solution
k = (solf.stat == solb.stat) & (solf.stat ~= const.SOLQ_NONE & solb.stat ~= const.SOLQ_NONE);

sol.time(k)     = solf.time(k) - (solf.time(k) - solb.time(k))/2;
sol.dtr(k, 1:5) = solf.dtr(k, 1:5);
sol.stat(k)     = solf.stat(k);
sol.sataz(k,:)  = solf.sataz(k,:);
sol.satel(k,:)  = solf.satel(k,:);
sol.nsat(k)     = solf.nsat(k);
sol.age(k)      = solf.age(k);
sol.dop(k, 1:4) = solf.dop(k, 1:4);

[sol.rr(k, 1:3), sol.qr(k, 1:6)] = smoother(solf.rr(k, 1:3), solf.qr(k, 1:6), solb.rr(k, 1:3), solb.qr(k, 1:6));

% smoothed solution with forward and backward filter solutions -------------------------------------
function [xs, qs] = smoother(xf, qf, xb, qb)

nepoch = size(xf, 1);

xs = NaN(nepoch, 3);
qs = NaN(nepoch, 6);

for i = 1:nepoch
    Qf = diag(qf(i, 1:3));
    Qf(1, 2) = qf(i, 4);
    Qf(2, 1) = qf(i, 4);
    Qf(2, 3) = qf(i, 5);
    Qf(3, 2) = qf(i, 5);
    Qf(1, 3) = qf(i, 6);
    Qf(3, 1) = qf(i, 6);
    
    Qb = diag(qb(i, 1:3));
    Qb(1, 2) = qb(i, 4);
    Qb(2, 1) = qb(i, 4);
    Qb(2, 3) = qb(i, 5);
    Qb(3, 2) = qb(i, 5);
    Qb(1, 3) = qb(i, 6);
    Qb(3, 1) = qb(i, 6);
    
    Q = inv(inv(Qf) + inv(Qb));
    
    xs(i, 1:3) = (Q*(Qf\xf(i, 1:3)' + Qb\xb(i, 1:3)'))'; %#ok<MINV>
    qs(i, 1:6) = [diag(Q(1:3, 1:3))', Q(1, 2), Q(2, 3), Q(3, 1)];
end