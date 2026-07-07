%% 감시가능망 "면적" 최대화 - 기준국->감시국 그리디 (실행/시각화 스크립트)
%  시각화 스타일은 2차/NRTK_with_CORS.m 의 빨강/회색 삼각형 + 커버리지와 동일.
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

%% 1) 데이터 로드 (위성기준점 99개소) - NRTK_with_CORS.m 과 동일 방식
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
names = string(rtsStations.RINEX(validDMS));   % 관측소 식별자 (배포표용)

%% 2) 그리디 실행 (run_ilp_area_max.m 과 동일 조건)
maxBaseKm = 70;
nOuter = 13;                          % 최외곽 고정 노드 수 (볼록껍질 12 + 동해안 YODK = 13)
bnd = outer_ring(lon, lat, nOuter);   % 명시적 외곽 노드 인덱스 (ILP와 동일)
fprintf('최외곽 고정 노드: %d개\n', numel(bnd));
[isRef, info] = greedy_area_max(lon, lat, maxBaseKm, bnd);
save_net_result(fullfile(thisDir,'result_greedy.mat'), 'greedy', lon, lat, isRef, maxBaseKm, bnd, info, names);

nInit = numel(lon);
nRef  = sum(isRef);
nMon  = sum(~isRef);
fprintf('\n===== 감시가능망 면적 최대화 (그리디) =====\n');
fprintf('초기 기준국        : %d개\n', nInit);
fprintf('최적화 후 기준국   : %d개\n', nRef);
fprintf('전환된 감시국(제거): %d개\n', nMon);

%% 3) 최종 유효면적(정확, WGS84) + 시각화 (NRTK_with_CORS.m 스타일 동일)
lonR = lon(isRef);   latR = lat(isRef);
lonM = lon(~isRef);  latM = lat(~isRef);
DT = delaunayTriangulation(lonR, latR);
CL = DT.ConnectivityList;

% 감시국을 포함하는(유효) 셀 = 빨강, 나머지 = 회색
triIdx  = pointLocation(DT, lonM, latM);
triIdx  = triIdx(~isnan(triIdx));
red_tri = unique(triIdx);
gray_tri = setdiff((1:size(CL,1))', red_tri);

figure('Name','감시가능망 면적 최대화','Color','w','Position',[80 80 960 720]);
gx = geoaxes; geobasemap(gx,'topographic'); hold(gx,'on');

% 3-1) 회색 셀(감시국 미포함) 면 채우기
for i = 1:numel(gray_tri)
    nodes = CL(gray_tri(i),:);
    p_lat = [latR(nodes); latR(nodes(1))];
    p_lon = [lonR(nodes); lonR(nodes(1))];
    geoplot(gx, geopolyshape(p_lat,p_lon), 'k', 'EdgeColor','k', 'HandleVisibility','off');
end
% 3-2) 빨강 셀(감시국 포함 = 유효면적) 면 채우기
for i = 1:numel(red_tri)
    nodes = CL(red_tri(i),:);
    p_lat = [latR(nodes); latR(nodes(1))];
    p_lon = [lonR(nodes); lonR(nodes(1))];
    geoplot(gx, geopolyshape(p_lat,p_lon), 'EdgeColor','k', 'LineWidth',0.5, ...
        'FaceColor','r', 'FaceAlpha',0.3, 'HandleVisibility','off');
end
% 3-3) 테두리 일괄
E = edges(DT);
lat_e = [latR(E(:,1)), latR(E(:,2)), NaN(size(E,1),1)]';
lon_e = [lonR(E(:,1)), lonR(E(:,2)), NaN(size(E,1),1)]';
geoplot(gx, lat_e(:), lon_e(:), 'k-', 'LineWidth',0.5, 'HandleVisibility','off');

% 3-4) 기준국(노란 사각) / 감시국(파란 삼각)
geoplot(gx, latR, lonR, 'ks', 'MarkerFaceColor','y', 'MarkerSize',6);
geoplot(gx, latM, lonM, 'k^', 'MarkerFaceColor','b', 'MarkerSize',5);
legend(gx, {'기준국(Reference)','감시국(Monitor)'}, 'Location','northeast');
title(gx, sprintf('감시가능망 면적 최대화 (기준국 %d, 감시국 %d)', nRef, nMon));
geolimits(gx, [33 39], [125 131]); hold(gx,'off');

% 정확 면적(WGS84) - 기존 코드와 동일(꼭짓점 fliplr 부호보정)
total_area = 0;
for i = 1:numel(red_tri)
    nodes = fliplr(CL(red_tri(i),:));
    p_lat = [latR(nodes); latR(nodes(1))];
    p_lon = [lonR(nodes); lonR(nodes(1))];
    total_area = total_area + area(geopolyshape(p_lat,p_lon))/1e6;
end
fprintf('감시 가능(유효) 셀 : %d개\n', numel(red_tri));
fprintf('감시 가능 망 면적  : %.2f km^2 (WGS84)\n', total_area);
fprintf('==========================================\n\n');

%% 4) 수렴 곡선 (기준국 수 감소 vs 유효면적 증가)
figure('Name','수렴 곡선','Color','w','Position',[80 80 960 720]);
plot(info.nRefHist, info.Varea_km2, '-o', 'LineWidth',1.2, 'MarkerSize',4);
set(gca,'XDir','reverse'); grid on;
xlabel('기준국 수 (전환 진행 →)'); ylabel('유효면적 (km^2, 평면근사)');
title('전환에 따른 감시가능망 면적 변화');
