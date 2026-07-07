clear; clc;
% ---- 프로젝트 경로 자동 설정 (절대경로 → 상대경로: 어느 PC에서든 동작) ----
thisDir = fileparts(mfilename('fullpath'));
if isempty(thisDir); thisDir = pwd; end
projectRoot = thisDir;
while ~isfolder(fullfile(projectRoot, 'Src'))
    parentDir = fileparts(projectRoot);
    if isempty(parentDir) || strcmp(parentDir, projectRoot); projectRoot = thisDir; break; end
    projectRoot = parentDir;
end
ngiiPaths = {thisDir, projectRoot, fullfile(projectRoot,'Src'), ...
    fullfile(projectRoot,'Src','Reference Code'), ...
    fullfile(projectRoot,'Data','rts'), fullfile(projectRoot,'dd')};
for pIdx = 1:numel(ngiiPaths)
    if isfolder(ngiiPaths{pIdx}); addpath(ngiiPaths{pIdx}); end
end
% -------------------------------------------------------------------------
load('netRts.mat');
MS = readtable('Main_Station.xlsx');
load("Net_data.mat");

for i = 1:height(MS)
    xq = table2array(MS(i,2));
    yq = table2array(MS(i,3));
    for j=1:height(Net_H)
        xv = table2array(Net_H(j,11:13));
        yv = table2array(Net_H(j,14:16));
        [in,on] = inpolygon(xq, yq, [xv xv(1)], [yv yv(1)]);
        in_H(i,j) = in & ~on;
    end
end
[row,col] = find(in_H == 1);

mt = [col,row];

a = MS(row,:);
b = Net_H(col,:);
a_array = table2array(a(:,2:end));


for i=1:height(a)
    LLA(i,1:3) = lla2enu(a_array(i,1:3),a_array(i,7:9),'ellipsoid');
    LLA(i,4:6) = a_array(i,4:6);
    baseline(i,1) = norm(LLA(i,1:3));
end
%%
for i = 1:height(MS)
    xq = table2array(MS(i,2));
    yq = table2array(MS(i,3));
    for j=1:height(Net_V)
        xv = table2array(Net_V(j,11:13));
        yv = table2array(Net_V(j,14:16));
        [in,on] = inpolygon(xq, yq, [xv xv(1)], [yv yv(1)]);
        in_V(i,j) = in & ~on;
    end
end
[row1,col1] = find(in_V == 1);

mt1 = [col1,row1];

a1 = MS(row1,:);
b1 = Net_V(col1,:);

a1_array = table2array(a1(:,2:end));

for i=1:height(a1)
    LLA1(i,1:3) = lla2enu(a1_array(i,1:3),a1_array(i,7:9),'ellipsoid');
    LLA1(i,4:6) = a1_array(i,4:6);
    baseline1(i,1) = norm(LLA1(i,1:3));
end

%%
for k = 1:height(MS)
    xq = table2array(MS(k,2));
    yq = table2array(MS(k,3));
    for l=1:height(Net_P)
        xv = table2array(Net_P(l,11:13));
        yv = table2array(Net_P(l,14:16));
        [in,on] = inpolygon(xq, yq, [xv xv(1)], [yv yv(1)]);
        in_P(k,l) = in & ~on;
    end
end
[row2,col2] = find(in_P == 1);

mt2 = [col2,row2];

a2 = MS(row2,:);
b2 = Net_P(col2,:);

a2_array = table2array(a2(:,2:end));

for k=1:height(a2)
    LLA2(k,1:3) = lla2enu(a2_array(k,1:3),a2_array(k,7:9),'ellipsoid');
    LLA2(k,4:6) = a2_array(k,4:6);
    baseline2(k,1) = norm(LLA2(k,1:3));
end