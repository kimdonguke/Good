function qc = qc_rules(T, cfg)
% QC_RULES  QC 기반 기준국 선별 규칙 — RsrchMt(2026-07-21, 김주헌) 방식
%   qc = qc_rules(T, cfg)
%     T   : load_stations() 4번째 출력 (qcAvail/qcMP1~5/qcSLPS/qcScore 열 —
%           QC xlsx 'NGII' 시트 조인본. 시트에 없는 국은 avail=0 취급)
%     cfg : net_config() (qcMinAvailRef / qcMaxSLPS / qcMPRef / qcScoreA7 / qcMinAvailMon)
%
%   문서의 선별 절차:
%     ① 외곽 기준국은 스코어링 대상 제외(기준국 유지) — 엔진의 isBoundary 예외로 처리
%     ② Availability < 95% 우선 cut-off            → refOK=false (x_i=0 고정)
%     ③ SLPS >= 임계값 추가 제외 (임계는 스윕으로 경험적 설정)
%     ④ 잔여국 MP 정규화 Q_MPi=min(1, 0.3/MPi), Score=(Q1·Q2·Q5)^(1/3) (MP5 없으면 √(Q1·Q2))
%     ⑤ A7 선형 부등식: Σ(S̄−S_j)x_j ≤ 0 — 선택 기준국 평균 Score ≥ 후보 평균 S̄
%   출력 qc: .avail .slps .score .refOK .monOK .useA7 .minAvailRef .maxSLPS .names
%   (monOK 는 문서 외 확장 — 가용성 미달 국은 셀 유효 판정의 감시국으로 카운트하지 않음)

    N = height(T);
    names = string(T.RINEX);

    a = zeros(N, 1);                       % 시트에 없으면 데이터 없음 → 0
    if ismember('qcAvail', T.Properties.VariableNames)
        v = T.qcAvail;  a(~isnan(v)) = v(~isnan(v));
    else
        warning('qc_rules:noQC', 'T 에 qcAvail 열이 없습니다 (make_stations_ngii 재실행 필요) — 전 국 0 취급.');
    end
    slps = Inf(N, 1);
    if ismember('qcSLPS', T.Properties.VariableNames)
        v = T.qcSLPS;  slps(~isnan(v)) = v(~isnan(v));
    end
    score = NaN(N, 1);
    if ismember('qcScore', T.Properties.VariableNames)
        score = T.qcScore;
    end

    % 가용성 임계: 고정(qcMinAvailRef) 또는 분포 기반(mean − k·std, 가동국 avail>0 기준)
    if isfield(cfg, 'qcAvailSigmaK') && ~isempty(cfg.qcAvailSigmaK)
        oper = a > 0;                        % avail=0(완전 미제공)은 분포에서 제외 + 무조건 컷
        thrA = mean(a(oper)) - cfg.qcAvailSigmaK * std(a(oper));
        availOK = oper & (a >= thrA);
        availDesc = sprintf('Availability>=%.3f (=mean−%g·std, 가동국 기준; 0은 무조건 컷)', ...
            thrA, cfg.qcAvailSigmaK);
        thrMon = thrA;
    else
        availOK = a >= cfg.qcMinAvailRef;
        availDesc = sprintf('Availability>=%.2f (고정)', cfg.qcMinAvailRef);
        thrMon = cfg.qcMinAvailMon;
    end
    slpsOK = slps < cfg.qcMaxSLPS;

    qc.avail = a;  qc.slps = slps;  qc.score = score;  qc.names = names;
    qc.availThr = thrMon;                % 유효 가용성 임계 (고정 또는 mean−k·std)
    qc.minAvailRef = cfg.qcMinAvailRef;  qc.maxSLPS = cfg.qcMaxSLPS;
    qc.refOK = availOK & slpsOK;
    qc.useA7 = isfield(cfg, 'qcScoreA7') && cfg.qcScoreA7;
    qc.monOK = (a > 0) & (a >= thrMon);

    fprintf('[QC 규칙/RsrchMt] %s & SLPS<%g, A7(평균 Score 제약)=%d\n', ...
        availDesc, cfg.qcMaxSLPS, qc.useA7);
    cutA = find(~availOK);
    fprintf('  Availability cut-off %d국: %s\n', numel(cutA), ...
        strjoin(compose("%s(%.2f)", names(cutA), a(cutA))', ', '));
    cutS = find(availOK & ~slpsOK);
    if ~isempty(cutS)
        fprintf('  SLPS 추가 제외 %d국: %s\n', numel(cutS), ...
            strjoin(compose("%s(%.1f)", names(cutS), slps(cutS))', ', '));
    else
        fprintf('  SLPS 추가 제외 없음\n');
    end
end
