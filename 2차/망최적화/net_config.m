function cfg = net_config()
% NET_CONFIG  망 최적화 공통 실험 조건 (단일 소스)
%   run_greedy_area_max / run_ilp_area_max / 통합파이프라인 이 모두 이 값을 사용한다.
%   조건을 바꿀 때는 여기 한 곳만 수정하면 모든 드라이버가 동일 조건으로 정렬된다.
%   (plots/run_stats.m 은 결과 .mat 에 저장된 maxBaseKm 을 읽으므로 자동 반영)

    cfg.maxBaseKm = 100;   % 신설 기선 최대 길이 [km] (초기망의 초과 기선은 grandfather 예외)
    cfg.nOuter    = 13;    % 최외곽 고정 노드 수 (볼록껍질 12 + 동해안 YODK = 13)

    % QC 가용성 설계 규칙 (stations_ngii.mat 의 qcAvailQ4 = 2025-Q4 OK 비율 기준;
    %  qc_rules.m 이 마스크 생성 → 그리디/ILP 에 선형 부등식(변수 고정)으로 반영)
    cfg.qcMinAvailRef = 0.95;  % 기준국 자격 하한: 미달 국은 감시국 전환 강제 (x_i=0).
                               %  단, 외곽 고정국은 커버리지 구조상 예외(경고만).
    cfg.qcMinAvailMon = 0.95;  % 감시 인정 하한: 미달 국은 셀 유효 판정에 카운트하지 않음
                               %  (그 국만 든 셀은 "감시가능"으로 세지 않음)
end
