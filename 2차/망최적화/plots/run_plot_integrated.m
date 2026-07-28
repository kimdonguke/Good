%% 통합 감시 커버리지 = (우리 감시국) ∪ (타기관 상설감시국 CORS)
%  저장된 결과(result_ilp.mat / result_greedy.mat)를 로드해서 실행.
%  빨강 = 우리 감시국 커버 셀,  초록 = 타기관 CORS 추가 커버 셀,  회색 = 미감시.
%  타기관 데이터 = load_cors_external (고시 xlsx) — run_plot_cors 와 단일 출처.
%  (구 cors_stations.m 하드코딩 38국은 legacy — 산출 그림 간 불일치 원인이라 대체)
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
lon = R.lon; lat = R.lat; isRef = logical(R.isRef);
lonR = lon(isRef);  latR = lat(isRef);
lonM = lon(~isRef); latM = lat(~isRef);          % 우리 감시국
DT = delaunayTriangulation(lonR, latR); CL = DT.ConnectivityList;

%% 타기관 상설감시국(CORS) — 고시 xlsx 단일 출처 (외부 기관만)
C = load_cors_external();
ext = C(C.agency ~= "국토지리정보원", :);
cors_lat = ext.lat;  cors_lon = ext.lon;

%% 셀 배정 (두 감시원) — 유효셀 판정은 QC 감시 인정 마스크(monOK) 적용
monOK = true(numel(lon),1);
if isfield(R, 'monOK'); monOK = logical(R.monOK(:)); end
lonMv = lon(~isRef & monOK); latMv = lat(~isRef & monOK);
tri_ours = pointLocation(DT, lonMv, latMv);       tri_ours = tri_ours(~isnan(tri_ours));
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
fig = figure('Name','통합 감시 커버리지','Color','w','Position',[80 80 960 720]);
gx = geoaxes(fig);
try
    geobasemap(gx,'topographic');   % 오프라인/헤드리스에서는 기본 축으로 대체
catch
end
hold(gx,'on');
% 셀 렌더: 색 클래스별 NaN 구분 멀티리전 geopolyshape 1개 (셀별 geoplot 반복 제거)
plot_cells_batch(gx, latR, lonR, CL(gray_tri,:), 'k','EdgeColor','k','HandleVisibility','off');   % 회색: 미감시
hCellMon = plot_cells_batch(gx, latR, lonR, CL(cells_ours,:), ...      % 빨강: 우리 감시국 커버
    'EdgeColor','k','LineWidth',0.5,'FaceColor','r','FaceAlpha',0.3,'HandleVisibility','off');
hCellExt = plot_cells_batch(gx, latR, lonR, CL(cells_corsOnly,:), ...  % 초록: CORS 추가 커버 (관례색 [0 0.7 0.2]·α0.3)
    'EdgeColor','k','LineWidth',0.5,'FaceColor',[0 0.7 0.2],'FaceAlpha',0.3,'HandleVisibility','off');
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
exportgraphics(fig, fullfile(figSave, sprintf('integrated_coverage_%s.png', R.method)), 'Resolution', 200);
fprintf('그림 저장: %s\n', fullfile(figSave, sprintf('integrated_coverage_%s.png', R.method)));

% ======================================================================
function h = plot_cells_batch(gx, latR, lonR, CLsub, varargin)
% 삼각형 셀 집합을 geopolyshape 객체 배열 + geoplot 1회로 렌더 (셀별 geoplot 반복 제거)
%   NaN 멀티리전 1개 합치기는 변 공유 삼각형이 even-odd 구멍 처리(체커보드) — 금지.
    h = gobjects(0);
    if isempty(CLsub); return; end
    shp = arrayfun(@(i) geopolyshape([latR(CLsub(i,:)); latR(CLsub(i,1))], ...
                                     [lonR(CLsub(i,:)); lonR(CLsub(i,1))]), (1:size(CLsub,1))');
    h = geoplot(gx, shp, varargin{:});
end

% ======================================================================
function A = cellAreaWgs(CL, cells, lonR, latR)
    A = 0;
    for i = 1:numel(cells)
        n = fliplr(CL(cells(i),:));
        A = A + area(geopolyshape([latR(n);latR(n(1))],[lonR(n);lonR(n(1))]))/1e6;
    end
end
