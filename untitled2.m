% 1. 들로네 삼각망에서 '실제로 연결된' 모든 선분(Edge) 추출
% E 행렬은 [시작점 인덱스, 끝점 인덱스] 형태로 모든 연결선을 중복 없이 담고 있습니다.
E = edges(DT);
node1_idx = E(:, 1);
node2_idx = E(:, 2);

% 2. 각 노드의 위도, 경도 좌표 추출
lon1 = DT.Points(node1_idx, 1);
lat1 = DT.Points(node1_idx, 2);

lon2 = DT.Points(node2_idx, 1);
lat2 = DT.Points(node2_idx, 2);

% 3. 하버사인(Haversine) 공식을 이용한 구면 거리 계산 (벡터 연산)
R = 6371; % 지구 평균 반지름 (km)

lat1_rad = deg2rad(lat1);
lon1_rad = deg2rad(lon1);
lat2_rad = deg2rad(lat2);
lon2_rad = deg2rad(lon2);

dlat = lat2_rad - lat1_rad;
dlon = lon2_rad - lon1_rad;

a = sin(dlat/2).^2 + cos(lat1_rad) .* cos(lat2_rad) .* sin(dlon/2).^2;
c = 2 * atan2(sqrt(a), sqrt(1-a));

% 모든 연결된 기선의 거리 (단위: km)
baseline_distances_km = R * c;

% 4. 한눈에 볼 수 있도록 전체 데이터를 하나의 테이블로 통합
AllBaselinesTable = table(node1_idx, node2_idx, baseline_distances_km, ...
    'VariableNames', {'Node1', 'Node2', 'Distance_km'});

% (선택) 노드 번호 순으로 깔끔하게 오름차순 정렬
% AllBaselinesTable = sortrows(AllBaselinesTable, ['Node1', 'Node2']);
% 
% 5. 결과 확인
disp('==================================================');
fprintf('들로네 삼각분할로 생성된 전체 기선(연결선) 개수: %d개\n', height(AllBaselinesTable));
disp('==================================================');

% 상위 15개 행만 미리보기 출력 (매트랩 작업 공간(Workspace)에서 전체 확인 가능)
disp(head(AllBaselinesTable, 15));

% 1. 전체 지점(관측소)의 총 개수 확인
num_points = size(DT.Points, 1);

% 2. 개수를 저장할 배열 미리 만들기 (모두 0으로 초기화)
counts_under_15km = zeros(num_points, 1);

% 3. 1번 지점부터 마지막 지점까지 하나씩 확인
for i = 1:num_points
    % AllBaselinesTable에서 현재 지점(i)이 Node1이나 Node2에 포함된 행만 찾기
    is_connected = (AllBaselinesTable.Node1 == i) | (AllBaselinesTable.Node2 == i);
    
    % 현재 지점(i)과 연결된 기선들의 거리만 추출
    connected_distances = AllBaselinesTable.Distance_km(is_connected);
    
    % 추출된 거리 중 15km 이하(<= 15)인 것의 개수를 세어서 저장
    counts_under_15km(i) = sum(connected_distances <= 10);
end

% 4. 결과를 한눈에 볼 수 있도록 테이블(표)로 묶기
Node_Idx = (1:num_points)'; % 1번부터 N번까지의 인덱스 생성
EveryNodeTable = table(Node_Idx, counts_under_15km, ...
    'VariableNames', {'Node_Idx', 'Count_Under_15km'});

% 5. 결과 출력
disp('==================================================');
disp('각 지점별 15km 이하 기선거리 개수 (전체 목록)');
disp('==================================================');
disp(EveryNodeTable); % 전체 테이블 출력