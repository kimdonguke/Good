%% 최적화 망 + 타기관 상시관측소(CORS) 오버레이 — 저장된 결과 로드해서 실행
%  빨강 셀 = 타기관 CORS가 속한 셀. (타기관 CORS는 우리 로직에 영향 없음, 표시만)
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
optDir = fileparts(thisDir);            % 망최적화 폴더 (알고리즘·결과 파일)
ngiiPaths = {thisDir, optDir, projectRoot, fullfile(projectRoot,'Src'), ...
    fullfile(projectRoot,'Src','Reference Code'), fullfile(projectRoot,'Data','rts'), fullfile(projectRoot,'dd')};
for pIdx = 1:numel(ngiiPaths)
    if isfolder(ngiiPaths{pIdx}); addpath(ngiiPaths{pIdx}); end
end
% ---------------------------------

%% 저장된 최적화 결과 로드  (← 'result_greedy.mat' 로 바꾸면 그리디 결과)
resultFile = fullfile(optDir, 'result_ilp.mat');
if ~isfile(resultFile)
    error(['결과 파일이 없습니다:\n  %s\n먼저 run_ilp_area_max.m (또는 run_greedy_area_max.m)을 실행하세요.'], resultFile);
end
Rr = load(resultFile); R = Rr.R;
lon = R.lon; lat = R.lat; isRef = R.isRef;
lonR = lon(isRef);  latR = lat(isRef);
lonM = lon(~isRef); latM = lat(~isRef);
DT = delaunayTriangulation(lonR, latR); CL = DT.ConnectivityList;

%% 타기관 상시관측소(CORS) + 셀 배정
[cors_lat, cors_lon] = cors_stations();
tri_cors = pointLocation(DT, cors_lon, cors_lat);
inNet = ~isnan(tri_cors);
cors_cells = unique(tri_cors(inNet));
gray_tri = setdiff((1:size(CL,1))', cors_cells);

fprintf('\n===== 타기관 상시관측소 오버레이 (%s 결과) =====\n', R.method);
fprintf('최적화 망: 기준국 %d, 감시국 %d\n', R.nRef, R.nMon);
fprintf('타기관 CORS %d개 중 망 내부 %d개 (셀 %d개), 망 밖 %d개\n', ...
        numel(cors_lat), sum(inNet), numel(cors_cells), sum(~inNet));
fprintf('===================================================\n\n');

%% 플롯 (geobasemap 지형도)
figure('Name','최적화 망 + 타기관 CORS','Color','w','Position',[80 80 960 720]);
gx = geoaxes; geobasemap(gx,'topographic'); hold(gx,'on');
for i = 1:numel(gray_tri)
    n = CL(gray_tri(i),:);
    geoplot(gx, geopolyshape([latR(n);latR(n(1))],[lonR(n);lonR(n(1))]),'k','EdgeColor','k','HandleVisibility','off');
end
for i = 1:numel(cors_cells)
    n = CL(cors_cells(i),:);
    geoplot(gx, geopolyshape([latR(n);latR(n(1))],[lonR(n);lonR(n(1))]),'EdgeColor','k','LineWidth',0.5,'FaceColor','r','FaceAlpha',0.3,'HandleVisibility','off');
end
E = edges(DT);
lat_e = [latR(E(:,1)), latR(E(:,2)), NaN(size(E,1),1)]';
lon_e = [lonR(E(:,1)), lonR(E(:,2)), NaN(size(E,1),1)]';
geoplot(gx, lat_e(:), lon_e(:), 'k-','LineWidth',0.5,'HandleVisibility','off');
geoplot(gx, latR, lonR, 'ks','MarkerFaceColor','y','MarkerSize',6);
geoplot(gx, latM, lonM, 'k^','MarkerFaceColor','b','MarkerSize',5);
geoplot(gx, cors_lat, cors_lon, 'kv','MarkerFaceColor','m','MarkerSize',7);
legend(gx, {'기준국(Reference)','감시국(Monitor)','타기관 상시관측소(CORS)'}, 'Location','northeast');
title(gx, sprintf('[%s] 최적화 망 + 타기관 CORS (기준국 %d, 감시국 %d, CORS %d)', ...
      R.method, R.nRef, R.nMon, numel(cors_lat)));
geolimits(gx, [33 39], [125 132]); hold(gx,'off');

% ---- PNG 자동 저장 (result_fig) ----
figSave = fullfile(optDir,'result_fig');
if ~isfolder(figSave); mkdir(figSave); end
drawnow;
print(gcf, fullfile(figSave, sprintf('cors_overlay_%s.png', R.method)), '-dpng', '-r200');
fprintf('그림 저장: %s\n', fullfile(figSave, sprintf('cors_overlay_%s.png', R.method)));
