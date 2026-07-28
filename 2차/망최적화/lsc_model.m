function M = lsc_model(refLon, refLat, qLon, qLat, mode, P)
% LSC_MODEL  공간이격오차 LSC 예측오차 모델 (reference/report.pdf 식(1))
%   sigma^2_pred(r) = C(0) - c(r)' (C + n0*I)^-1 c(r)
%   오차장(전리층·대류권 등 공간상관 오차)을 거리의존 공분산 C(d)를 갖는 확률장으로
%   보고, 기준국 관측으로부터 위치 r의 오차를 선형 예측했을 때 남는 잔차 분산을 계산.
%
%   mode 'full': 전 기준국 LSC — 주어진 공분산모델 하 최소분산 선형예측기(BLUP).
%                망 성능의 이론 하한(주 지표). 외삽/원거리에서 C0로 포화(이득 소멸).
%   mode 'tri' : 소속 들로네 삼각형 3국 barycentric 평면내삽 잔차
%                Var[d(r) - sum(lam_i*d_i)] + n0*sum(lam_i^2).
%                FKP/VRS가 실제 방송하는 평면 보정면과 정합(시스템 정합 지표).
%                report 식(3): sigma_full <= sigma_tri (전 지점).
%
%   P (시나리오 파라미터 struct):
%     .family  'gauss'(기본) | 'exp'  — 공분산족. gauss = 매끄러운 장
%              (실무 ppm 선형 RMS 규칙과 정합, report 표 1), exp = 거친 장.
%     .Lkm     상관거리 [km]
%     .C0EN/.C0U [cm^2]  수평축(E=N 등방)/수직 신호분산 직접 지정 — 또는
%     .ppmEN/.ppmU [ppm] 단일기선 잔차 RMS 기울기 앵커 (1 ppm = 0.1 cm/km):
%              gauss 소거리 D(d)=2*C0*(d/L)^2 에서 RMS = sqrt(2*C0)/L * d 이므로
%              C0 = (0.1*ppm*L)^2 / 2  [cm^2]
%     .sigNEN/.sigNU [cm]  국별 독립잡음(너깃) 표준편차. 기준국 위치에서
%              sigma -> 너깃 수준으로 수렴 (IDOP 모델의 도넛 아티팩트 해소).
%
%   출력 M: sigEcm=sigNcm(수평축), sigUcm [cm] / H95cm=2*sqrt(2)*sigE (2DRMS) /
%           V95cm=1.96*sigU / valid / nUsed / (tri) lamSq=sum(lam^2) 노이즈 이득
%
%   비고: 거리 = 하버사인 대원거리(R=6371.0088 km). barycentric 가중치는 lon/lat
%         평면에서 계산 — 아핀 불변이라 국소 km 평면과 사실상 동일(삼각형 규모의
%         cos(lat) 변화 ~1% 수준).

    refLon = refLon(:); refLat = refLat(:);
    qLon = qLon(:);     qLat = qLat(:);
    n = numel(refLon);  m = numel(qLon);
    if nargin < 5 || isempty(mode); mode = 'full'; end

    fam = 'gauss';
    if isfield(P, 'family') && ~isempty(P.family); fam = P.family; end
    L = P.Lkm;
    [C0EN, C0U] = resolve_C0(P, L, fam);
    sigNEN = field_def(P, 'sigNEN', 0);
    sigNU  = field_def(P, 'sigNU',  0);

    switch lower(mode)
        case 'full'
            Kref = kernel(hav_km(refLat, refLon, refLat', refLon'), L, fam);  % n x n
            Kq   = kernel(hav_km(refLat, refLon, qLat',  qLon'),  L, fam);   % n x m
            s2EN = lsc_var(C0EN, sigNEN, Kref, Kq);
            s2U  = lsc_var(C0U,  sigNU,  Kref, Kq);
            valid = true(m, 1);
            nUsed = repmat(n, m, 1);

        case 'tri'
            DT = delaunayTriangulation(refLon, refLat);
            ti = pointLocation(DT, qLon, qLat);
            valid = ~isnan(ti);
            s2EN = NaN(m,1); s2U = NaN(m,1); lamSq = NaN(m,1);
            iv = find(valid);
            if ~isempty(iv)
                lam = cartesianToBarycentric(DT, ti(iv), [qLon(iv) qLat(iv)]);  % |iv| x 3
                V = DT.ConnectivityList(ti(iv), :);                              % |iv| x 3
                KQ = zeros(numel(iv), 3);
                for c = 1:3
                    KQ(:,c) = kernel(hav_km(qLat(iv), qLon(iv), ...
                                            refLat(V(:,c)), refLon(V(:,c))), L, fam);
                end
                K12 = kernel(hav_km(refLat(V(:,1)),refLon(V(:,1)),refLat(V(:,2)),refLon(V(:,2))), L, fam);
                K13 = kernel(hav_km(refLat(V(:,1)),refLon(V(:,1)),refLat(V(:,3)),refLon(V(:,3))), L, fam);
                K23 = kernel(hav_km(refLat(V(:,2)),refLon(V(:,2)),refLat(V(:,3)),refLon(V(:,3))), L, fam);
                lamSq(iv) = sum(lam.^2, 2);
                crossK = lam(:,1).*lam(:,2).*K12 + lam(:,1).*lam(:,3).*K13 + lam(:,2).*lam(:,3).*K23;
                % 정규화 신호 잔차: 1 - 2*sum(lam*K(dq)) + sum(lam^2)*K(0) + 2*교차항
                shape = max(1 - 2*sum(lam.*KQ, 2) + lamSq(iv) + 2*crossK, 0);
                s2EN(iv) = C0EN*shape + sigNEN^2 * lamSq(iv);
                s2U(iv)  = C0U *shape + sigNU^2  * lamSq(iv);
            end
            nUsed = 3*double(valid);
            M.lamSq = lamSq;

        otherwise
            error('lsc_model: 알 수 없는 mode "%s" (full | tri)', mode);
    end

    M.mode = mode;  M.P = P;  M.C0EN = C0EN;  M.C0U = C0U;
    M.valid = valid;  M.nUsed = nUsed;
    s2EN(s2EN < 0) = 0;  s2U(s2U < 0) = 0;   % 음수만 클램프 — invalid(NaN)은 보존
    M.sigEcm = sqrt(s2EN);  M.sigNcm = M.sigEcm;   % (max(NaN,0)=0 이라 NaN이 σ=0으로 둔갑하던 버그 수정)
    M.sigUcm = sqrt(s2U);
    M.H95cm = 2*sqrt(2) * M.sigEcm;   % 수평 2DRMS (sigE = sigN 등방 가정)
    M.V95cm = 1.96 * M.sigUcm;
