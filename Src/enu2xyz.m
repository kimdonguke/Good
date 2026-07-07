function xyz = enu2xyz(enu, refxyz)

llh = xyz2llh(refxyz);

lat = llh(:,1);
lon = llh(:,2);

sinlat = sin(lat);
sinlon = sin(lon);
coslat = cos(lat);
coslon = cos(lon);

rot_mat = [-sinlon           coslon           0; ...
           -sinlat*coslon   -sinlat*sinlon    coslat; ...
            coslat*coslon    coslat*sinlon    sinlat];

diffxyz = inv(rot_mat)*enu';

xyz = refxyz + diffxyz';
