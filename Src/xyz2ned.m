function ned = xyz2ned(xyz, orgxyz)

llh = xyz2llh(orgxyz);

slat = sin(llh(1));
clat = cos(llh(1));
slon = sin(llh(2));
clon = cos(llh(2));

R = [  -slat*clon  -slat*slon   clat; ...
       -slon          clon         0; ... 
       -clat*clon  -clat*slon  -slat];

[MAX, N] = size(xyz);
ned = zeros(MAX, N);

for i=1:MAX
    ned_t = R * (xyz(i, :) - orgxyz)' ;
    ned(i, :) = ned_t';
end
