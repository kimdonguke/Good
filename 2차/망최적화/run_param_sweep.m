%% [B] 파라미터 스윕 - 감시가능망 면적 최대화 그리디 (30 조합)
%   maxBaseKm(6) x boundaryShrink(5) = 30회 시도, 결과 표/CSV/히트맵 기록.
%   [legacy] 구 99개소 shp·자체 조건 기준 — 현행 공식 파이프라인(stations_ngii.mat
%   102국, net_config·outerForce·qc_rules)과 결과 비교 불가. 참고 보존용.
close all; clear; clc;

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
nInit = numel(lon);

%% 파라미터 격자 (6 x 5 = 30)
kmVals     = [80 90 100 110 120 130];
shrinkVals = [0.00 0.25 0.50 0.75 1.00];
nKm = numel(kmVals); nSh = numel(shrinkVals);

AREA = zeros(nSh, nKm);   % 유효면적 (km^2, WGS84)
NREF = zeros(nSh, nKm);   % 최종 기준국 수
NCEL = zeros(nSh, nKm);   % 유효셀 수

trial = 0;
rows = strings(0,1);
T_km = []; T_sh = []; T_nref = []; T_nmon = []; T_ncell = []; T_area = [];

fprintf('\n===== [B] 파라미터 스윕 (30 조합) =====\n');
fprintf('%3s | %7s %6s | %5s %5s %6s %12s\n','#','maxKm','shrink','nRef','nMon','nCell','area(km^2)');
fprintf('%s\n', repmat('-',1,58));
for s = 1:nSh
    for k = 1:nKm
        trial = trial + 1;
        [isRef, ~] = greedy_monitor_net(lon, lat, kmVals(k), shrinkVals(s), 'area');
        [aKm2, nCell] = valid_net_wgs84(lon, lat, isRef);
        nRef = sum(isRef); nMon = nInit - nRef;

        AREA(s,k) = aKm2;  NREF(s,k) = nRef;  NCEL(s,k) = nCell;
        T_km(end+1,1)=kmVals(k); T_sh(end+1,1)=shrinkVals(s); %#ok<AGROW>
        T_nref(end+1,1)=nRef; T_nmon(end+1,1)=nMon; T_ncell(end+1,1)=nCell; T_area(end+1,1)=aKm2; %#ok<AGROW>
        fprintf('%3d | %7g %6.2f | %5d %5d %6d %12.1f\n', trial, kmVals(k), shrinkVals(s), nRef, nMon, nCell, aKm2);
    end
end

% 결과 표 저장 (CSV)
Ttab = table(T_km, T_sh, T_nref, T_nmon, T_ncell, T_area, ...
    'VariableNames', {'maxBaseKm','boundaryShrink','nRef','nMon','nValidCells','area_km2'});
csvPath = fullfile(thisDir, 'sweep_results.csv');
writetable(Ttab, csvPath);
fprintf('%s\n', repmat('-',1,58));
[bestA, bi] = max(T_area);
fprintf('최대 면적: %.1f km^2  (maxKm=%g, shrink=%.2f, nRef=%d)\n', ...
    bestA, T_km(bi), T_sh(bi), T_nref(bi));
fprintf('CSV 저장: %s\n', csvPath);
fprintf('=======================================\n\n');

%% 히트맵 시각화
figure('Name','파라미터 스윕 요약','Color','w','Position',[100 100 1100 420]);
tl = tiledlayout(1,2,'TileSpacing','compact','Padding','compact');
title(tl,'감시가능 면적 파라미터 스윕 — 기선 상한 × 외곽 축소');

nexttile;
imagesc(1:nKm, 1:nSh, AREA); axis xy; colorbar; colormap(gca,'parula');
set(gca,'XTick',1:nKm,'XTickLabel',string(kmVals),'YTick',1:nSh,'YTickLabel',string(shrinkVals));
xlabel('maxBaseKm (기선 상한, km)'); ylabel('boundaryShrink'); title('유효면적 (km^2, WGS84)');
for s=1:nSh, for k=1:nKm, text(k,s,sprintf('%.0f',AREA(s,k)),'HorizontalAlignment','center','FontSize',8); end, end

nexttile;
imagesc(1:nKm, 1:nSh, NREF); axis xy; colorbar; colormap(gca,'parula');
set(gca,'XTick',1:nKm,'XTickLabel',string(kmVals),'YTick',1:nSh,'YTickLabel',string(shrinkVals));
xlabel('maxBaseKm (기선 상한, km)'); ylabel('boundaryShrink'); title('최종 기준국 수');
for s=1:nSh, for k=1:nKm, text(k,s,sprintf('%d',NREF(s,k)),'HorizontalAlignment','center','FontSize',8); end, end