end

% ----------------------------------------------------------------------
function s2 = lsc_var(C0, sigN, Kref, Kq)
% s2(j) = C0 - c_j' (C + n0 I)^-1 c_j,  C = C0*Kref, c_j = C0*Kq(:,j)
    n = size(Kref, 1);
    A = C0*Kref + sigN^2 * eye(n);
    A = (A + A')/2;
    [Rc, pfail] = chol(A);
    jit = 1e-9;
    while pfail > 0 && jit <= 1e-3        % 너깃 0 + 근접 국 → 수치 특이 시 지터 (10배씩 증폭)
        warning('lsc_model:jitter', 'chol 실패 — 지터 %.0e*C0 적용 후 재시도', jit);
        [Rc, pfail] = chol(A + jit*C0*eye(n));
        jit = jit * 10;
    end
    if pfail > 0
        error('lsc_model:cholFail', '공분산 행렬 양정치화 실패 (지터 상한 도달) — 중복 좌표 국 확인 필요');
    end
    X = Rc' \ (C0*Kq);                    % c'A^-1 c = ||Rc'^-1 c||^2
    s2 = max(C0 - sum(X.^2, 1)', 0);
end

function K = kernel(d, L, fam)
    switch lower(fam)
        case {'gauss','gaussian'};  K = exp(-(d/L).^2);
        case {'exp','markov'};      K = exp(-d/L);
        otherwise; error('lsc_model: 알 수 없는 family "%s" (gauss | exp)', fam);
    end
end

function [C0EN, C0U] = resolve_C0(P, L, fam)
% ppm 앵커는 gauss 소거리 유도(D(d)=2C0(d/L)^2 → RMS 선형) 전용 —
% exp(Markov)는 RMS∝√d 라 선형 기울기 앵커가 정의되지 않음 → C0 직접 지정 강제.
    isGauss = any(strcmpi(fam, {'gauss','gaussian'}));
    if isfield(P, 'C0EN') && ~isempty(P.C0EN)
        C0EN = P.C0EN;
    else
        assert_gauss_anchor(isGauss);
        C0EN = (0.1*P.ppmEN*L)^2 / 2;     % ppm 앵커 (1 ppm = 0.1 cm/km)
    end
    if isfield(P, 'C0U') && ~isempty(P.C0U)
        C0U = P.C0U;
    else
        assert_gauss_anchor(isGauss);
        C0U = (0.1*P.ppmU*L)^2 / 2;
    end
end

function assert_gauss_anchor(isGauss)
    if ~isGauss
        error('lsc_model:ppmAnchor', ...
            'ppm 앵커는 gauss family 전용입니다 — exp family는 C0EN/C0U를 직접 지정하세요.');
    end
end

function v = field_def(P, f, def)
    if isfield(P, f) && ~isempty(P.(f)); v = P.(f); else; v = def; end
end

function d = hav_km(lat1, lon1, lat2, lon2)
% 하버사인 대원거리 [km] (implicit expansion 지원, R = 6371.0088 km)
    R = 6371.0088;
    p1 = deg2rad(lat1);  p2 = deg2rad(lat2);
    a = sin((p2-p1)/2).^2 + cos(p1).*cos(p2).*sin(deg2rad(lon2-lon1)/2).^2;
    d = 2*R*asin(min(sqrt(a), 1));
end
