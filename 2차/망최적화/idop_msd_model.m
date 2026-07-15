function M = idop_msd_model(refLon, refLat, qLon, qLat, mode)
% IDOP_MSD_MODEL  기준국 배치 기반 사용자 측위 성능 모델 (이예빈·박병운 2023)
%   출처: 이예빈, 박병운, "해양 및 내륙 정밀 PNT 사용자 성능 최적화를 위한
%         내륙 기준국 배치 연구", J. Adv. Navig. Technol. 27(4):396-409, 2023.
%   원 모델: Schwarz, Snay & Soler (2009), OPUS-RS 정확도 평가 (논문[26]).
%
%   σ_axis = sqrt( (α·IDOP)^2 + (β·MSD)^2 )                     [식 (21)]
%     IDOP = sqrt(R/Q) : 사용자 기준 상대좌표 평면 최소제곱 (A'A)^-1 의
%            (3,3) 원소 s33 (식 9-11). R = det(B), Q = det(A'A) — 수치 계산.
%            (항등식: IDOP^2 = 1/n + 마할라노비스^2/n — 사용국 집합
%             centroid 에서 최소 1/sqrt(n))
%     MSD  = mean(d_i^2) [km^2]                                  [식 (20)]
%
%   mode — 사용 기준국 선택 규칙:
%     'radius150' (기본) : 반경 150 km 이내 전체 (논문 3-1절 규칙.
%                          계수 적합 조건과 정합 — 절대값 판정용)
%     'tri'              : 질의점이 속한 들로네 삼각형 꼭짓점 3국
%                          (우리 VRS 설계와 정합. 단 n=3 에서는 IDOP 하한이
%                          1/sqrt(3)=0.577, 꼭짓점에서 1.0 이라 다국 기반
%                          계수로는 절대값이 보수적으로 편향됨)
%     'tri1ring'         : 삼각형 꼭짓점 3국 + 그 꼭짓점들과 델로네 간선으로
%                          연결된 인접국 (VRS 마스터+보조국 셀 구성과 유사,
%                          망 위상 정합 + n≈10 으로 계수 적합 범위와도 정합)
%
%   계수 (표 1, 2 — 미국 CORS 실측 기반. 추후 국내 실측으로 재추정 예정):
%     α(E,N,U) = 1.8785, 1.8785, 6.7259 [cm]
%     β(E,N,U) = 0.000032, 0.000032, 0.000078 [cm/km^2]
%   95% 변환 (논문 미명시 → 표준 관례 채택):
%     수평 95% = 2·sqrt(σE^2+σN^2) (2DRMS), 수직 95% = 1.96·σU
%
%   출력 M (struct, 질의점별 열벡터):
%     .H95cm, .V95cm  수평/수직 95% 예측 오차 [cm] (invalid 는 NaN)
%     .IDOP, .MSDkm2, .nUsed, .mode
%     .valid          false = 사용국 <3 / 기하 특이 / 망 외부(tri 계열)
%                     → 예측 불가 (논문의 제외 규칙에 해당)

    if nargin < 5; mode = 'radius150'; end
    RADIUS_KM = 150;
    ALPHA = [1.8785 1.8785 6.7259];        % E, N, U [cm]
    BETA  = [0.000032 0.000032 0.000078];  % E, N, U [cm/km^2]

    refLon = refLon(:); refLat = refLat(:);
    qLon = qLon(:);     qLat = qLat(:);
    nQ = numel(qLon);   nR = numel(refLon);

    % 선택 규칙별 사전 준비
    switch mode
        case 'radius150'
            dKm = zeros(nQ, nR);           % 질의점×기준국 거리 (WGS84 대원거리)
            for j = 1:nR
                dKm(:,j) = deg2km(distance(qLat, qLon, refLat(j), refLon(j)));
            end
        case {'tri', 'tri1ring'}
            DT = delaunayTriangulation(refLon, refLat);
            CL = DT.ConnectivityList;
            ti = pointLocation(DT, qLon, qLat);
            if strcmp(mode, 'tri1ring')    % 노드별 델로네 인접 목록
                Ed = edges(DT);
                adj = cell(nR, 1);
                for e = 1:size(Ed,1)
                    adj{Ed(e,1)}(end+1) = Ed(e,2);
                    adj{Ed(e,2)}(end+1) = Ed(e,1);
                end
            end
        otherwise
            error('idop_msd_model: 알 수 없는 mode "%s"', mode);
    end

    M.H95cm  = nan(nQ,1);  M.V95cm = nan(nQ,1);
    M.IDOP   = nan(nQ,1);  M.MSDkm2 = nan(nQ,1);
    M.nUsed  = zeros(nQ,1);
    M.valid  = false(nQ,1);
    M.mode   = mode;

    for i = 1:nQ
        switch mode
            case 'radius150'
                sel = find(dKm(i,:) <= RADIUS_KM);
                d = dKm(i, sel)';
            otherwise
                if isnan(ti(i)); continue; end          % 망(볼록껍질) 외부
                sel = CL(ti(i), :);
                if strcmp(mode, 'tri1ring')
                    sel = unique([sel, adj{sel(1)}, adj{sel(2)}, adj{sel(3)}]);
                end
                d = deg2km(distance(qLat(i), qLon(i), refLat(sel), refLon(sel)));
        end
        n = numel(sel);
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
        msd  = mean(d(:).^2);                         % 식 (20)
        sig  = sqrt((ALPHA*idop).^2 + (BETA*msd).^2); % 식 (21), [cm] E/N/U

        M.IDOP(i) = idop;  M.MSDkm2(i) = msd;
        M.H95cm(i) = 2 * sqrt(sig(1)^2 + sig(2)^2);   % 2DRMS
        M.V95cm(i) = 1.96 * sig(3);
        M.valid(i) = true;
    end
end
