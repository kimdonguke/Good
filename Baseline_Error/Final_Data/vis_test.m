%%%% 4. Automated Map Plot (Corrected)
clear; clc; %close all; % (필요에 따라 이 줄을 주석 처리/제거하세요)

% --- 1. 데이터 로드 ---
load("netRts.mat");

% [수정] 좌표(Lat/Lon)를 'Position' 시트에서 불러옵니다.
Hor_Coords = readtable("data.xlsx", 'Sheet', 'Horizontal');

% [수정] 오차 값을 'Pos_Error' 시트에서 불러옵니다.
Hor_Errors = readtable("data.xlsx", 'Sheet', 'Hor_Error');

% [확인] 두 테이블의 행 수가 같은지 확인
if size(Hor_Coords, 1) ~= size(Hor_Errors, 1)
    error('데이터 오류: Position 시트와 Pos_Error 시트의 행 수가 일치하지 않습니다.');
end

% --- 2. 임계값 정의 ---
Hor_threshold = 0.1;

% --- 3. 지도 설정 ---
figure;
gx = geoaxes;
geobasemap(gx, 'topographic')
hold(gx, 'on')
geolimits([33 39], [124 132])
title('NGII NRTK Service Performance Analysis (Position Error)')

% --- 4. CORS 네트워크 플롯 (기존과 동일) ---
for k = 1:size(netrts,1)
    pg = geopolyshape(netrts.LAT(k, [1 2 3 1]), netrts.LON(k, [1 2 3 1]));
    geoplot(gx, pg, 'k', 'EdgeColor', 'k', 'HandleVisibility', 'off')
end

% --- 5. [자동화] 에러 포인트 플롯 (두 테이블 조합) ---

% [수정] 'Pos_Errors' 테이블의 오차 값으로 인덱싱
idx_red = Hor_Errors.Hor_Error >= Hor_threshold;
idx_blue = ~idx_red; % 위 조건을 만족하지 않는 나머지 모든 포인트

% 'Good' 포인트 플롯 (파란색)
% [수정] 'Pos_Coords' 테이블의 좌표를 사용
geoplot(gx, Hor_Coords.Point_Lat(idx_blue), Hor_Coords.Point_Lon(idx_blue), ...
    'b^', ... % 파란색 삼각형
    'MarkerFaceColor', 'b', ...
    'MarkerSize', 6, ...
    'DisplayName', 'Good (Hor < 0.1 or |Ver| < 0.2)');

% 'Bad' 포인트 플롯 (빨간색)
% [수정] 'Pos_Coords' 테이블의 좌표를 사용
geoplot(gx, Hor_Coords.Point_Lat(idx_red), Hor_Coords.Point_Lon(idx_red), ...
    'r^', ... % 빨간색 삼각형
    'MarkerFaceColor', 'r', ...
    'MarkerSize', 6, ...
    'DisplayName', 'Bad (Hor >= 0.1 AND |Ver| >= 0.2)');

% --- 6. 범례 추가 ---
legend(gx, 'show', 'Location', 'southwest');

hold(gx, 'off');

%%
% [수정] 좌표(Lat/Lon)를 'Position' 시트에서 불러옵니다.
Ver_Coords = readtable("data.xlsx", 'Sheet', 'Vertical');

% [수정] 오차 값을 'Pos_Error' 시트에서 불러옵니다.
Ver_Errors = readtable("data.xlsx", 'Sheet', 'Ver_Error');

% [확인] 두 테이블의 행 수가 같은지 확인
if size(Ver_Coords, 1) ~= size(Ver_Errors, 1)
    error('데이터 오류: Position 시트와 Pos_Error 시트의 행 수가 일치하지 않습니다.');
end

% --- 2. 임계값 정의 ---
Ver_threshold = 0.2;

% --- 3. 지도 설정 ---
figure;
gx = geoaxes;
geobasemap(gx, 'topographic')
hold(gx, 'on')
geolimits([33 39], [124 132])
title('NGII NRTK Service Performance Analysis (Position Error)')

% --- 4. CORS 네트워크 플롯 (기존과 동일) ---
for k = 1:size(netrts,1)
    pg = geopolyshape(netrts.LAT(k, [1 2 3 1]), netrts.LON(k, [1 2 3 1]));
    geoplot(gx, pg, 'k', 'EdgeColor', 'k', 'HandleVisibility', 'off')
