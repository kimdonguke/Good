%% run_plot_cors.m — 최적화 망 + 외부 상설 감시국(기관별) 오버레이
%  데이터: Data/CORS_coordinate_최종본.xlsx (고시 ECEF X,Y,Z → GRS80 LLH 변환,
%          load_cors_external.m). 기관(mngr_nm)별로 마커·색을 구분해 표기한다.
%  - 국토지리정보원 소속국은 우리 위성기준점 계열(기준국/감시국으로 이미 표기)이라
%    오버레이에서 제외 — "외부" 7개 기관만 표시.
%  - 빨강 셀 = 외부 상설 감시국이 속한 최적화 망 셀 (우리 로직에 영향 없음, 표시만).
%  - status(ok/missing)는 콘솔 집계로만 보고하고 지도에는 전 지점 표기.
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
lon = R.lon; lat = R.lat; isRef = logical(R.isRef);
lonR = lon(isRef);  latR = lat(isRef);
lonM = lon(~isRef); latM = lat(~isRef);
DT = delaunayTriangulation(lonR, latR); CL = DT.ConnectivityList;

%% 외부 상설 감시국 로드 (고시 XYZ → LLH) + 셀 배정
[C, Raw] = load_cors_external();

% 변환 검증: xlsx 참고용 Lat/Lon 열과 대조 (있는 행만)
chk   = ~isnan(Raw.Lat) & ~isnan(Raw.Lon);
agree = chk & abs(C.lat-Raw.Lat) < 1e-4 & abs(C.lon-Raw.Lon) < 1e-4;   % ~10 m
subst = C.src == "xlsx_llh";                                            % XYZ 손상 → 참고열 대체
refBad = chk & ~agree & ~subst;                                         % 참고열 자체 이상 (변환값 사용)
fprintf('XYZ→LLH(GRS80) 검증: 참고열 일치(<1e-4 deg) %d행 / XYZ 손상→참고열 대체 %d행(%s) / 참고열 이상→변환값 사용 %d행(%s)\n', ...
    nnz(agree), nnz(subst), strjoin(C.station(subst), ','), ...
    nnz(refBad), strjoin(C.station(refBad), ','));

ext = C(C.agency ~= "국토지리정보원", :);           % 외부 기관만
agencies = unique(ext.agency);
tri_ext = pointLocation(DT, ext.lon, ext.lat);
inNet = ~isnan(tri_ext);
ext_cells = unique(tri_ext(inNet));
gray_tri = setdiff((1:size(CL,1))', ext_cells);

fprintf('\n===== 외부 상설 감시국 오버레이 (%s 결과) =====\n', R.method);
fprintf('최적화 망: 기준국 %d, 감시국 %d\n', R.nRef, R.nMon);
fprintf('외부 상설 감시국 %d개소(%d개 기관) 중 망 내부 %d개소 (셀 %d개), 망 밖 %d개소\n', ...
        height(ext), numel(agencies), nnz(inNet), numel(ext_cells), nnz(~inNet));
for a = agencies'
    m = ext.agency == a;
    fprintf('  %-14s 총 %3d (ok %3d / missing %3d), 망 내부 %3d\n', a, nnz(m), ...
        nnz(m & ext.status=="ok"), nnz(m & ext.status=="missing"), nnz(m & inNet));
end
fprintf('(국토지리정보원 소속 %d개소는 기준국/감시국으로 이미 표기되어 제외)\n', nnz(C.agency=="국토지리정보원"));
fprintf('===================================================\n\n');

%% 플롯 (960x720 표준, 기관별 마커·색)
agMk  = {'v','o','d','p','h','<','>'};                             % 기관별 마커
agCol = [0.84 0.37 0.00; 0.34 0.71 0.91; 0.00 0.62 0.45; ...      % Okabe-Ito 팔레트
         0.80 0.47 0.65; 0.90 0.62 0.00; 0.00 0.45 0.70; 0.25 0.25 0.25];

figure('Name','최적화 망 + 외부 상설 감시국','Color','w','Position',[80 80 960 720]);
gx = geoaxes;
try
    geobasemap(gx, 'topographic');
catch
end
hold(gx,'on');
for i = 1:numel(gray_tri)
    n = CL(gray_tri(i),:);
    geoplot(gx, geopolyshape([latR(n);latR(n(1))],[lonR(n);lonR(n(1))]),'k','EdgeColor','k','HandleVisibility','off');
end
for i = 1:numel(ext_cells)
    n = CL(ext_cells(i),:);
    geoplot(gx, geopolyshape([latR(n);latR(n(1))],[lonR(n);lonR(n(1))]),'EdgeColor','k','LineWidth',0.5,'FaceColor','r','FaceAlpha',0.3,'HandleVisibility','off');
end
E = edges(DT);
lat_e = [latR(E(:,1)), latR(E(:,2)), NaN(size(E,1),1)]';
lon_e = [lonR(E(:,1)), lonR(E(:,2)), NaN(size(E,1),1)]';
geoplot(gx, lat_e(:), lon_e(:), 'k-','LineWidth',0.5,'HandleVisibility','off');

hh = gobjects(2 + numel(agencies), 1);
lbl = cell(size(hh));
hh(1) = geoplot(gx, latR, lonR, 'ks','MarkerFaceColor','y','MarkerSize',6);
lbl{1} = sprintf('기준국 (%d개소)', R.nRef);
hh(2) = geoplot(gx, latM, lonM, 'k^','MarkerFaceColor','b','MarkerSize',5);
lbl{2} = sprintf('감시국 (%d개소)', R.nMon);
for k = 1:numel(agencies)
    m = ext.agency == agencies(k);
    kk = mod(k-1, numel(agMk)) + 1;      % 기관 수가 팔레트를 넘으면 순환
    hh(2+k) = geoplot(gx, ext.lat(m), ext.lon(m), agMk{kk}, ...
        'MarkerEdgeColor','k', 'MarkerFaceColor', agCol(kk,:), 'MarkerSize', 6, 'LineStyle', 'none');
    lbl{2+k} = sprintf('%s (%d개소)', agencies(k), nnz(m));
end
legend(gx, hh, lbl, 'Location','northeast');
title(gx, sprintf('최적화 망(기준국 %d·감시국 %d)과 기관별 외부 상설 감시국 %d개소', ...
      R.nRef, R.nMon, height(ext)));
geolimits(gx, [33 39], [125 132]); hold(gx,'off');

% ---- PNG 자동 저장 (result_fig) ----
figSave = fullfile(optDir,'result_fig');
if ~isfolder(figSave); mkdir(figSave); end
drawnow;
print(gcf, fullfile(figSave, sprintf('cors_overlay_%s.png', R.method)), '-dpng', '-r200');
fprintf('그림 저장: %s\n', fullfile(figSave, sprintf('cors_overlay_%s.png', R.method)));
