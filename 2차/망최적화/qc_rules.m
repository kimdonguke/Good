function qc = qc_rules(T, cfg)
% QC_RULES  관측소 가용성(QC) 기반 설계 규칙 마스크 생성 (net_config 임계값 단일 소스)
%   qc = qc_rules(T, cfg)
%     T   : load_stations() 4번째 출력 (qcAvailQ4 열 사용; 없거나 NaN 이면 1.0 간주)
%     cfg : net_config() (qcMinAvailRef / qcMinAvailMon)
%   출력 qc struct:
%     .avail       : N×1 가용률 (2025-Q4 OK 비율)
%     .refOK       : avail >= qcMinAvailRef  — 기준국 자격 (엔진에서 외곽 고정국은 예외 처리)
%     .monOK       : avail >= qcMinAvailMon  — 감시 인정 (셀 유효 판정 카운트 대상)
%     .minAvailRef / .minAvailMon / .names
%   그리디/ILP 엔진에 전달하면: ~refOK & ~외곽 → x_i=0 강제(감시국 전환),
%   셀 유효 = monOK 감시국 포함 셀. qc=[] 전달 시 규칙 미적용(legacy).

    N = height(T);
    a = ones(N, 1);
    if ismember('qcAvailQ4', T.Properties.VariableNames)
        v = T.qcAvailQ4;
        a(~isnan(v)) = v(~isnan(v));
    else
        warning('qc_rules:noQC', 'T 에 qcAvailQ4 열이 없어 전 국 가용률 1.0 으로 간주합니다 (make_stations_ngii 재실행 필요).');
    end

    qc.avail = a;
    qc.minAvailRef = cfg.qcMinAvailRef;
    qc.minAvailMon = cfg.qcMinAvailMon;
    qc.refOK = a >= qc.minAvailRef;
    qc.monOK = a >= qc.minAvailMon;
    qc.names = string(T.RINEX);

    fprintf('[QC 규칙] 가용률(2025-Q4) 임계: 기준국 %.2f / 감시 인정 %.2f\n', ...
        qc.minAvailRef, qc.minAvailMon);
    if any(~qc.refOK)
        bad = find(~qc.refOK);
        fprintf('  기준국 부적격 %d국: %s\n', numel(bad), ...
            strjoin(compose("%s(%.0f%%)", qc.names(bad), 100*a(bad))', ', '));
    else
        fprintf('  기준국 부적격 없음\n');
    end
    ex = find(qc.refOK & ~qc.monOK);
    if ~isempty(ex)
        fprintf('  감시 인정 추가 제외 %d국: %s\n', numel(ex), strjoin(qc.names(ex)', ', '));
    end
end
