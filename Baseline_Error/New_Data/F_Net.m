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

FKP = readtable('New_Data.xlsx');
load('netRts.mat');


H_error = sqrt(FKP.East_Error.^2 + FKP.North_Error.^2);

idx_H_logical = (H_error >= 0.1) & (abs(FKP.Up_Error) < 0.2);
idx_V_logical = (H_error < 0.1) & (abs(FKP.Up_Error) >= 0.2);
idx_P_logical = (H_error >= 0.1) & (abs(FKP.Up_Error) >= 0.2);
% H,P 8행, 10행 / 
H = FKP(idx_H_logical,:);
V = FKP(idx_V_logical,:);
P = FKP(idx_P_logical,:);


for j=1:height(H)
    for i=1:height(netrts)

        in(i,j) = inpolygon(H.Point_Lat(j),H.Point_Lon(j),netrts.LAT(i, [1 2 3 1]), netrts.LON(i, [1 2 3 1]));
    end
end
[row, col] = find(in==1);
tt = [col,row];
nett = table2array(netrts);

Net_H = H;
Net_H(:,11:16) = array2table(nett(tt(:,2),1:6));


for j=1:height(V)
    for i=1:height(netrts)

        in_V(i,j) = inpolygon(V.Point_Lat(j),V.Point_Lon(j),netrts.LAT(i, [1 2 3 1]), netrts.LON(i, [1 2 3 1]));
    end
end
[row_v, col_v] = find(in_V==1);
tt_V = [col_v,row_v];
 

Net_V = V;
Net_V(:,11:16) = array2table(nett(tt_V(:,2),1:6));

for j=1:height(P)
    for i=1:height(netrts)

        in_P(i,j) = inpolygon(P.Point_Lat(j),P.Point_Lon(j),netrts.LAT(i, [1 2 3 1]), netrts.LON(i, [1 2 3 1]));
    end
end
[row_p, col_p] = find(in_P==1);
tt_P = [col_p,row_p];
 

Net_P = P;
Net_P(:,11:16) = array2table(nett(tt_P(:,2),1:6));


