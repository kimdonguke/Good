clear; clc; %close all;

%% 1. 데이터 로드 및 임계값 정의
load("MS_data.mat"); % MS_H, MS_V, MS_P 변수 로드
load("netRts.mat"); % netrts 변수 로드

Hor_threshold = 0.1;
Ver_threshold = 0.2;

%% 2. Horizontal Error Map (MS_H 데이터 기준)
figure;
gx_h = geoaxes;
geobasemap(gx_h, 'topographic')
hold(gx_h, 'on')
geolimits([33 39], [124 132])
title('Main Station Analysis (Horizontal Error)')

% --- CORS 네트워크 플롯 (배경용) ---
for k = 1:size(netrts,1)
    pg = geopolyshape(netrts.LAT(k, [1 2 3 1]), netrts.LON(k, [1 2 3 1]));
    geoplot(gx_h, pg, 'k', 'EdgeColor', 'k', 'HandleVisibility', 'off')
end

% --- Main Station 및 Rover Points 플롯 (MS_H) ---
for k = 1:length(MS_H)
    tbl = MS_H{k};
    if isempty(tbl), continue; end
    
    % 범례(legend) 중복을 피하기 위한 핸들러
    if k == 1
        ms_disp = 'Main Station';
        good_disp = 'Good (Hor < 0.1)';
        bad_disp = 'Bad (Hor >= 0.1)';
    else
        ms_disp = 'off';
        good_disp = 'off';
        bad_disp = 'off';
    end
    
    % 1. 주기준국(Main Station) 플롯 (노란색 사각형)
    geoplot(gx_h, tbl.Station_Lat(1), tbl.Station_Lon(1), 'ks','Linewidth',2, ...
        'MarkerFaceColor', 'y', 'MarkerSize', 10, 'DisplayName', ms_disp);
    
    % 2. 이동국(Rover Points) 플롯
    % (MS_H는 수평 오차 기준이므로 Hor_Error만 계산)
    hor_error = sqrt(tbl.East_Error.^2 + tbl.North_Error.^2);
    
    idx_bad = (hor_error >= Hor_threshold);
    idx_good = ~idx_bad;
    
    % Good (파란색)
    geoplot(gx_h, tbl.Point_Lat(idx_good), tbl.Point_Lon(idx_good), 'b^', ...
        'MarkerFaceColor', 'b', 'MarkerSize', 6, 'DisplayName', good_disp);
    
    % Bad (빨간색)
    geoplot(gx_h, tbl.Point_Lat(idx_bad), tbl.Point_Lon(idx_bad), 'r^', ...
        'MarkerFaceColor', 'r', 'MarkerSize', 6, 'DisplayName', bad_disp);
end
% legend(gx_h, 'show', 'Location', 'southwest');
hold(gx_h, 'off');


%% 3. Vertical Error Map (MS_V 데이터 기준)
figure;
gx_v = geoaxes;
geobasemap(gx_v, 'topographic')
hold(gx_v, 'on')
geolimits([33 39], [124 132])
title('Main Station Analysis (Vertical Error)')

% --- CORS 네트워크 플롯 (배경용) ---
for k = 1:size(netrts,1)
    pg = geopolyshape(netrts.LAT(k, [1 2 3 1]), netrts.LON(k, [1 2 3 1]));
    geoplot(gx_v, pg, 'k', 'EdgeColor', 'k', 'HandleVisibility', 'off')
end

% --- Main Station 및 Rover Points 플롯 (MS_V) ---
for k = 1:length(MS_V)
    tbl = MS_V{k};
    if isempty(tbl), continue; end
    
    if k == 1
        ms_disp = 'Main Station';
        good_disp = 'Good (|Ver| < 0.2)';
        bad_disp = 'Bad (|Ver| >= 0.2)';
    else
        ms_disp = 'off';
        good_disp = 'off';
        bad_disp = 'off';
    end
    
    % 1. 주기준국(Main Station) 플롯 (노란색 사각형)
    geoplot(gx_v, tbl.Station_Lat(1), tbl.Station_Lon(1), 'ks','Linewidth',2, ...
        'MarkerFaceColor', 'y', 'MarkerSize', 10, 'DisplayName', ms_disp);
    
    % 2. 이동국(Rover Points) 플롯
    idx_bad = (abs(tbl.Up_Error) >= Ver_threshold);
    idx_good = ~idx_bad;
    
    % Good (파란색)
    geoplot(gx_v, tbl.Point_Lat(idx_good), tbl.Point_Lon(idx_good), 'b^', ...
        'MarkerFaceColor', 'b', 'MarkerSize', 6, 'DisplayName', good_disp);
    
    % Bad (청록색 - Cyan)
    geoplot(gx_v, tbl.Point_Lat(idx_bad), tbl.Point_Lon(idx_bad), 'c^', ...
        'MarkerFaceColor', 'c', 'MarkerSize', 6, 'DisplayName', bad_disp);
end
% legend(gx_v, 'show', 'Location', 'southwest');
hold(gx_v, 'off');


%% 4. Position Error Map (MS_P 데이터 기준)
figure;
gx_p = geoaxes;
geobasemap(gx_p, 'topographic')
hold(gx_p, 'on')
geolimits([33 39], [124 132])
title('Main Station Analysis (Position Error)')

% --- CORS 네트워크 플롯 (배경용) ---
for k = 1:size(netrts,1)
    pg = geopolyshape(netrts.LAT(k, [1 2 3 1]), netrts.LON(k, [1 2 3 1]));
    geoplot(gx_p, pg, 'k', 'EdgeColor', 'k', 'HandleVisibility', 'off')
end

% --- Main Station 및 Rover Points 플롯 (MS_P) ---
for k = 1:length(MS_P)
    tbl = MS_P{k};
    if isempty(tbl), continue; end
    
    if k == 1
        ms_disp = 'Main Station';
        good_disp = 'Good (Hor < 0.1 or |Ver| < 0.2)';
        bad_disp = 'Bad (Hor >= 0.1 AND |Ver| >= 0.2)';
    else
        ms_disp = 'off';
        good_disp = 'off';
        bad_disp = 'off';
    end
    
    % 1. 주기준국(Main Station) 플롯 (노란색 사각형)
    geoplot(gx_p, tbl.Station_Lat(1), tbl.Station_Lon(1), 'ks','Linewidth',2, ...
        'MarkerFaceColor', 'y', 'MarkerSize', 10, 'DisplayName', ms_disp);
    
    % 2. 이동국(Rover Points) 플롯
    hor_error = sqrt(tbl.East_Error.^2 + tbl.North_Error.^2);
    
    % (Hor >= 0.1 AND |Ver| >= 0.2)
    idx_bad = (hor_error >= Hor_threshold) & (abs(tbl.Up_Error) >= Ver_threshold);
    idx_good = ~idx_bad;
    
    % Good (파란색)
    geoplot(gx_p, tbl.Point_Lat(idx_good), tbl.Point_Lon(idx_good), 'b^', ...
        'MarkerFaceColor', 'b', 'MarkerSize', 6, 'DisplayName', good_disp);
    
    % Bad (검은색 테두리, 청록색 채우기)
    geoplot(gx_p, tbl.Point_Lat(idx_bad), tbl.Point_Lon(idx_bad), 'k^', ...
        'LineWidth', 1.2, ...
        'MarkerFaceColor', 'c', ...
        'MarkerSize', 6, ...
        'DisplayName', bad_disp);
end
% legend(gx_p, 'show', 'Location', 'southwest');
hold(gx_p, 'off');