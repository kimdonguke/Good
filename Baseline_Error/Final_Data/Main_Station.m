% clear; clc;
% 
% FKP = readtable('Final_FKP.xlsx');
% load('Net_FKP.mat');
% 
% %% Horizontal Main Station
% [~, idx_H] = ismember(FKP.Station_Lat,Net_H.Station_Lat);
% a = find(idx_H ~= 0);
% aa = sortrows([idx_H(a), a],1);
% 
% MS_H = cell(9,1);
% 
% for i=1:length(aa)
%     MS_H{aa(i),1} = [MS_H{aa(i),1}; FKP(aa(i,2),:)];
% end
% 
% 
% 
% %% Vertical Main Station
% [~, idx_V] = ismember(FKP.Station_Lat,Net_V.Station_Lat);
% a1 = find(idx_V ~= 0);
% aa1 = sortrows([idx_V(a1), a1]);
% 
% MS_V = cell(3,1);
% 
% for i=1:length(aa1)
%     MS_V{aa1(i),1} = [MS_V{aa1(i),1}; FKP(aa1(i,2),:)];
% end
% 
% %% Position Main Station
% [~, idx_P] = ismember(FKP.Station_Lat,Net_P.Station_Lat);
% a2 = find(idx_P ~= 0);
% aa2 = sortrows([idx_P(a2), a2]);
% aa2(5:7,1) = 2;
% aa2(8:10,1) = 3;
% MS_P = cell(4,1);
% 
% for i=1:length(aa2)
%     MS_P{aa2(i),1} = [MS_P{aa2(i),1}; FKP(aa2(i,2),:)];
% end
% % MS_P{2,1} = Net_P(2,1:10)
% 
%% 
clear; clc; %close all;

%% 0. 데이터 로드
load("MS_data.mat");
load("netRts.mat");
% 이 시점에 MS_H, MS_V, MS_P, netRts 변수가 로드됨

%% 1. 데이터 전처리: Baseline 및 오차 계산
% (MS_H, MS_V, MS_P 셀 배열을 플로팅용 T, T1, T2 테이블로 변환)

Hor_threshold = 0.1;
Ver_threshold = 0.2;
Pos_threshold = sqrt(Hor_threshold^2 + Ver_threshold^2);

% 측지계 설정 (WGS84, 단위: meter)
s = wgs84Ellipsoid('meter');

% --- T (Horizontal) 테이블 생성 ---
T_Hor_cell = cell(length(MS_H), 1);
for k = 1:length(MS_H)
    tbl = MS_H{k};
    if isempty(tbl), continue; end
    
    % 기준국(Origin) 좌표 (모든 행이 동일하므로 1번째 행 사용)
    [lat0, lon0, h0] = deal(tbl.Station_Lat(1), tbl.Station_Lon(1), tbl.Station_H(1));
    
    % 이동국(Point) 좌표
    [latP, lonP, hP] = deal(tbl.Point_Lat, tbl.Point_Lon, tbl.Point_H);
    
    % ENU 좌표계로 변환 -> 3D Baseline 계산
    [e, n, u] = geodetic2enu(latP, lonP, hP, lat0, lon0, h0, s);
    baseline = sqrt(e.^2 + n.^2 + u.^2);
    
    % 오차 계산
    hor_error = sqrt(tbl.East_Error.^2 + tbl.North_Error.^2);
    
    % 기준국 ID (Network ID)
    network_id = repmat(k, height(tbl), 1);
    
    % 플롯용 테이블 생성
    T_Hor_cell{k} = table(network_id, baseline, hor_error, ...
        'VariableNames', {'Hor_Network', 'Hor_Baseline', 'Hor_Error'});
end
T = vertcat(T_Hor_cell{:}); % T 변수 = Hor_Error 플롯용 최종 테이블

