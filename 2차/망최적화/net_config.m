function cfg = net_config()
% NET_CONFIG  망 최적화 공통 실험 조건 (단일 소스)
%   run_greedy_area_max / run_ilp_area_max / 통합파이프라인 이 모두 이 값을 사용한다.
%   조건을 바꿀 때는 여기 한 곳만 수정하면 모든 드라이버가 동일 조건으로 정렬된다.
%   (plots/run_stats.m 은 결과 .mat 에 저장된 maxBaseKm 을 읽으므로 자동 반영)

    cfg.maxBaseKm = 100;   % 신설 기선 최대 길이 [km] (초기망의 초과 기선은 grandfather 예외)
    cfg.nOuter    = 13;    % 최외곽 고정 노드 수 (볼록껍질 12 + 동해안 YODK = 13)

    % QC 기반 기준국 선별 규칙 — RsrchMt(2026-07-21, 김주헌) 방식.
    %  지표 소스 = QC xlsx 'NGII' 시트(RINGO 연간: Availability·MP1/2/5·SLPS),
    %  stations_ngii.mat 에 조인됨. qc_rules.m 이 마스크/Score 생성 → 그리디/ILP 반영.
    cfg.qcMinAvailRef = 0.95;  % ① Availability 95% 미만 cut-off (기준국 부적격, x_i=0
                               %    고정). 외곽 고정국은 스코어링 대상 제외(기준국 유지).
    cfg.qcAvailSigmaK = 3;     % ①' 분포 기반 컷(기본): 임계 = mean − k·std (가동국 avail>0
                               %    분포 기준; avail=0 완전 미제공 국은 무조건 컷). [] = 고정
                               %    qcMinAvailRef 사용. 2025 데이터에선 2σ(0.892)와 3σ(0.852)가
                               %    동일 망을 주고(0.83 그룹 컷, INCH는 SLPS로 걸림),
                               %    고정 0.95 대비 WNJU(0.93) 생존 → 면적 +2.7% (87,543 km²).
    cfg.qcMaxSLPS     = 10;    % ② SLPS 임계 초과 추가 제외 — 문서 지침대로 망 재구성
                               %    반복 비교(스윕)로 경험적 설정. Inf = 비활성.
    cfg.qcMPRef       = 0.3;   % ③ MP 정규화 기준 [m] (IGS 권고값)
    cfg.qcScoreA7     = true;  % ④ A7 평균 품질 제약: 선택 기준국 평균 Score >= 후보 평균
    cfg.qcMinAvailMon = 0.95;  % (문서 외 확장 유지) 감시 인정 하한 — 미달 국은 셀 유효
                               %  판정에 카운트하지 않음
end
