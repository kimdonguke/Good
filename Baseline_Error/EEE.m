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

MS = readtable('Main_Station.xlsx');
load('netRts.mat');
% HH = readtable('Main_Station_Network.xlsx');


H_error = sqrt(MS.East_Error.^2 + MS.North_Error.^2);

idx_H_logical = (H_error >= 0.1) & (abs(MS.Up_Error) < 0.2);
idx_V_logical = (H_error < 0.1) & (abs(MS.Up_Error) >= 0.2);
idx_P_logical = (H_error >= 0.1) & (abs(MS.Up_Error) >= 0.2);
% H,P 8행, 10행 / 
H = MS(idx_H_logical,:);
V = MS(idx_V_logical,:);
P = MS(idx_P_logical,:);


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







% idx_H = [];
% idx_V = [];
% idx_P = [];

% for i = 1:height(H)
%     for j=1:height(MS)
%         if MS.Station_h(j) == H.Station_h(i)
%             idx_H(end+1,1:2) = [i,j];
%         end
%     end
% end
% for i = 1:height(V)
%     for j=1:height(MS)
%         if MS.Station_h(j) == V.Station_h(i)
%             idx_V(end+1,1:2) = [i,j];
%         end
%     end
% end
% for i = 1:height(P)
%     for j=1:height(MS)
%         if MS.Station_h(j) == P.Station_h(i)
%             idx_P(end+1,1:2) = [i,j];
%         end
%     end
% end
% MS_H = MS(idx_H(:,2),:);
% MS_V = MS(idx_V(:,2),:);
% MS_P = MS(idx_P(:,2),:);

% figure;
% gx = geoaxes;
% hold on;
% for k = 1:size(netrts,1)
%     pg = geopolyshape(netrts.LAT(k, [1 2 3 1]), netrts.LON(k, [1 2 3 1]));
%     geoplot(gx, pg, 'k', 'EdgeColor', 'k', 'HandleVisibility', 'off')
% end
% geoplot(MS.Station_Lat,MS.Station_Lon,'ks','MarkerSize',8,'MarkerFaceColor','y','LineWidth',2);
% geoplot(H.Station_Lat,H.Station_Lon,'ks','MarkerSize',8,'MarkerFaceColor','y','LineWidth',2);
% geoplot(MS_H.Point_Lat,MS_H.Point_Lon,'b^','MarkerSize',6,'MarkerFaceColor','b');
% geoplot(H.Point_Lat,H.Point_Lon,'r^','MarkerSize',6,'MarkerFaceColor','r');

% for i = 1:height(MS_H)
%     xq = table2array(MS_H(i,2));
%     yq = table2array(MS_H(i,3));
%     for j=1:height(HH)
%         xv = table2array(HH(j,11:13));
%         yv = table2array(HH(j,14:16));
%         in_H(i,j) = inpolygon(xq, yq, [xv xv(1)], [yv yv(1)]);
%     end
% end
% 
% 
% 
