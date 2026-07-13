function M = idop_msd_model(refLon, refLat, qLon, qLat)
% IDOP_MSD_MODEL  기준국 배치 기반 사용자 측위 성능 모델 (이예빈·박병운 2023)
%   출처: 이예빈, 박병운, "해양 및 내륙 정밀 PNT 사용자 성능 최적화를 위한
%         내륙 기준국 배치 연구", J. Adv. Navig. Technol. 27(4):396-409, 2023.
%   원 모델: Schwarz, Snay & Soler (2009), OPUS-RS 정확도 평가 (논문[26]).
%
%   σ_axis = sqrt( (α·IDOP)^2 + (β·MSD)^2 )                     [식 (21)]
%     IDOP = sqrt(R/Q) : 사용자 기준 상대좌표 평면 최소제곱 (A'A)^-1 의
%            (3,3) 원소 s33 (식 9-11). R = det(B), Q = det(A'A) — 수치 계산.
%     MSD  = mean(d_i^2) [km^2]                                  [식 (20)]
%   사용 기준국: 질의점 반경 150 km 이내 (논문 3-1절 시뮬레이션 규칙)
%   계수 (표 1, 2 — 미국 CORS 실측 기반. 추후 국내 실측으로 재추정 예정):
%     α(E,N,U) = 1.8785, 1.8785, 6.7259 [cm]
%     β(E,N,U) = 0.000032, 0.000032, 0.000078 [cm/km^2]
%   95% 변환 (논문 미명시 → 표준 관례 채택):
%     수평 95% = 2·sqrt(σE^2+σN^2) (2DRMS), 수직 95% = 1.96·σU
%
%   출력 M (struct, 질의점별 열벡터):
%     .H95cm, .V95cm  수평/수직 95% 예측 오차 [cm] (invalid 는 NaN)
%     .IDOP, .MSDkm2, .nUsed
%     .valid          false = 반경 내 기준국 <3 또는 기하 특이 → 예측 불가
%                     (논문의 "측위 성능 예측 불가 지점" 제외 규칙에 해당)

    RADIUS_KM = 150;
    ALPHA = [1.8785 1.8785 6.7259];        % E, N, U [cm]
    BETA  = [0.000032 0.000032 0.000078];  % E, N, U [cm/km^2]

    refLon = refLon(:); refLat = refLat(:);
    qLon = qLon(:);     qLat = qLat(:);
    nQ = numel(qLon);   nR = numel(refLon);

    % 질의점×기준국 거리 행렬 (WGS84 대원거리)
    dKm = zeros(nQ, nR);
    for j = 1:nR
        dKm(:,j) = deg2km(distance(qLat, qLon, refLat(j), refLon(j)));
    end

    M.H95cm  = nan(nQ,1);  M.V95cm = nan(nQ,1);
    M.IDOP   = nan(nQ,1);  M.MSDkm2 = nan(nQ,1);
    M.nUsed  = zeros(nQ,1);
    M.valid  = false(nQ,1);

    for i = 1:nQ
        sel = dKm(i,:) <= RADIUS_KM;
        n = nnz(sel);
        M.nUsed(i) = n;
        if n < 3; continue; end

        % 사용자 기준 상대좌표 [km] (국지 등장방형 근사 — IDOP 는 축척 불변)
        dx = deg2km(refLon(sel) - qLon(i)) .* cosd(qLat(i));
        dy = deg2km(refLat(sel) - qLat(i));

        Sx = sum(dx); Sy = sum(dy);
        Sxx = sum(dx.^2); Syy = sum(dy.^2); Sxy = sum(dx.*dy);
        R = Sxx*Syy - Sxy^2;                          % 식 (10)
        Q = det([Sxx Sxy Sx; Sxy Syy Sy; Sx Sy n]);   % 식 (11)
        if R <= 0 || Q <= 0; continue; end            % 일직선 배치 등 특이

        idop = sqrt(R/Q);                             % 식 (9)
        msd  = mean(dKm(i,sel).^2);                   % 식 (20)
        sig  = sqrt((ALPHA*idop).^2 + (BETA*msd).^2); % 식 (21), [cm] E/N/U

        M.IDOP(i) = idop;  M.MSDkm2(i) = msd;
        M.H95cm(i) = 2 * sqrt(sig(1)^2 + sig(2)^2);   % 2DRMS
        M.V95cm(i) = 1.96 * sig(3);
        M.valid(i) = true;
    end
end