% --- T1 (Vertical) 테이블 생성 ---
T_Ver_cell = cell(length(MS_V), 1);
for k = 1:length(MS_V)
    tbl = MS_V{k};
    if isempty(tbl), continue; end
    [lat0, lon0, h0] = deal(tbl.Station_Lat(1), tbl.Station_Lon(1), tbl.Station_H(1));
    [latP, lonP, hP] = deal(tbl.Point_Lat, tbl.Point_Lon, tbl.Point_H);
    
    [e, n, u] = geodetic2enu(latP, lonP, hP, lat0, lon0, h0, s);
    baseline = sqrt(e.^2 + n.^2 + u.^2);
    
    ver_error = tbl.Up_Error; % 수직 오차
    network_id = repmat(k, height(tbl), 1);
    
    T_Ver_cell{k} = table(network_id, baseline, ver_error, ...
        'VariableNames', {'Ver_Network', 'Ver_Baseline', 'Ver_Error'});
end
T1 = vertcat(T_Ver_cell{:}); % T1 변수 = Ver_Error 플롯용 최종 테이블

% --- T2 (Position) 테이블 생성 ---
T_Pos_cell = cell(length(MS_P), 1);
for k = 1:length(MS_P)
    tbl = MS_P{k};
    if isempty(tbl), continue; end
    [lat0, lon0, h0] = deal(tbl.Station_Lat(1), tbl.Station_Lon(1), tbl.Station_H(1));
    [latP, lonP, hP] = deal(tbl.Point_Lat, tbl.Point_Lon, tbl.Point_H);
    
    [e, n, u] = geodetic2enu(latP, lonP, hP, lat0, lon0, h0, s);
    baseline = sqrt(e.^2 + n.^2 + u.^2);
    
    % 색상 구분을 위해 Hor, Ver 오차도 계산
    hor_error = sqrt(tbl.East_Error.^2 + tbl.North_Error.^2);
    ver_error = tbl.Up_Error;
    % 3D 위치 오차
    pos_error = sqrt(hor_error.^2 + ver_error.^2); 
    
    network_id = repmat(k, height(tbl), 1);
    
    % [중요] Pos 플롯은 색상 구분을 위해 Hor, Ver 오차도 포함해야 함
    T_Pos_cell{k} = table(network_id, baseline, pos_error, hor_error, ver_error, ...
        'VariableNames', {'Pos_Network', 'Pos_Baseline', 'Pos_Error', 'Hor_Error', 'Ver_Error'});
end
T2 = vertcat(T_Pos_cell{:}); % T2 변수 = Pos_Error 플롯용 최종 테이블

disp('--- 1. 전처리 완료 (T, T1, T2 테이블 생성됨) ---');
disp('T (Hor) 테이블 예시:');
disp(head(T));

%% 2. Horizontal Error Plot (이전 코드와 동일, T 사용)
figure; 
unique_networks = unique(T.Hor_Network);
num_networks = length(unique_networks);
t = tiledlayout('flow', 'TileSpacing', 'compact', 'Padding', 'compact');
title(t, 'Main Station별 Baseline에 따른 Horizontal Error', 'FontSize', 14); 
min_baseline = min(T.Hor_Baseline);
max_baseline = max(T.Hor_Baseline);
padding = (max_baseline - min_baseline) * 0.05;
x_lims = [min_baseline - padding, max_baseline + padding];
y_lims_hor = [0, max(T.Hor_Error) * 1.1]; 
for i = 1:num_networks
    current_net_id = unique_networks(i);
    idx = (T.Hor_Network == current_net_id);
    current_baseline = T.Hor_Baseline(idx);
    current_error = T.Hor_Error(idx);
    
    ax = nexttile;
    threshold = Hor_threshold;
    idx_above = (current_error > threshold);
    idx_below = (current_error <= threshold);
    
    stem(ax, current_baseline(idx_below), current_error(idx_below), 'filled', 'Color', 'b', 'MarkerFaceColor', 'b', 'MarkerSize', 4);
    hold(ax, 'on');
    stem(ax, current_baseline(idx_above), current_error(idx_above), 'filled', 'Color', 'r', 'MarkerFaceColor', 'r', 'MarkerSize', 4);
    hold(ax, 'off');
    
    title(ax, sprintf('Main Station %d (n=%d)', current_net_id, length(current_error))); 
    xlabel(ax, 'Hor Baseline (m)'); 
    ylabel(ax, 'Hor Error [m]'); 
    grid on;
    xlim(ax, x_lims);
    ylim(ax, y_lims_hor); 
    yline(ax, threshold, '--k', 'LineWidth', 1.5); 
