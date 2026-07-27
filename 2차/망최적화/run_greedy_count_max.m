%% [A] 감시가능망 "개수" 최대화 - 기준국->감시국 그리디 (실행/시각화)
%   유효셀(감시국 포함 셀) 개수를 최대화. 시각화는 NRTK_with_CORS.m 스타일 동일. 
clear; clc;

% ---- 프로젝트 경로 자동 설정 ----
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
% ---------------------------------

%% 데이터 로드 (위성기준점 99개소)
rtsStations = struct2table(shaperead('위성기준점(99개소).shp'));
rtsStations.Properties.VariableNames = {'Geometry','X_proj','Y_proj','FID1','FID2', ...
    'Name','RINEX','LAT_dms','LON_dms','Height','X1','Y1','Proj','None1','None2'}';
latParts = cellfun(@(x) str2double(strsplit(x,'-')), rtsStations.LAT_dms, 'UniformOutput', false);
lonParts = cellfun(@(x) str2double(strsplit(x,'-')), rtsStations.LON_dms, 'UniformOutput', false);
validDMS = ~cellfun('isempty', latParts) & ~cellfun('isempty', lonParts);
rtsStations.LAT_deg(validDMS) = cellfun(@(x) dms2deg(x'), latParts(validDMS));
rtsStations.LON_deg(validDMS) = cellfun(@(x) dms2deg(x'), lonParts(validDMS));
lon = rtsStations.LON_deg(validDMS);
lat = rtsStations.LAT_deg(validDMS);

%% 그리디 실행 (objective = count)
maxBaseKm = 100;
[isRef, info] = greedy_monitor_net(lon, lat, maxBaseKm, 0.5, 'count');

nInit = numel(lon); nRef = sum(isRef); nMon = nInit - nRef;
[total_area, nCells, DT, red_tri, lonR, latR] = valid_net_wgs84(lon, lat, isRef);
lonM = lon(~isRef); latM = lat(~isRef);
CL = DT.ConnectivityList;
gray_tri = setdiff((1:size(CL,1))', red_tri);

fprintf('\n===== [A] 감시가능망 개수 최대화 (그리디) =====\n');
fprintf('초기 기준국        : %d개\n', nInit);
fprintf('최적화 후 기준국   : %d개\n', nRef);
fprintf('전환된 감시국(제거): %d개\n', nMon);
fprintf('감시 가능(유효) 셀 : %d개  <-- 최대화 대상\n', nCells);
fprintf('참고: 감시 가능 망 면적 : %.2f km^2 (WGS84)\n', total_area);
fprintf('==============================================\n\n');

%% 시각화 (NRTK_with_CORS.m 스타일 동일)
figure('Name','감시가능망 개수 최대화','Color','w','Position',[80 80 960 720]);
gx = geoaxes; geobasemap(gx,'topographic'); hold(gx,'on');
for i = 1:numel(gray_tri)
    nodes = CL(gray_tri(i),:);
    geoplot(gx, geopolyshape([latR(nodes);latR(nodes(1))],[lonR(nodes);lonR(nodes(1))]), ...
        'k','EdgeColor','k','HandleVisibility','off');
end
for i = 1:numel(red_tri)
    nodes = CL(red_tri(i),:);
    geoplot(gx, geopolyshape([latR(nodes);latR(nodes(1))],[lonR(nodes);lonR(nodes(1))]), ...
        'EdgeColor','k','LineWidth',0.5,'FaceColor','r','FaceAlpha',0.3,'HandleVisibility','off');
end
E = edges(DT);
lat_e = [latR(E(:,1)), latR(E(:,2)), NaN(size(E,1),1)]';
lon_e = [lonR(E(:,1)), lonR(E(:,2)), NaN(size(E,1),1)]';
geoplot(gx, lat_e(:), lon_e(:), 'k-','LineWidth',0.5,'HandleVisibility','off');
geoplot(gx, latR, lonR, 'ks','MarkerFaceColor','y','MarkerSize',6);
geoplot(gx, latM, lonM, 'k^','MarkerFaceColor','b','MarkerSize',5);
legend(gx, {'기준국(Reference)','감시국(Monitor)'}, 'Location','northeast');
title(gx, '감시가능망 개수 최대화 — 그리디');
geolimits(gx, [33 39], [125 131]); hold(gx,'off');

%% 수렴 곡선 (기준국 수 vs 유효셀 개수)
figure('Name','개수 수렴 곡선','Color','w','Position',[80 80 960 720]);
plot(info.nRefHist, info.Ncells, '-o','LineWidth',1.2,'MarkerSize',4);
set(gca,'XDir','reverse'); grid on;
xlabel('기준국 수 (전환 진행 →)'); ylabel('유효셀 개수');
title('전환에 따른 감시가능망 개수 변화');
