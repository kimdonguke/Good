%% [골격①] 빈-외접원 ILP 면적 최대화 - 전역최적 + 그리디 비교 + LP 상한 인증
clear; clc;
tic
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

if isempty(which('intlinprog'))
    error('Optimization Toolbox(intlinprog)가 설치되어 있지 않습니다. 설치된 툴박스 확인: ver');
end

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
names = string(rtsStations.RINEX(validDMS));   % 관측소 식별자 (배포표용)

maxBaseKm = 100;
nOuter = 13;                          % 최외곽 고정 노드 수 (볼록껍질 12 + 동해안 YODK = 13)
bnd = outer_ring(lon, lat, nOuter);   % 명시적 외곽 노드 인덱스 (shrink 대신 개수로 고정)
fprintf('최외곽 고정 노드: %d개\n', numel(bnd));

%% 1) 그리디 (비교 기준)
tG = tic;
[isRefG, ~] = greedy_area_max(lon, lat, maxBaseKm, bnd);
tGreedy = toc(tG);
[aG, ncG] = valid_net_wgs84(lon, lat, isRefG);

%% 2) ILP 전역최적
tI = tic;
[isRefI, info] = ilp_area_max(lon, lat, maxBaseKm, bnd);
tILP = toc(tI);
[aI, ncI] = valid_net_wgs84(lon, lat, isRefI);
save_net_result(fullfile(thisDir,'result_ilp.mat'), 'ilp', lon, lat, isRefI, maxBaseKm, bnd, info, names);

nInit = numel(lon);
fprintf('\n===== [골격①] 빈-외접원 ILP vs 그리디 (면적 최대화) =====\n');
fprintf('후보 삼각형        : %d개 (raw %d)\n', info.nCand, info.nCandRaw);
fprintf('no-good 컷 반복     : %d회\n', info.iters);
fprintf('-----------------------------------------------------------\n');
fprintf('%-10s | %6s %6s %10s %8s\n','방법','기준국','유효셀','면적(km^2)','시간(s)');
fprintf('%-10s | %6d %6d %10.1f %8.1f\n','그리디', sum(isRefG), ncG, aG, tGreedy);
fprintf('%-10s | %6d %6d %10.1f %8.1f\n','ILP최적', sum(isRefI), ncI, aI, tILP);
fprintf('-----------------------------------------------------------\n');
fprintf('LP 상한(dual bound): %.1f km^2\n', info.lpBound_km2);
fprintf('ILP 내부 목적값     : %.1f km^2 (실제 재계산 %.1f)\n', info.ilpObj_km2, aI);
fprintf('그리디 최적성       : %.2f%% (그리디/ILP)\n', 100*aG/aI);
fprintf('그리디 갭(면적)     : %.1f km^2  (ILP−그리디)\n', aI-aG);
fprintf('ILP 최적성 인증     : %.2f%% (ILP/LP상한, 100%%이면 증명완료)\n', 100*aI/info.lpBound_km2);
fprintf('===========================================================\n\n');

%% 3) ILP 결과 지도 (기존 빨강/회색 스타일)
lonR = lon(isRefI); latR = lat(isRefI);
lonM = lon(~isRefI); latM = lat(~isRefI);
DT = delaunayTriangulation(lonR, latR); CL = DT.ConnectivityList;
ti = pointLocation(DT, lonM, latM); ti = ti(~isnan(ti));
red_tri = unique(ti); gray_tri = setdiff((1:size(CL,1))', red_tri);

figure('Name','ILP 면적 최대화 (전역최적)','Color','w','Position',[80 80 960 720]);
gx = geoaxes; geobasemap(gx,'topographic'); hold(gx,'on');
for i = 1:numel(gray_tri)
    n = CL(gray_tri(i),:);
    geoplot(gx, geopolyshape([latR(n);latR(n(1))],[lonR(n);lonR(n(1))]),'k','EdgeColor','k','HandleVisibility','off');
end
for i = 1:numel(red_tri)
    n = CL(red_tri(i),:);
    geoplot(gx, geopolyshape([latR(n);latR(n(1))],[lonR(n);lonR(n(1))]),'EdgeColor','k','LineWidth',0.5,'FaceColor','r','FaceAlpha',0.3,'HandleVisibility','off');
end
E = edges(DT);
lat_e = [latR(E(:,1)), latR(E(:,2)), NaN(size(E,1),1)]';
lon_e = [lonR(E(:,1)), lonR(E(:,2)), NaN(size(E,1),1)]';
geoplot(gx, lat_e(:), lon_e(:), 'k-','LineWidth',0.5,'HandleVisibility','off');
geoplot(gx, latR, lonR, 'ks','MarkerFaceColor','y','MarkerSize',6);
geoplot(gx, latM, lonM, 'k^','MarkerFaceColor','b','MarkerSize',5);
legend(gx, {'기준국(Reference)','감시국(Monitor)'}, 'Location','northeast');
title(gx, sprintf('최적 감시망 구성 (ILP) — 기준국 %d, 감시국 %d, 감시가능 면적 %.0f km^2', sum(isRefI), sum(~isRefI), aI));
geolimits(gx, [33 39], [125 131]); hold(gx,'off');

%% 4) 그리디 vs ILP vs 상한 비교 막대
figure('Name','면적 비교','Color','w','Position',[80 80 960 720]);
vals = [aG, aI, info.lpBound_km2];
b = bar(categorical({'그리디','ILP최적','LP상한'},{'그리디','ILP최적','LP상한'}), vals, 0.5);
ylabel('감시가능망 면적 (km^2)'); grid on;
title({'감시가능 면적 비교 — Greedy, ILP, LP 상한', ...
       sprintf('Greedy/ILP = %.1f%%,  ILP/상한 = %.1f%%', 100*aG/aI, 100*aI/info.lpBound_km2)});
text(1:3, vals, compose('%.0f',vals), 'HorizontalAlignment','center','VerticalAlignment','bottom');
toc
