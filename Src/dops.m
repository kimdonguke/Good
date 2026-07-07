function dop = dops(azel, elmask)

az = azel(:,1);
el = azel(:,2);

H(:,1) = cos(el).*sin(az);
H(:,2) = cos(el).*cos(az);
H(:,3) = sin(el);
H(:,4) = ones(size(az));

H = H(el >= elmask,:);
Q = inv(H'*H);

dop = NaN(1, 4);
dop(1) = sqrt(sum(diag(Q)));                % GDOP
dop(2) = sqrt(Q(1, 1) + Q(2, 2) + Q(3, 3)); % PDOP
dop(3) = sqrt(Q(1, 1) + Q(2, 2));           % HDOP
dop(4) = sqrt(Q(3, 3));                     % VDOP