end

%% 3. Vertical Error Plot (이전 코드와 동일, T1 사용)
figure;
unique_networks = unique(T1.Ver_Network);
num_networks = length(unique_networks);
t = tiledlayout('flow', 'TileSpacing', 'compact', 'Padding', 'compact');
title(t, 'Main Station별 Baseline에 따른 Vertical Error (Absolute)', 'FontSize', 14); 
min_baseline = min(T1.Ver_Baseline);
max_baseline = max(T1.Ver_Baseline);
padding = (max_baseline - min_baseline) * 0.05;
x_lims = [min_baseline - padding, max_baseline + padding];
y_lims_ver = [0, max(abs(T1.Ver_Error)) * 1.1];
for i = 1:num_networks
    current_net_id = unique_networks(i);
    idx = (T1.Ver_Network == current_net_id);
    current_baseline = T1.Ver_Baseline(idx);
    current_error = abs(T1.Ver_Error(idx));
    
    ax = nexttile;
    threshold = Ver_threshold;
    idx_above = (current_error > threshold);
    idx_below = (current_error <= threshold);
    
    stem(ax, current_baseline(idx_below), current_error(idx_below), 'filled', 'Color', 'b', 'MarkerFaceColor', 'b', 'MarkerSize', 4);
    hold(ax, 'on');
    stem(ax, current_baseline(idx_above), current_error(idx_above), 'filled', 'Color', 'r', 'MarkerFaceColor', 'r', 'MarkerSize', 4);
    hold(ax, 'off');
    
    title(ax, sprintf('Main Station %d (n=%d)', current_net_id, length(current_error))); 
    xlabel(ax, 'Ver Baseline (m)'); 
    ylabel(ax, 'Ver Error [m] (abs)'); 
    grid on;
    xlim(ax, x_lims);
    ylim(ax, y_lims_ver); 
    yline(ax, threshold, '--k', 'LineWidth', 1.5); 
end

%% 4. Position Error Plot (이전 코드와 동일, T2 사용)
% (Hor >= 0.1 AND |Ver| >= 0.2 조건으로 색상 구분)
figure;
unique_networks = unique(T2.Pos_Network);
num_networks = length(unique_networks);
t = tiledlayout('flow', 'TileSpacing', 'compact', 'Padding', 'compact');
title(t, 'Main Station별 Baseline에 따른 Position Error', 'FontSize', 14); 
min_baseline = min(T2.Pos_Baseline);
max_baseline = max(T2.Pos_Baseline);
padding = (max_baseline - min_baseline) * 0.05;
x_lims = [min_baseline - padding, max_baseline + padding];
y_lims_pos = [0, max(T2.Pos_Error) * 1.1]; 

for i = 1:num_networks
    current_net_id = unique_networks(i);
    idx = (T2.Pos_Network == current_net_id);
    
    current_baseline = T2.Pos_Baseline(idx);
    current_error = T2.Pos_Error(idx); 
    
    % 색상 구분을 위한 컴포넌트 에러 (T2에서 가져옴)
    current_hor_error = T2.Hor_Error(idx);
    current_ver_error = T2.Ver_Error(idx);
    
    % [수정] 임계값 기준 변경 (AND 조건)
    idx_above = (current_hor_error >= Hor_threshold) & (abs(current_ver_error) >= Ver_threshold);
    idx_below = ~idx_above; 
    
    ax = nexttile;
    
    stem(ax, current_baseline(idx_below), current_error(idx_below), 'filled', 'Color', 'b', 'MarkerFaceColor', 'b', 'MarkerSize', 4);
    hold(ax, 'on');
    stem(ax, current_baseline(idx_above), current_error(idx_above), 'filled', 'Color', 'r', 'MarkerFaceColor', 'r', 'MarkerSize', 4);
    hold(ax, 'off');
    
    title(ax, sprintf('Main Station %d (n=%d)', current_net_id, length(current_error))); 
    xlabel(ax, 'Pos Baseline (m)'); 
    ylabel(ax, 'Pos Error [m]');
    grid on;
    xlim(ax, x_lims);
    ylim(ax, y_lims_pos); 
    yline(ax, Pos_threshold, '--k', 'LineWidth', 1.5); 
end