end

% --- 5. [자동화] 에러 포인트 플롯 (두 테이블 조합) ---

% [수정] 'Pos_Errors' 테이블의 오차 값으로 인덱싱
idx_ver = abs(Ver_Errors.Ver_Error) >= Ver_threshold;
idx_blue_v = ~idx_ver; % 위 조건을 만족하지 않는 나머지 모든 포인트

% 'Good' 포인트 플롯 (파란색)
% [수정] 'Pos_Coords' 테이블의 좌표를 사용
geoplot(gx, Ver_Coords.Point_Lat(idx_blue_v), Ver_Coords.Point_Lon(idx_blue_v), ...
    'b^', ... % 파란색 삼각형
    'MarkerFaceColor', 'b', ...
    'MarkerSize', 6, ...
    'DisplayName', 'Good (|Ver| < 0.2)');

% 'Bad' 포인트 플롯 (빨간색)
% [수정] 'Pos_Coords' 테이블의 좌표를 사용
geoplot(gx, Ver_Coords.Point_Lat(idx_ver), Ver_Coords.Point_Lon(idx_ver), ...
    'c^', ... % 빨간색 삼각형
    'MarkerFaceColor', 'c', ...
    'MarkerSize', 6, ...
    'DisplayName', 'Bad (|Ver| >= 0.2)');

% --- 6. 범례 추가 ---
legend(gx, 'show', 'Location', 'southwest');

hold(gx, 'off');

%%
% [수정] 좌표(Lat/Lon)를 'Position' 시트에서 불러옵니다.
Pos_Coords = readtable("data.xlsx", 'Sheet', 'Position');

% [수정] 오차 값을 'Pos_Error' 시트에서 불러옵니다.
Pos_Errors = readtable("data.xlsx", 'Sheet', 'Pos_Error');

% [확인] 두 테이블의 행 수가 같은지 확인
if size(Pos_Coords, 1) ~= size(Pos_Errors, 1)
    error('데이터 오류: Position 시트와 Pos_Error 시트의 행 수가 일치하지 않습니다.');
end

% --- 2. 임계값 정의 ---
Hor_threshold = 0.1;
Ver_threshold = 0.2;

% --- 3. 지도 설정 ---
figure;
gx = geoaxes;
geobasemap(gx, 'topographic')
hold(gx, 'on')
geolimits([33 39], [124 132])
title('NGII NRTK Service Performance Analysis (Position Error)')

% --- 4. CORS 네트워크 플롯 (기존과 동일) ---
for k = 1:size(netrts,1)
    pg = geopolyshape(netrts.LAT(k, [1 2 3 1]), netrts.LON(k, [1 2 3 1]));
    geoplot(gx, pg, 'k', 'EdgeColor', 'k', 'HandleVisibility', 'off')
end

% --- 5. [자동화] 에러 포인트 플롯 (두 테이블 조합) ---

% [수정] 'Pos_Errors' 테이블의 오차 값으로 인덱싱
idx_Pos = (Pos_Errors.Hor_Error >= Hor_threshold) & (abs(Pos_Errors.Ver_Error) >= Ver_threshold);
idx_blue_p = ~idx_Pos; % 위 조건을 만족하지 않는 나머지 모든 포인트

% 'Good' 포인트 플롯 (파란색)
% [수정] 'Pos_Coords' 테이블의 좌표를 사용
geoplot(gx, Pos_Coords.Point_Lat(idx_blue_p), Pos_Coords.Point_Lon(idx_blue_p), ...
    'b^', ... % 파란색 삼각형
    'MarkerFaceColor', 'b', ...
    'MarkerSize', 6, ...
    'DisplayName', 'Good (Hor < 0.1 or |Ver| < 0.2)');

% 'Bad' 포인트 플롯 (빨간색)
% [수정] 'Pos_Coords' 테이블의 좌표를 사용
geoplot(gx, Pos_Coords.Point_Lat(idx_Pos), Pos_Coords.Point_Lon(idx_Pos), ...
    'k^', ... % 빨간색 삼각형
    'LineWidth',1.2,...
    'MarkerFaceColor', 'c', ...
    'MarkerSize', 6, ...
    'DisplayName', 'Bad (Hor >= 0.1 AND |Ver| >= 0.2)');

% --- 6. 범례 추가 ---
legend(gx, 'show', 'Location', 'southwest');

hold(gx, 'off');