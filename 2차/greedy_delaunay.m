% 1. 초기 데이터 설정 (기존 위도, 경도)
% lon = rtsStations.LON_deg;
% lat = rtsStations.LAT_deg;
lon_opt = lon;
lat_opt = lat;

target_min_km = 30; % 최소 거리 목표 (30km)

disp('망 최적화(기준점 제거)를 시작합니다...');

% 2. 30km 미만 간선이 없어질 때까지 반복 제거 (While Loop)
while true
    % (1) 현재 남은 점들로 들로네 삼각망 생성
    DT = delaunayTriangulation(lon_opt, lat_opt);
    E = edges(DT); % 삼각망의 모든 간선(Edges) 추출
    
    % (2) 각 간선의 실제 물리적 거리(km) 계산
    % Mapping Toolbox의 distance 함수 사용 (WGS84 기준)
    arclen = distance(lat_opt(E(:,1)), lon_opt(E(:,1)), lat_opt(E(:,2)), lon_opt(E(:,2)));
    dist_km = deg2km(arclen);
    
    % (3) 30km 미만인 간선 찾기
    short_idx = find(dist_km < target_min_km);
    if isempty(short_idx)
        disp('모든 간선이 30km 이상으로 확보되었습니다! 최적화 종료.');
        break; 
    end
    
    % (4) 가장 짧은 간선을 이루는 두 노드(A, B) 찾기
    [~, min_idx] = min(dist_km);
    nodeA = E(min_idx, 1);
    nodeB = E(min_idx, 2);
    
    % (5) 커버리지 보호를 위해 외곽선(Boundary) 노드인지 확인
    B_nodes = boundary(lon_opt, lat_opt, 0.5);
    is_A_bound = ismember(nodeA, B_nodes);
    is_B_bound = ismember(nodeB, B_nodes);
    
    % (6) 지울 노드 결정 (외곽선 노드는 살리고 내부 노드를 지움)
    if is_A_bound && ~is_B_bound
        remove_node = nodeB;
    elseif is_B_bound && ~is_A_bound
        remove_node = nodeA;
    else
        % 둘 다 내부거나 둘 다 외곽이면, 주변에 연결된 짧은 간선이 더 많은(더 밀집된) 노드를 지움
        countA = sum(E(short_idx, 1) == nodeA | E(short_idx, 2) == nodeA);
        countB = sum(E(short_idx, 1) == nodeB | E(short_idx, 2) == nodeB);
        if countA >= countB
            remove_node = nodeA;
        else
            remove_node = nodeB;
        end
    end
    
    % (7) 선택된 노드 제거
    lon_opt(remove_node) = [];
    lat_opt(remove_node) = [];
end

fprintf('최초 기준점 수: %d개 -> 최적화 후 남은 기준점 수: %d개\n', length(lon), length(lon_opt));

% 3. 최적화된 결과 시각화
figure('Name', 'Optimized NRTK Network', 'Color', 'w');
gx = geoaxes;
hold(gx, 'on');
geobasemap(gx, 'topographic');

% 최적화된 삼각망(들로네) 생성
DT_opt = delaunayTriangulation(lon_opt, lat_opt);
tri = DT_opt.ConnectivityList;

% 폴리곤(회색 커버리지) 그리기
k = convhull(lon_opt, lat_opt);
pg_opt = geopolyshape(lat_opt(k), lon_opt(k));
geoplot(gx, pg_opt, 'k', 'EdgeColor', 'k', 'HandleVisibility', 'off');

% 삼각망의 선들 그리기
for i = 1:size(tri, 1)
    geoplot(gx, lat_opt(tri(i, [1 2 3 1])), lon_opt(tri(i, [1 2 3 1])), 'k-', 'LineWidth', 0.5, 'HandleVisibility', 'off');
end

% 남은 기준점 그리기
geoplot(gx, lat_opt, lon_opt, 'ks', 'MarkerFaceColor', 'y', 'MarkerSize', 6);

title(gx, 'NGII NRTK Network Configuration (Optimized 30-70km)');
geolimits(gx, [33 39], [125 131]);
hold(gx, 'off');