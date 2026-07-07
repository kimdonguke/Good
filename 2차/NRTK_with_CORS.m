%% Initialize and Setup
% close all;
clear;
clc;

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
% set_plot_style;
CORS_TruePos_ECEF = [
    -3102269.318, 3914266.018, 3953618.697; % JEOJ
    -3309631.002, 3834554.848, 3863307.849; % ULLE
    -3393317.086, 3785917.142, 3838651.937; % DOKD
    -3020139.799, 4079807.145, 3849130.627; % PALM
    -2876283.755, 4149428.408, 3884508.482; % SOCH
    -3020236.857, 4136468.616, 3788431.988; % ANHN
    -3029436.991, 4174489.865, 3739474.670; % EOCH
    -3064945.137, 4170122.441, 3715473.938; % MLDO
    -3025924.946, 4288817.018, 3611645.039; % HGDO
    -3040228.939, 4325980.929, 3555223.961; % GASE
    -3097626.989, 4256824.484, 3588741.435; % GASA
    -3152604.582, 4244559.537, 3555538.726; % DANG
    -3209052.409, 4209084.067, 3547202.181; % GEOM
    -3228667.951, 4162214.110, 3584296.756; % SORI
    -3163444.449, 4311372.207, 3464865.222; % MARA
    -3281490.566, 4090421.629, 3618634.192; % SEOI
    -3294232.510, 4057786.202, 3643626.819; % YNDO
    -3287391.371, 3978484.960, 3735216.059; % HOMI
    -3154854.857, 4099170.444, 3719782.817; % MOOJ
    -3196187.662, 4064068.516, 3722851.285; % SEJU
    -3138633.993, 4078412.585, 3755410.009; % OKCH
    -3169577.644, 4030299.571, 3781067.315; % MUNG
    -3123433.261, 4033298.187, 3815900.759; % CCHJ
    -3183643.871, 3995960.384, 3805622.050; % YNJU
    -3236668.844, 3936353.400, 3822579.047; % JUKB
    -3204049.208, 3930214.539, 3855959.433; % SAMC
    -3159577.521, 3973889.641, 3848566.324; % PYCH
    -3102607.958, 3989929.871, 3877576.742; % HONG
    -3078831.376, 3981392.550, 3905083.340; % CCHN
    -3130518.687, 3921543.502, 3924167.491; % SOKC
    -3160056.141, 3925576.993, 3896541.865; % JUMN
    -3035913.940, 4052535.357, 3865342.823; % GANS
    -3044105.929, 4053468.858, 3857988.182; % GUMC
    -3047506.741, 4043980.580, 3865243.010; % YONS
    -3046229.955, 4034989.023, 3875524.024; % DBON
    -3059553.884, 4039145.662, 3860773.000; % SONP
    -3253751.004, 4054962.963, 3682413.187; % MLYN
    -3161258.981, 3974731.038, 3846954.260  % DONM
    ];
CORS_TruePos_LLA = ecef2lla(CORS_TruePos_ECEF);

% 경로는 상단에서 이미 설정됨 (아래는 외부 JPNT 폴더가 있으면 선택적으로 추가)
ngiiJpnt = fullfile(fileparts(projectRoot), 'JPNT', 'Data_Function');
if isfolder(ngiiJpnt); addpath(ngiiJpnt); end
% Initialize constants
% initconst();

%% Load and Preprocess Data (NGII Network)

% Load NGII NRTK service validation results
load('rslt.mat');

% Load CORS information (format: shapefile)
rtsStations = struct2table(shaperead('위성기준점(99개소).shp'));
rtsStations.Properties.VariableNames = {'Geometry', 'X_proj', 'Y_proj', 'FID1', 'FID2', 'Name', 'RINEX', 'LAT_dms', 'LON_dms'...
                                       ,'Height', 'X1', 'Y1', 'Proj', 'None1', 'None2'}';

RTSid = [0 : size(rtsStations,1)-1]';
rtsStations.RTSid = RTSid; 

% Convert DMS to decimal degree
latParts = cellfun(@(x) str2double(strsplit(x, '-')), rtsStations.LAT_dms, 'UniformOutput', false);
lonParts = cellfun(@(x) str2double(strsplit(x, '-')), rtsStations.LON_dms, 'UniformOutput', false);

