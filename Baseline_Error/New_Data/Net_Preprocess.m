clear; clc;

load('Degradation_Point.mat');
FKP = readtable('New_Data.xlsx');

for i = 1:height(FKP)
    xq = table2array(FKP(i,2));
    yq = table2array(FKP(i,3));
    for j=1:height(Net_H)
        xv = table2array(Net_H(j,11:13));
        yv = table2array(Net_H(j,14:16));
        [in,on] = inpolygon(xq, yq, [xv xv(1)], [yv yv(1)]);
        in_H(i,j) = in & ~on;
    end
end
[row,col] = find(in_H == 1);

mt = [col,row];

a = FKP(row,:);
b = Net_H(col,:);
a_array = table2array(a(:,2:end));


for i=1:height(a)
    LLA(i,1:3) = lla2enu(a_array(i,1:3),a_array(i,7:9),'ellipsoid');
    LLA(i,4:6) = a_array(i,4:6);
    baseline(i,1) = norm(LLA(i,1:3));
end
%%
for i = 1:height(FKP)
    xq = table2array(FKP(i,2)); % 검증측량지점 위도
    yq = table2array(FKP(i,3)); % 검증측량지점 경도
    for j=1:height(Net_V)
        xv = table2array(Net_V(j,11:13)); % 성능저하지점 네트워크 (위도)
        yv = table2array(Net_V(j,14:16)); % 성능저하지점 네트워크 (경도)
        [in,on] = inpolygon(xq, yq, [xv xv(1)], [yv yv(1)]);
        in_V(i,j) = in & ~on;
    end
end
[row1,col1] = find(in_V == 1);

mt1 = [col1,row1];

a1 = FKP(row1,:);
b1 = Net_V(col1,:);

a1_array = table2array(a1(:,2:end));

for i=1:height(a1)
    LLA1(i,1:3) = lla2enu(a1_array(i,1:3),a1_array(i,7:9),'ellipsoid');
    LLA1(i,4:6) = a1_array(i,4:6);
    baseline1(i,1) = norm(LLA1(i,1:3));
end

%%
for k = 1:height(FKP)
    xq = table2array(FKP(k,2));
    yq = table2array(FKP(k,3));
    for l=1:height(Net_P)
        xv = table2array(Net_P(l,11:13));
        yv = table2array(Net_P(l,14:16));
        [in,on] = inpolygon(xq, yq, [xv xv(1)], [yv yv(1)]);
        in_P(k,l) = in & ~on;
    end
end
[row2,col2] = find(in_P == 1);

mt2 = [col2,row2];

a2 = FKP(row2,:);
b2 = Net_P(col2,:);

a2_array = table2array(a2(:,2:end));

for k=1:height(a2)
    LLA2(k,1:3) = lla2enu(a2_array(k,1:3),a2_array(k,7:9),'ellipsoid');
    LLA2(k,4:6) = a2_array(k,4:6);
    baseline2(k,1) = norm(LLA2(k,1:3));
end