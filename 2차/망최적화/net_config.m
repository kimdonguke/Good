function cfg = net_config()
% NET_CONFIG  망 최적화 공통 실험 조건 (단일 소스)
%   run_greedy_area_max / run_ilp_area_max / 통합파이프라인 이 모두 이 값을 사용한다.
%   조건을 바꿀 때는 여기 한 곳만 수정하면 모든 드라이버가 동일 조건으로 정렬된다.
%   (plots/run_stats.m 은 결과 .mat 에 저장된 maxBaseKm 을 읽으므로 자동 반영)

    cfg.maxBaseKm = 70;    % 신설 기선 최대 길이 [km] (초기망의 초과 기선은 grandfather 예외)
    cfg.nOuter    = 13;    % 최외곽 고정 노드 수 (볼록껍질 12 + 동해안 YODK = 13)
end
