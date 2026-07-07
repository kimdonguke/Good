clear; clc; close all;

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

Hor = readtable("data.xlsx",'Sheet',1);
Vert = readtable("data.xlsx",'Sheet',2);
Pos = readtable("data.xlsx",'Sheet',3);

Hor_Error = sqrt(Hor.East_Error.^2+Hor.North_Error.^2);
Pos_Error = sqrt(Pos.East_Error.^2+Pos.North_Error.^2+Pos.Up_Error.^2);

Hor_threshold = 0.1;
Ver_threshold = 0.2;
Pos_threshhold = sqrt(Hor_threshold^2 + Ver_threshold^2);


%%
figure;
gx = geoaxes;
hold on;
for k = 1:size(netrts,1)
    pg = geopolyshape(netrts.LAT(k, [1 2 3 1]), netrts.LON(k, [1 2 3 1]));
    geoplot(gx, pg, 'k', 'EdgeColor', 'k', 'HandleVisibility', 'off')
end

geoplot(Hor.Station_Lat(32),Hor.Station_Lon(32),'ks','LineWidth',2,'MarkerFaceColor','y','MarkerSize',8);
geoplot(Hor.Point_Lat(32:39),Hor.Point_Lon(32:39),'r^','MarkerFaceColor','r');