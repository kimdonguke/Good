%% 통합 감시 커버리지 = (우리 감시국) ∪ (타기관 상시관측소 CORS)
%  저장된 결과(result_ilp.mat / result_greedy.mat)를 로드해서 실행.
%  빨강 = 우리 감시국 커버 셀,  초록 = 타기관 CORS 추가 커버 셀,  회색 = 미감시.
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

%% 저장된 최적화 결과 로드  (← 'result_greedy.mat' 로 바꾸면 그리디 결과로 플롯)
resultFile = fullfile(optDir, 'result_ilp.mat');
if ~isfile(resultFile)
    error(['결과 파일이 없습니다:\n  %s\n먼저 run_ilp_area_max.m (또는 run_greedy_area_max.m)을 실행하세요.'], resultFile);
end
Rr = load(resultFile); R = Rr.R;
lon = R.lon; lat = R.lat; isRef = R.isRef;
lonR = lon(isRef);  latR = lat(isRef);
lonM = lon(~isRef); latM = lat(~isRef);          % 우리 감시국
DT = delaunayTriangulation(lonR, latR); CL = DT.ConnectivityList;

%% 타기관 상시관측소(CORS)
[cors_lat, cors_lon] = cors_stations();

%% 셀 배정 (두 감시원)
tri_ours = pointLocation(DT, lonM, latM);         tri_ours = tri_ours(~isnan(tri_ours));
tri_cors = pointLocation(DT, cors_lon, cors_lat); corsIn = ~isnan(tri_cors); tri_cors = tri_cors(corsIn);
cells_ours     = unique(tri_ours);                 % 우리 감시국 커버 셀
cells_cors     = unique(tri_cors);                 % 타기관 CORS 커버 셀
cells_corsOnly = setdiff(cells_cors, cells_ours);  % CORS가 "추가로" 커버
cells_union    = union(cells_ours, cells_cors);    % 통합 감시 셀
gray_tri       = setdiff((1:size(CL,1))', cells_union);

%% 면적 (WGS84)
areaOurs    = cellAreaWgs(CL, cells_ours,     lonR, latR);
areaUnion   = cellAreaWgs(CL, cells_union,    lonR, latR);
areaCorsAdd = cellAreaWgs(CL, cells_corsOnly, lonR, latR);

fprintf('\n===== 통합 감시 커버리지 (%s 결과) =====\n', R.method);
fprintf('기준국 %d, 우리 감시국 %d, 타기관 CORS %d (망 내부 %d)\n', ...
        R.nRef, R.nMon, numel(cors_lat), sum(corsIn));
fprintf('셀:  우리 %d + CORS추가 %d = 통합 %d개\n', numel(cells_ours), numel(cells_corsOnly), numel(cells_union));
fprintf('면적: 우리 %.0f + CORS추가 %.0f = 통합 %.0f km^2\n', areaOurs, areaCorsAdd, areaUnion);
fprintf('  → 타기관 CORS로 추가 확보: %.0f km^2 (우리 대비 +%.1f%%)\n', areaCorsAdd, 100*areaCorsAdd/max(areaOurs,eps));
fprintf('=================================================\n\n');

%% 플롯 (geobasemap 지형도)
figure('Name','통합 감시 커버리지','Color','w','Position',[80 80 960 720]);
gx = geoaxes; geobasemap(gx,'topographic'); hold(gx,'on');
for i = 1:numel(gray_tri)               % 회색: 미감시
    n = CL(gray_tri(i),:);
    geoplot(gx, geopolyshape([latR(n);latR(n(1))],[lonR(n);lonR(n(1))]),'k','EdgeColor','k','HandleVisibility','off');
end
hCellMon = gobjects(0);  hCellExt = gobjects(0);
for i = 1:numel(cells_ours)             % 빨강: 우리 감시국 커버
    n = CL(cells_ours(i),:);
    h = geoplot(gx, geopolyshape([latR(n);latR(n(1))],[lonR(n);lonR(n(1))]),'EdgeColor','k','LineWidth',0.5,'FaceColor','r','FaceAlpha',0.30,'HandleVisibility','off');
    if i == 1; hCellMon = h; end
end
for i = 1:numel(cells_corsOnly)         % 초록: CORS 추가 커버
    n = CL(cells_corsOnly(i),:);
    h = geoplot(gx, geopolyshape([latR(n);latR(n(1))],[lonR(n);lonR(n(1))]),'EdgeColor','k','LineWidth',0.5,'FaceColor',[0 0.7 0.3],'FaceAlpha',0.45,'HandleVisibility','off');
    if i == 1; hCellExt = h; end
end
E = edges(DT);
lat_e = [latR(E(:,1)), latR(E(:,2)), NaN(size(E,1),1)]';
lon_e = [lonR(E(:,1)), lonR(E(:,2)), NaN(size(E,1),1)]';
geoplot(gx, lat_e(:), lon_e(:), 'k-','LineWidth',0.5,'HandleVisibility','off');
hh = gobjects(3,1);
hh(1) = geoplot(gx, latR, lonR, 'ks','MarkerFaceColor','y','MarkerSize',6);
hh(2) = geoplot(gx, latM, lonM, 'k^','MarkerFaceColor','b','MarkerSize',5);
hh(3) = geoplot(gx, cors_lat, cors_lon, 'kv','MarkerFaceColor','m','MarkerSize',7);
lbl = {sprintf('기준국 (%d개소)', R.nRef), sprintf('감시국 (%d개소)', R.nMon), ...
       sprintf('타기관 CORS (%d개소)', numel(cors_lat))};
cellH = gobjects(0,1);  cellL = {};
if ~isempty(hCellMon); cellH(end+1,1) = hCellMon; cellL{end+1} = '감시가능 셀 (감시국)'; end
if ~isempty(hCellExt); cellH(end+1,1) = hCellExt; cellL{end+1} = '추가 감시가능 셀 (타기관 CORS)'; end
legend(gx, [hh; cellH], [lbl(:); cellL(:)], 'Location','northeast');
title(gx, sprintf('통합 감시 커버리지 — %s 최적망 + 타기관 CORS', upper(R.method)));
geolimits(gx, [33 39], [125 132]); hold(gx,'off');

% ---- PNG 자동 저장 (result_fig/04_외부상설감시국) ----
figSave = fullfile(optDir,'result_fig','04_외부상설감시국');
if ~isfolder(figSave); mkdir(figSave); end
drawnow;
print(gcf, fullfile(figSave, sprintf('integrated_coverage_%s.png', R.method)), '-dpng', '-r200');
fprintf('그림 저장: %s\n', fullfile(figSave, sprintf('integrated_coverage_%s.png', R.method)));

% ======================================================================
function A = cellAreaWgs(CL, cells, lonR, latR)
    A = 0;
    for i = 1:numel(cells)
        n = fliplr(CL(cells(i),:));
        A = A + area(geopolyshape([latR(n);latR(n(1))],[lonR(n);lonR(n(1))]))/1e6;
    end
end
