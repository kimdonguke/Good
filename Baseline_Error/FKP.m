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

load('FKP_RTCM31.mat'); % 위성기준점
load('result.mat'); % 검증측량지점
MS = readtable('Main_Station.xlsx');



figure;
gx = geoaxes;
geobasemap(gx, 'topographic')
hold(gx, 'on')
geolimits([33 39], [124 132])
geobasemap streets;

% Plot NGII CORS Networks (polygons)
for k = 1:size(netrts,1)
    pg = geopolyshape(netrts.LAT(k, [1 2 3 1]), netrts.LON(k, [1 2 3 1]));
    geoplot(gx, pg, 'k', 'EdgeColor', 'k', 'HandleVisibility', 'off')
end

geoplot(rtsStations.LAT_deg, rtsStations.LON_deg, 'gs', 'color', 'k',...
    'MarkerFaceColor','y', 'LineWidth', 1, 'MarkerSize', 6, 'HandleVisibility', 'off');

geoplot(MS.Point_Lat(:),MS.Point_Lon(:),'b^','MarkerFaceColor','b', 'LineWidth', 1, 'MarkerSize', 5);


