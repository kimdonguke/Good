function cfg = net_config()
% NET_CONFIG  망 최적화 공통 실험 조건 (단일 소스)
%   run_greedy_area_max / run_ilp_area_max / 통합파이프라인 이 모두 이 값을 사용한다.
%   조건을 바꿀 때는 여기 한 곳만 수정하면 모든 드라이버가 동일 조건으로 정렬된다.
%   (plots/run_stats.m 은 결과 .mat 에 저장된 maxBaseKm 을 읽으므로 자동 반영)

    cfg.maxBaseKm = 70;    % 신설 기선 최대 길이 [km] (초기망의 초과 기선은 grandfather 예외)
                           % 2026-07-27 사용자 지시로 공식 기본값 100 -> 70 변경.
                           % (100km QC 확정망 43/59·93,163km2 는 커밋 bf62001 이력 보존)
    cfg.qcEnable  = false; % QC cut-off 적용 여부. 70km 기본망은 QC 규칙과 비실현
                           % (SLPS 탈락 BONH·YONK가 70km 기하의 구조적 필수국)이라
                           % 사용자 결정으로 QC는 추후 진행 — 당분간 비활성.
                           % true 로 되돌리면 아래 컷·A7·감시인정 제한이 전부 복원된다.
    cfg.nOuter    = 13;    % 최외곽 고정 노드 수 (볼록껍질 + 경계 근접 순 자동 보충)
    cfg.outerForce = "YODK";
    % ↑ 외곽 강제 보완국: 동해안 요철 보완용 YODK. 97국 시절엔 outer_ring(13)이
    %   자동 선정(볼록껍질12+YODK)했으나, 신설 도서 5국 가동(2026-07)으로 볼록껍질이
    %   10국(ULDO 포함)으로 바뀌며 자동 보충이 남해안(PSJA·PUSN·SSAN)으로 이동 →
    %   YODK가 탈락하면 동해안 QC 컷 군집(YODK·YONK·YDKG·YEOJ·YCMP)을 덮을 수 없어
    %   ILP 비실현. 드라이버가 bnd = outer_ring(...) ∪ outerForce 로 합집합 처리.

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
