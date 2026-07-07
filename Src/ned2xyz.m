%% ned2xyz
function xyz = ned2xyz(ned, orgxyz)

llh = xyz2llh(orgxyz);

slat = sin(llh(1));
clat = cos(llh(1));
slon = sin(llh(2));
clon = cos(llh(2));

R = [  -slat*clon  -slat*slon   clat; ...
       -slon          clon         0; ... 
       -clat*clon  -clat*slon  -slat];

[MAX, N] = size(ned);
xyz = zeros(MAX, N);

for i=1:MAX
    
    xyz_t = orgxyz' + R' * ned(i, :)';
    xyz (i, :) = xyz_t';
end

end