validDMS = ~cellfun('isempty', latParts) & ~cellfun('isempty', lonParts);
rtsStations.LAT_deg(validDMS) = cellfun(@(x) dms2deg(x'), latParts(validDMS));
rtsStations.LON_deg(validDMS) = cellfun(@(x) dms2deg(x'), lonParts(validDMS));

% Load CORS Network information (format: shapefile)
netrtsfile  = shaperead('위성기준점(99개소) 망.shp');

for i = 1:size(netrtsfile, 1)
    idxA = find((netrtsfile(i).POINTA == [rtsStations.RTSid]') & (netrtsfile(i).X(1) == [rtsStations.X_proj]'));
    idxB = find((netrtsfile(i).POINTB == [rtsStations.RTSid]') & (netrtsfile(i).X(2) == [rtsStations.X_proj]'));
    idxC = find((netrtsfile(i).POINTC == [rtsStations.RTSid]') & (netrtsfile(i).X(3) == [rtsStations.X_proj]'));

    networkLats(i,1) = rtsStations.LAT_deg(idxA);
    networkLats(i,2) = rtsStations.LAT_deg(idxB);
    networkLats(i,3) = rtsStations.LAT_deg(idxC);

    networkLons(i,1) = rtsStations.LON_deg(idxA);
    networkLons(i,2) = rtsStations.LON_deg(idxB);
    networkLons(i,3) = rtsStations.LON_deg(idxC);
end

netrts = table(networkLats, networkLons, [netrtsfile.POINTA]', [netrtsfile.POINTB]', [netrtsfile.POINTC]', 'VariableNames', {'LAT', 'LON', 'POINTA', 'POINTB', 'POINTC'});

%% Load and Preprocess Data (Test Points)

% Load test points information (True Position)
testPoints = readtable('검증 대상점 목록_250321.xlsx', 'VariableNamingRule', 'preserve');
testPoints.Properties.VariableNames = ["Location","Gridnum", "Name", "Var1","Lon_dms", "Lat_dms", "X", "Y", "h", "H", "Var2", "Var3",...
                                       "RINEX", "Var4", "Var5", "Var6"];

latParts_vp = cellfun(@(x) str2double(split(x)), testPoints.Lat_dms, 'UniformOutput', false);
lonParts_vp = cellfun(@(x) str2double(split(x)), testPoints.Lon_dms, 'UniformOutput', false);

validDMS_vp = ~cellfun('isempty', latParts_vp) & ~cellfun('isempty', lonParts_vp);
testPoints.Lat_deg(validDMS_vp) = cellfun(@(x) dms2deg(x'), latParts_vp(validDMS_vp));
testPoints.Lon_deg(validDMS_vp) = cellfun(@(x) dms2deg(x'), lonParts_vp(validDMS_vp));

% Test points positioning performance analysis

% Define precision thresholds
horizThreshold = 0.05 * 2;  % Horizontal precision threshold (e.g., 10 cm)
vertThreshold  = 0.10 * 2;  % Vertical precision threshold (e.g., 20 cm)

% Extract horizontal and vertical errors from results
horizErrors = rslt{1,2};
vertErrors  = rslt{1,3};
pointNames  = rslt{1,1};

% Find FKP services and other services
fkpServices   = [9, 10]; 
otherServices = setdiff(1:size(horizErrors, 2), fkpServices);

isFKP_Degrade  = any(~isnan(horizErrors(:, fkpServices)) & (horizErrors(:, fkpServices) > horizThreshold), 2);
isOther_OK     = all((horizErrors(:, otherServices) <= horizThreshold) | isnan(horizErrors(:, otherServices)), 2);
mask_horizFail = isFKP_Degrade & isOther_OK;

isFKP_Vert_Degrade = any(~isnan(vertErrors(:, fkpServices)) & (vertErrors(:, fkpServices) > vertThreshold), 2);
isOther_Vert_OK    = all((horizErrors(:, otherServices) <= horizThreshold) | isnan(horizErrors(:, otherServices)), 2);
mask_vertFail      = isFKP_Vert_Degrade;

% Combine masks to get all degraded points
degradedRows  = find(mask_horizFail | mask_vertFail);
degradedNames = pointNames(degradedRows, 2);

[~, idxFailing, ~] = intersect(testPoints.Name, degradedNames);


%% Plotting and Result Display

% Create new figure
figure;
gx = geoaxes;
geobasemap(gx, 'topographic')
hold(gx, 'on')
geolimits([33 39], [124 132])
title('NGII NRTK Service Performance Analysis')

% Plot NGII CORS Networks (polygons)
for k = 1:size(netrts,1)
    pg = geopolyshape(netrts.LAT(k, [1 2 3 1]), netrts.LON(k, [1 2 3 1]));
    geoplot(gx, pg, 'k', 'EdgeColor', 'k', 'HandleVisibility', 'off')
end

% Plot NGII CORS Stations
for i = 1:size(rtsStations, 1)
    geoplot(rtsStations.LAT_deg(i), rtsStations.LON_deg(i), 'gs', 'color', 'k', 'MarkerFaceColor','y', 'LineWidth', 1, 'MarkerSize', 6, 'HandleVisibility', 'off')
end

geoplot(CORS_TruePos_LLA(:,1), CORS_TruePos_LLA(:,2),'k^','MarkerFaceColor','b');

% Plot all test points
% [~, idxValid, ~] = intersect(testPoints.Name, pointNames(:,2));
% geoplot(gx, testPoints.Lat_deg(idxValid), testPoints.Lon_deg(idxValid), 'b^','MarkerFaceColor','b', 'LineWidth', 1, 'MarkerSize', 5);
% 
% % Plot performance degraded points
% geoplot(gx, testPoints.Lat_deg(idxFailing), testPoints.Lon_deg(idxFailing), 'r^', ...
%        'MarkerFaceColor','r', 'LineWidth', 1, 'MarkerSize', 5, 'DisplayName', 'Failing Points')


Point = [rtsStations.LAT_deg,rtsStations.LON_deg];
DT = delaunayTriangulation(Point(:,2),Point(:,1));

lon = DT.Points(:, 1);
lat = DT.Points(:, 2);

% 1. 삼각망의 모든 선분(Edge) 인덱스 추출 (앞에서 사용한 함수)
E = edges(DT);

% 2. 선분의 양 끝점(Point 1, Point 2)의 경도(X), 위도(Y) 분리
lon1 = DT.Points(E(:,1), 1);
lat1 = DT.Points(E(:,1), 2);

lon2 = DT.Points(E(:,2), 1);
lat2 = DT.Points(E(:,2), 2);

% 3. 지구 평균 반지름 설정 (단위: km)
R = 6371; 

% 4. 각도(Degree)를 라디안(Radian)으로 변환
lat1_rad = deg2rad(lat1);
lon1_rad = deg2rad(lon1);
lat2_rad = deg2rad(lat2);
lon2_rad = deg2rad(lon2);

% 5. 하버사인(Haversine) 공식을 활용한 거리 계산 (벡터화 연산)
dlat = lat2_rad - lat1_rad;
dlon = lon2_rad - lon1_rad;

a = sin(dlat/2).^2 + cos(lat1_rad) .* cos(lat2_rad) .* sin(dlon/2).^2;
c = 2 * atan2(sqrt(a), sqrt(1-a));

% 각 변의 길이 배열 (크기: 184 x 1) - 단위: km
edge_lengths_km = R * c; 

% --- (앞선 1~5번 하버사인 거리 계산 코드는 동일하게 실행) ---
% edge_lengths_km 배열이 계산된 상태라고 가정합니다.

% 7. 인덱스와 거리를 테이블(Table) 형태로 묶기
% E(:,1)은 첫 번째 점(관측소)의 인덱스, E(:,2)는 두 번째 점의 인덱스입니다.
BaselineTable = table(E(:,1), E(:,2), edge_lengths_km, ...
    'VariableNames', {'Station1_Idx', 'Station2_Idx', 'Distance_km'});

% 8. 거리가 긴 순서대로(내림차순) 테이블 정렬하기 (분석을 위해)
BaselineTable_Sorted = sortrows(BaselineTable, 'Distance_km', 'descend');

% 9. 결과 확인 (상위 10개의 가장 긴 기선 출력)
% disp('가장 거리가 먼 상위 10개 연결망 (기선):');
% disp(head(BaselineTable_Sorted, 10));

% % 6. 결과 기초 통계 확인 (Network RTK 기선장 분석용)
fprintf('총 연결된 변의 개수: %d 개\n', length(edge_lengths_km));
fprintf('가장 짧은 기선 길이: %.2f km\n', min(edge_lengths_km));
fprintf('가장 긴 기선 길이  : %.2f km\n', max(edge_lengths_km));
fprintf('평균 기선 길이     : %.2f km\n', mean(edge_lengths_km));

% 1. 테스트 지점(파란색 원)들의 위도, 경도 좌표 통합
test_lat = [ CORS_TruePos_LLA(:, 1)];
test_lon = [ CORS_TruePos_LLA(:, 2)];

% 2. 테스트 지점들이 속해 있는 삼각형(Cell) 인덱스 찾기
tri_idx = pointLocation(DT, test_lon, test_lat);
tri_idx = tri_idx(~isnan(tri_idx)); 
red_tri_indices = unique(tri_idx);  

% 테스트 지점을 포함하지 않는 나머지 삼각형 인덱스
all_tri_indices = (1:size(DT.ConnectivityList, 1))';
gray_tri_indices = setdiff(all_tri_indices, red_tri_indices);


% 3. 시각화 시작
figure;
gx = geoaxes; 
geobasemap(gx, 'topographic'); 
hold(gx, 'on');

% =========================================================================
% [수정 1] 면(Face) 채우기: 구멍 뚫림을 막기 위해 개별적으로 칠합니다.
% 테두리는 그리지 않습니다. ('EdgeColor', 'none')

% 3-1. 회색 삼각형 면 채우기
for i = 1:length(gray_tri_indices)
    idx = gray_tri_indices(i); 
    nodes = DT.ConnectivityList(idx, :);
    
    % 삼각형을 닫아주기 위해 첫 번째 점을 마지막에 추가 (1-2-3-1)
    p_lat = [lat(nodes); lat(nodes(1))];
    p_lon = [lon(nodes); lon(nodes(1))];
    
    poly = geopolyshape(p_lat, p_lon);
    geoplot(gx, poly, 'k', 'EdgeColor', 'k', 'HandleVisibility', 'off');
end

% 3-2. 빨간색 삼각형 면 채우기
for i = 1:length(red_tri_indices)
    idx = red_tri_indices(i);
    nodes = DT.ConnectivityList(idx, :);
    
    % 삼각형을 닫아주기 위해 첫 번째 점을 마지막에 추가 (1-2-3-1)
    p_lat = [lat(nodes); lat(nodes(1))];
    p_lon = [lon(nodes); lon(nodes(1))];
    
    poly = geopolyshape(p_lat, p_lon);
    geoplot(gx, poly, 'EdgeColor','k', ...    
    'LineWidth',0.5, ...   
    'FaceColor','r', ...
    'FaceAlpha',0.3, ...
    'HandleVisibility','off');
end

% =========================================================================
% [수정 2] 테두리 선(Edge) 그리기: 모든 선을 똑같은 굵기(1.0)로 한 번에 그립니다.
E = edges(DT);
lat_edges = [lat(E(:,1)), lat(E(:,2)), NaN(size(E,1), 1)]';
lon_edges = [lon(E(:,1)), lon(E(:,2)), NaN(size(E,1), 1)]';

% 모든 삼각형의 테두리를 일정하게 검은색으로 덮어 그리기
geoplot(gx, lat_edges(:), lon_edges(:), 'k-', 'LineWidth', 0.5);

% =========================================================================
% 4. 관측소 및 테스트 지점 마커 찍기 (작성하신 커스텀 스타일 유지!)
% 관측소(노드) 위치에 노란색 사각형 점 찍기
geoplot(gx, lat, lon, 'ks', 'LineWidth', 0.5, 'MarkerFaceColor', 'y', 'MarkerSize', 5);

% N-RTK 감시 지점 위치에 초록색 원 찍기 (1~17번)
% geoplot(gx, test_lat(1:17), test_lon(1:17), 'ko', 'LineWidth', 1, 'MarkerFaceColor', 'g', 'MarkerSize', 5);

% CORS 상설감시국 위치에 파란색 원 찍기 (18번 이후)
geoplot(gx, test_lat, test_lon, 'k^', 'LineWidth', 0.5, 'MarkerFaceColor', 'b', 'MarkerSize', 5);
legend('','국토지리정보원 기준국','타기관 상시관측소')

title(gx, 'Network 및 상설감시국 시각화');
hold(gx, 'off');

% =========================================================================
% ★ 활성화된 N-RTK 셀(Cell)의 개수 및 총 커버리지 면적 계산 ★
% =========================================================================
num_red_triangles = length(red_tri_indices);
total_red_area_sqkm = 0; % 면적을 누적할 변수 초기화

% 빨간색 삼각형들의 면적을 하나씩 구해서 더하기
for i = 1:length(red_tri_indices)
    idx = red_tri_indices(i);
    
    % 들로네 삼각망의 꼭짓점 번호 가져오기 [예: 1번, 5번, 3번]
    nodes = DT.ConnectivityList(idx, :);
    
    % ★ 핵심 해결책: 꼭짓점 배열 순서 뒤집기 (시계 방향 -> 반시계 방향 복구)
    % 이 한 줄이 지구 전체 면적이 계산되는 구면 기하학 오류를 완벽하게 막아줍니다.
    nodes = fliplr(nodes); 
    
    % 삼각형을 닫힌 다각형(1-2-3-1) 형태로 구성
    p_lat = [lat(nodes); lat(nodes(1))];
    p_lon = [lon(nodes); lon(nodes(1))];
    
    % 지리 다각형 객체 생성
    poly = geopolyshape(p_lat, p_lon);
    
    % area 함수: WGS84 타원체 기준 실제 물리적 면적 반환 (단위: m²)
    area_sqm = area(poly); 
    
    % m²를 km²로 변환하여 누적
    total_red_area_sqkm = total_red_area_sqkm + (area_sqm / 1e6); 
end
 

% 결과 출력
fprintf('\n================================================\n');
fprintf('활성화된 N-RTK 셀(빨간색 삼각형)의 총 개수: %d 개\n', num_red_triangles);
fprintf('N-RTK 유효 커버리지 총 면적: %.2f km²\n', total_red_area_sqkm);
% fprintf('대한민국 국토 면적 대비 커버리지 비율: %.2f %%\n', coverage_ratio);
fprintf('================================================\n\n');
%%

% 1. 관측소 데이터
lon = rtsStations.LON_deg;
lat = rtsStations.LAT_deg;

% 2. 지도(Geoaxes) 생성
figure('Name', 'NGII NRTK Density Map', 'Color', 'w');
gx = geoaxes; 
hold(gx, 'on');
geobasemap(gx, 'topographic'); 


% (1) 관측소 최외곽 테두리 좌표 구하기
k = boundary(lon, lat, 0.5); 
b_lat = lat(k);
b_lon = lon(k);
pg_outline = geopolyshape(b_lat, b_lon);

% (2) 화면을 덮을 아주 촘촘한 가상의 격자(점)들 생성
lat_grid = linspace(33, 39, 200); % 200단계로 촘촘하게
lon_grid = linspace(124, 132, 200);
[Lon_mesh, Lat_mesh] = meshgrid(lon_grid, lat_grid);
lat_vec = Lat_mesh(:);
lon_vec = Lon_mesh(:);

% (3) 각 격자점들의 밀도(Z) 계산
[Z_vec, ~] = ksdensity([lon, lat], [lon_vec, lat_vec], 'Bandwidth', [0.4, 0.4]);

% (4) 🌟 inpolygon으로 내부 판별 (수정된 부분) 🌟
% inpolygon(검사할X, 검사할Y, 다각형X, 다각형Y) 순서로 들어갑니다. (X=경도, Y=위도)
tf_inside = inpolygon(lon_vec, lat_vec, b_lon, b_lat);

% (5) 조건에 맞는(안쪽에 있는) 데이터만 추출 (밖은 투명해짐)
lat_in = lat_vec(tf_inside);
lon_in = lon_vec(tf_inside);
Z_in = Z_vec(tf_inside);

% (6) geoscatter로 안쪽 점들만 칠하기 
% 'MarkerEdgeColor', 'none'을 추가해 점들 사이의 틈이나 선이 안 보이게 부드럽게 뭉치게 합니다.
geoscatter(gx, lat_in, lon_in, 70, Z_in, 'filled', 'Marker', 's', ...
    'MarkerFaceAlpha', 0.6, 'MarkerEdgeColor', 'none');

% ==========================================================

% 컬러맵 및 컬러바 추가
colormap(gx, 'jet');
colorbar;

% 테두리 윤곽선을 뚜렷하게 한 번 더 그려주기
% geoplot(gx, pg_outline, 'EdgeColor', 'k', 'FaceColor', 'none', 'LineWidth', 1.2, 'HandleVisibility', 'off');

% 4. 원래의 관측소 위치 (노란 사각형) 표시
geoplot(gx, lat, lon, 'ks', 'MarkerFaceColor', 'y', 'MarkerSize', 6);
legend('','국토지리정보원 위성기준점')

% 5. 타이틀 및 지도 범위 고정
title(gx, '국토지리정보원 위성기준점 밀집도 분석');
geolimits(gx, [33 39], [125 131]); 
hold(gx, 'off');