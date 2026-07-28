%% run_validation_lsc.m — 망 타당성 검증 v2: LSC 공간이격오차 모델 (전/후 비교)
% 기존 run_validation.m 2단계(IDOP·MSD)를 대체하는 새 오차 커널.
% 근거 문서: reference/report.pdf — LSC(최소제곱 콜로케이션) 예측오차분산 식(1)
%   sigma^2_pred(r) = C(0) - c(r)' (C + n0*I)^-1 c(r)
% 커널 구현: lsc_model.m (전역 LSC / 들로네 3국 평면내삽 2규칙)
%
% ─── 핵심 해석 노트 (v2) ─────────────────────────────────────────────────
% [IDOP·MSD 대비 왜 교체하나]
%   ① IDOP는 보간 가중치 노름(축척 불변) → 망 밀도 변별력 없음.
%   ② 거리항 β·MSD는 차용 계수로는 수치적으로 죽어 있음(셀 2배 확대에 +0.9%).
%   ③ 기준국 위에서 오차 →0 수렴 구조가 없어 도넛 아티팩트 발생.
%   LSC 커널은 셋 다 해소: 밀도·거리 민감(d^κ 성장 + d≫L 포화), 기준국 위
%   σ→너깃, 편측 외삽 페널티 유지. legacy 결과는 validation_error_summary.txt.
% [규칙 2종]
%   full: 전역 LSC = 주어진 공분산모델 하 최소분산 선형예측기(BLUP) — 주 지표.
%   tri : 들로네 3국 barycentric 평면내삽 잔차 — FKP/VRS가 실제 방송하는
%         평면 보정면과 정합. report 식(3)에 의해 σ_full ≤ σ_tri (전 지점),
%         차이(국소성 페널티)는 삼각형 공유변 근처에 집중(report §7: 평균 ~3%).
% [공분산/앵커] Gaussian C0·exp(-d²/L²) — 실무 ppm 선형 RMS 규칙과 정합
%   (report 표 1: ppm 선형규칙 = 매끄러운 장 가정). 소거리에서 단일기선 잔차
%   RMS ≈ 0.1·ppm·d [cm] 가 되도록 C0 = (0.1·ppm·L)²/2 로 앵커링.
% [시나리오 3종 — ★ 잠정 공학 앵커값 ★]
%   전리층 활동도에 따라 (ppm, L)이 크게 변하므로 정온/활동/폭풍 3점 평가.
%   수치는 문헌 관례 수준의 잠정값(국내 실측 미적합) — 상대 비교·민감도 해석
%   용도로 쓰고, 절대 유계 판정의 확정은 국내 적합 후로 미룰 것.
%   국내 적합 경로: 위성기준점 전 관측소 leave-one-out 보간 잔차로 (C0, L, n0)
%   직접 추정(신규 관측 불필요, RINEX/보정 데이터 처리 필요) — IDOP·MSD의
%   α·β 재적합 계획을 대체.
% [해석 요령]
%   - a/L 이 지배 변수(report §5: 정삼각형 국간거리 0.5L/1L/2L에서 무게중심
%     분산 0.24/0.46/0.77·C0). 같은 망이라도 폭풍(L↓)이면 a/L이 커져 성능 저하.
%   - 외삽/원거리에서 σ는 폭주가 아니라 √C0(망 이득 소멸 = 단독측위 수준)로
%     포화 — 초과 지역은 "이득 소멸 구역"으로 읽을 것.
%   - 기준국(구 기준국 포함) 위치에서는 σ ≈ 너깃(0.3/0.6 cm) 바닥.
% [평가 규칙] 기존과 동일: 만족율 분모 = 공통 도메인 전체 격자(예측불가는
%   불만족 집계), 평균은 예측불가·100 cm 이상 제외. 95% 변환: 수평 2DRMS =
%   2√(σE²+σN²), 수직 1.96·σU. 유계: 수평 5 cm / 수직 10 cm.
% ─────────────────────────────────────────────────────────────────────────
% 출력: validation_lsc_summary.txt / validation_lsc.mat / validation_lsc_monitors.csv
%       validation_lsc_cdf.png / validation_lsc_map_{old,new}.png
%       / validation_lsc_exceed_{old,new}.png / validation_lsc_scen.png
%       (지도류 figure는 한 figure에 지도 1개 규격 — 망별 개별 파일)

clear; clc; close all;

% ---- 프로젝트 경로 자동 설정 ----
thisDir = fileparts(mfilename('fullpath'));
if isempty(thisDir); thisDir = pwd; end
projectRoot = thisDir;
while ~isfolder(fullfile(projectRoot, 'Src'))
    parentDir = fileparts(projectRoot);
    if isempty(parentDir) || strcmp(parentDir, projectRoot); projectRoot = thisDir; break; end
    projectRoot = parentDir;
end
ngiiPaths = {thisDir, projectRoot, fullfile(projectRoot,'Src'), ...
    fullfile(projectRoot,'Src','Reference Code'), ...
    fullfile(projectRoot,'Data','rts'), fullfile(projectRoot,'dd')};
for pIdx = 1:numel(ngiiPaths)
    if isfolder(ngiiPaths{pIdx}); addpath(ngiiPaths{pIdx}); end
end
% ---------------------------------

%% 1) 결과/원망 로드 + 공통 도메인 격자 (run_validation 1단계와 동일 정의)
S = load(fullfile(thisDir, 'result_ilp.mat'));  R = S.R;
lonAll = R.lon(:); latAll = R.lat(:); isRef = logical(R.isRef(:));
lonMon = lonAll(~isRef); latMon = latAll(~isRef);
namesMon = string(R.names(~isRef));
nM = numel(lonMon);
fprintf('최적망 로드: 기준국 %d, 감시국 %d, maxBaseKm=%g\n', nnz(isRef), nM, R.maxBaseKm);

GRID_DEG = 0.025;
[glon, glat] = meshgrid(125:GRID_DEG:131, 33:GRID_DEG:39);
glon = glon(:); glat = glat(:);
Gold = net_geometry(lonAll, latAll, glon, glat);
Gnew = net_geometry(lonAll(isRef), latAll(isRef), glon, glat);
common = Gold.inTri & Gnew.inTri;
fprintf('격자 %d점, 공통 도메인 %d점\n', numel(glon), nnz(common));

%% 2) 시나리오 정의 (★ 잠정 공학 앵커 — 국내 적합 전 상대비교/민감도 용도 ★)
SCEN = struct( ...
    'name',   {'정온', '활동', '폭풍'}, ...
    'ppmEN',  {0.5,    1.5,    4.0}, ...   % 수평축 단일기선 잔차 RMS 기울기 [ppm]
    'ppmU',   {1.0,    3.0,    8.0}, ...   % 수직 (대류권 잔차·기하로 수평의 ~2배)
    'Lkm',    {150,    60,     30}, ...    % 상관거리 (활동도↑ → L↓)
    'sigNEN', {0.3,    0.3,    0.3}, ...   % 국별 독립잡음 너깃 [cm]
    'sigNU',  {0.6,    0.6,    0.6}, ...
    'family', {'gauss','gauss','gauss'});
DESIGN = 2;   % 설계 판정 시나리오(지도·감시국 상세·초과 figure) = 활동
nS = numel(SCEN);

HOR_LIM = 5; VER_LIM = 10; OUT_LIM = 100;   % [cm]
rules = {'full', 'tri'};
ruleLabel = {'전역 LSC (BLUP)', '들로네 3국 평면내삽 (FKP/VRS 정합)'};

%% 3) 격자·감시국 계산 (시나리오 x 규칙 x 2망)
fprintf('[v2] LSC 오차 모델 적용 중 (격자 %d점 x 2망 x %d시나리오 x %d규칙)...\n', ...
    numel(glon), nS, numel(rules));
Eo = cell(nS, 2); En = Eo; So = Eo; Sn = Eo;
EoM = cell(nS, 1); EnM = EoM;
for s = 1:nS
    P = SCEN(s);
    for r = 1:numel(rules)
        Eo{s,r} = lsc_model(lonAll, latAll, glon, glat, rules{r}, P);
        En{s,r} = lsc_model(lonAll(isRef), latAll(isRef), glon, glat, rules{r}, P);
        So{s,r} = err_stats(Eo{s,r}, common, HOR_LIM, VER_LIM, OUT_LIM);
        Sn{s,r} = err_stats(En{s,r}, common, HOR_LIM, VER_LIM, OUT_LIM);
    end
    EoM{s} = lsc_model(lonAll, latAll, lonMon, latMon, 'full', P);
    EnM{s} = lsc_model(lonAll(isRef), latAll(isRef), lonMon, latMon, 'full', P);
    fprintf('  시나리오 %d/%d (%s) 완료\n', s, nS, P.name);
end

%% 4) 요약 txt (UTF-8)
sumFile = fullfile(thisDir, 'validation_lsc_summary.txt');
fid = fopen(sumFile, 'w', 'n', 'UTF-8');
w = @(varargin) fprintf(fid, varargin{:});
w('===== 망 타당성 검증 v2: LSC 공간이격오차 모델 (%s) =====\n', datestr(now, 'yyyy-mm-dd HH:MM'));
w('모델: sigma^2_pred(r) = C(0) - c''(C+n0*I)^-1 c  (reference/report.pdf 식(1))\n');
w('규칙: [full] 전역 LSC(BLUP, 주지표) / [tri] 들로네 3국 평면내삽(FKP/VRS 보정면 정합)\n');
w('공분산: Gaussian C0*exp(-d^2/L^2), 앵커 C0 = (0.1*ppm*L)^2/2 (단일기선 RMS = ppm*d 정합)\n');
w('95%% 변환: 수평 2DRMS = 2*sqrt(sE^2+sN^2), 수직 1.96*sU / 유계: 수평 %g cm, 수직 %g cm\n', HOR_LIM, VER_LIM);
w('*** 시나리오 파라미터는 잠정 공학 앵커 — 절대 판정은 국내 적합(전 관측소 LOO 잔차) 후 확정 ***\n\n');

w('[0] 시나리오 정의 (수평축 기준)\n');
w('  이름   ppm(EN/U)   L[km]   C0EN[cm^2]  포화 sigEN[cm]  포화 H95[cm]  너깃(EN/U)[cm]\n');
for s = 1:nS
    C0 = (0.1*SCEN(s).ppmEN*SCEN(s).Lkm)^2/2;
    w('  %-4s   %3.1f/%3.1f    %4d    %8.1f    %8.2f      %8.2f      %.1f/%.1f\n', ...
        SCEN(s).name, SCEN(s).ppmEN, SCEN(s).ppmU, SCEN(s).Lkm, ...
        C0, sqrt(C0), 2*sqrt(2)*sqrt(C0), SCEN(s).sigNEN, SCEN(s).sigNU);
end
w('  (포화 = 망 이득 소멸 시 수렴값. a/L이 지배 변수 — report §5)\n\n');

w('[1] 시나리오 x 규칙 매트릭스 (공통 도메인 %d점, %g도 격자)\n', nnz(common), GRID_DEG);
w('  시나리오  규칙                                  망      만족율H%%  만족율V%%   평균H     평균V     최대H\n');
for s = 1:nS
    for r = 1:numel(rules)
        w('  %-4s      %-34s  이전   %8.2f  %8.2f  %8.2f  %8.2f  %8.2f\n', ...
            SCEN(s).name, ruleLabel{r}, So{s,r}.ratioH, So{s,r}.ratioV, So{s,r}.avgH, So{s,r}.avgV, So{s,r}.maxH);
        w('  %-4s      %-34s  최적   %8.2f  %8.2f  %8.2f  %8.2f  %8.2f\n', ...
            '', '', Sn{s,r}.ratioH, Sn{s,r}.ratioV, Sn{s,r}.avgH, Sn{s,r}.avgV, Sn{s,r}.maxH);
    end
end
w('\n');

w('[2] 감시국 %d점 (전환 지점, 전역 LSC)\n', nM);
w('  시나리오   망      평균H95    최대H95    평균V95    최대V95   유계초과(H/V)\n');
for s = 1:nS
    badH = EnM{s}.H95cm > HOR_LIM;  badV = EnM{s}.V95cm > VER_LIM;
    w('  %-4s       이전   %8.2f  %8.2f  %8.2f  %8.2f       -\n', SCEN(s).name, ...
        mean(EoM{s}.H95cm), max(EoM{s}.H95cm), mean(EoM{s}.V95cm), max(EoM{s}.V95cm));
    w('  %-4s       최적   %8.2f  %8.2f  %8.2f  %8.2f    %d / %d\n', '', ...
        mean(EnM{s}.H95cm), max(EnM{s}.H95cm), mean(EnM{s}.V95cm), max(EnM{s}.V95cm), ...
        nnz(badH), nnz(badV));
    if s == DESIGN && any(badH | badV)
        w('             (%s 초과 감시국: %s)\n', SCEN(s).name, strjoin(namesMon(badH | badV), ', '));
    end
end
w('  (이전 망에서 감시국 지점은 기준국 자체였으므로 너깃 바닥 수준이 정상)\n\n');

pen = En{DESIGN,2}.H95cm - En{DESIGN,1}.H95cm;   % tri - full (BLUP 부등식으로 >= 0)
ok2 = common & En{DESIGN,2}.valid;
w('[3] 규칙 간 페널티 (최적망, %s): 평균 dH95 = %.2f cm, 최대 %.2f cm, 음수 지점 %d\n', ...
    SCEN(DESIGN).name, mean(pen(ok2)), max(pen(ok2)), nnz(pen(ok2) < -1e-9));
w('  (report 식(3): sigma_full <= sigma_tri. 페널티는 삼각형 공유변 근처 집중 — §7 평균 ~3%%)\n\n');

w('[4] legacy IDOP·MSD 대조: validation_error_summary.txt 참조.\n');
w('  구조 차이: IDOP=잡음 증폭(축척 불변)+MSD 거리항 사실상 0 → 밀도 변별 없음/도넛.\n');
w('  LSC는 밀도·활동도(a/L) 민감 + 기준국 위 너깃 바닥 + 원거리 포화.\n');
fclose(fid);
fprintf('요약 저장: %s\n', sumFile);

%% 5) 감시국 CSV (시나리오 x 감시국, 전역 LSC, 시나리오별 H95_new 내림차순)
rows = [];
for s = 1:nS
    [~, si] = sort(EnM{s}.H95cm, 'descend');
    T = table(repmat(string(SCEN(s).name), nM, 1), namesMon(si), latMon(si), lonMon(si), ...
        round(EoM{s}.H95cm(si),2), round(EnM{s}.H95cm(si),2), round(EnM{s}.H95cm(si)-EoM{s}.H95cm(si),2), ...
        round(EoM{s}.V95cm(si),2), round(EnM{s}.V95cm(si),2), round(EnM{s}.V95cm(si)-EoM{s}.V95cm(si),2), ...
        'VariableNames', {'scenario','RINEX','lat','lon','H95_old_cm','H95_new_cm','dH95_cm', ...
                          'V95_old_cm','V95_new_cm','dV95_cm'});
    rows = [rows; T]; %#ok<AGROW>
end
csvFile = fullfile(thisDir, 'validation_lsc_monitors.csv');
writetable(rows, csvFile, 'Encoding', 'UTF-8');
fprintf('감시국별 예측 오차 저장: %s\n', csvFile);

%% 6) mat 저장
L2 = struct('created', datestr(now), 'HOR_LIM', HOR_LIM, 'VER_LIM', VER_LIM, 'OUT_LIM', OUT_LIM, ...
    'GRID_DEG', GRID_DEG, 'DESIGN', DESIGN, 'rules', {rules}, 'ruleLabel', {ruleLabel}, ...
    'glon', glon, 'glat', glat, 'common', common, ...
    'namesMon', {namesMon}, 'lonMon', lonMon, 'latMon', latMon);
L2.SCEN = SCEN;
L2.gridOldByScenRule = Eo;  L2.gridNewByScenRule = En;
L2.statsOldByScenRule = So; L2.statsNewByScenRule = Sn;
L2.monOldByScen = EoM;      L2.monNewByScen = EnM;
save(fullfile(thisDir, 'validation_lsc.mat'), 'L2');
fprintf('LSC 결과 저장: validation_lsc.mat\n');

%% 7) figure 1 — CDF (960x720): 시나리오 3종 x 2망, 전역 LSC
figDir = fullfile(thisDir, 'result_fig', '03_망검증_LSC');   % figure는 작업단위별 하위 폴더에 저장
if ~isfolder(figDir); mkdir(figDir); end
BLU = [0.10 0.25 0.75];  RED = [0.85 0.10 0.10];
ls3 = {':', '-', '--'};                       % 정온 / 활동 / 폭풍
fig1 = figure('Name','validation_lsc_cdf','Position',[100 100 960 720],'Color','w');
for pnl = 1:2
    subplot(1,2,pnl); hold on;
    hh = gobjects(2*nS,1); lbl = cell(2*nS,1);
    for s = 1:nS
        if pnl == 1
            vo = Eo{s,1}.H95cm(common & Eo{s,1}.valid);
            vn = En{s,1}.H95cm(common & En{s,1}.valid);
        else
            vo = Eo{s,1}.V95cm(common & Eo{s,1}.valid);
            vn = En{s,1}.V95cm(common & En{s,1}.valid);
        end
        hh(2*s-1) = stairs_cdf(vo, BLU, ls3{s});
        hh(2*s)   = stairs_cdf(vn, RED, ls3{s});
        lbl{2*s-1} = sprintf('기존 망 — %s', SCEN(s).name);
        lbl{2*s}   = sprintf('최적화 망 — %s', SCEN(s).name);
    end
    if pnl == 1
        xline(HOR_LIM, 'k--', sprintf('요구 성능 %g cm', HOR_LIM));
        xlabel('수평 측위오차 예측치 (95%) [cm]'); xlim([0 25]);
        title('(a) 수평 측위오차 (95%) 누적분포 — 전역 LSC');
    else
        xline(VER_LIM, 'k--', sprintf('요구 성능 %g cm', VER_LIM));
        xlabel('수직 측위오차 예측치 (95%) [cm]'); xlim([0 40]);
        title('(b) 수직 측위오차 (95%) 누적분포 — 전역 LSC');
    end
    ylabel('누적 확률'); grid on;
    legend(hh, lbl, 'Location', 'southeast');
end
exportgraphics(fig1, fullfile(figDir, 'validation_lsc_cdf.png'), 'Resolution', 200);

%% 8) figure 2 — 수평 95% 오차 지도 (설계 시나리오, heat map — colorbar 예외)
% 지도류 figure는 한 figure에 지도 1개 규격 — 망별 개별 파일, clim 공유로 비교 가능
Ed_o = Eo{DESIGN,1};  Ed_n = En{DESIGN,1};
Sd_o = So{DESIGN,1};  Sd_n = Sn{DESIGN,1};
okO = common & Ed_o.valid;  okN = common & Ed_n.valid;
cl = [0, prctile_local([Ed_o.H95cm(okO); Ed_n.H95cm(okN)], 99)];
mapFile = {'validation_lsc_map_old.png', 'validation_lsc_map_new.png'};
mapTtl = {sprintf('기존 망 (%d개소)', numel(latAll)), ...
          sprintf('최적화 망 (%d개소)', nnz(isRef))};
for k = 1:2
    fig2 = figure('Name','validation_lsc_map','Position',[100 100 960 720],'Color','w');
    gx = geoaxes(fig2);
    try
        geobasemap(gx, 'grayland');
    catch
    end
    hold(gx, 'on');
    if k == 1
        geoscatter(gx, glat(okO), glon(okO), 6, Ed_o.H95cm(okO), 'filled');
        geoplot(gx, latAll, lonAll, 'k^', 'MarkerSize', 4, 'MarkerFaceColor', 'k');
    else
        geoscatter(gx, glat(okN), glon(okN), 6, Ed_n.H95cm(okN), 'filled');
        geoplot(gx, latAll(isRef), lonAll(isRef), 'k^', 'MarkerSize', 4, 'MarkerFaceColor', 'k');
    end
    geolimits(gx, [33 39], [125 131]);
    clim(gx, cl); colorbar(gx);
    title(gx, {sprintf('수평 측위오차 예측치 (95%%) [cm] — 전역 LSC, %s 시나리오', ...
        SCEN(DESIGN).name), mapTtl{k}});
    exportgraphics(fig2, fullfile(figDir, mapFile{k}), 'Resolution', 200);
end

%% 9) figure 3 — 요구 성능 미달 지점 지도 (설계 시나리오, 전역 LSC)
plot_exceed_fig(fullfile(figDir, 'validation_lsc_exceed.png'), Ed_o, Ed_n, glat, glon, ...
    latAll, lonAll, isRef, common, HOR_LIM, VER_LIM, ...
    sprintf('전역 LSC — %s 시나리오 (%.1f ppm, L=%d km)', SCEN(DESIGN).name, SCEN(DESIGN).ppmEN, SCEN(DESIGN).Lkm));

%% 10) figure 4 — 시나리오 x 망 만족율 매트릭스 (전역 LSC)
fig4 = figure('Name','validation_lsc_scen','Position',[100 100 960 720],'Color','w');
scNames = {SCEN.name};
cats = categorical(scNames, scNames);
for pnl = 1:2
    subplot(1,2,pnl);
    if pnl == 1
        vals = [cellfun(@(x) x.ratioH, So(:,1)), cellfun(@(x) x.ratioH, Sn(:,1))];
        ttl = sprintf('(a) 수평 유계(%g cm) 만족율', HOR_LIM);
    else
        vals = [cellfun(@(x) x.ratioV, So(:,1)), cellfun(@(x) x.ratioV, Sn(:,1))];
        ttl = sprintf('(b) 수직 유계(%g cm) 만족율', VER_LIM);
    end
    b = bar(cats, vals, 0.8);
    b(1).FaceColor = BLU;  b(2).FaceColor = RED;
    ylim([0 105]); ylabel('만족율 [%]'); grid on; title(ttl);
    legend({sprintf('기존 망 (%d개소)', numel(latAll)), sprintf('최적화 망 (%d개소)', nnz(isRef))}, 'Location', 'northeast');
    for g = 1:2
        text(b(g).XEndPoints, b(g).YEndPoints, compose('%.1f', vals(:,g)'), ...
            'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom', 'FontSize', 8);
    end
end
sgtitle('전리층 활동도 시나리오별 유계 만족율 — 전역 LSC');
exportgraphics(fig4, fullfile(figDir, 'validation_lsc_scen.png'), 'Resolution', 200);

fprintf('figure 저장: validation_lsc_cdf/scen.png + map/exceed 각 _old/_new (지도 1개/figure)\n');
fprintf('검증 v2(LSC) 완료\n');

%% ---- 로컬 함수 ----
function h = stairs_cdf(v, col, ls)
% 통계 툴박스 없이 경험적 CDF (핸들 반환)
    v = sort(v(~isnan(v)));
    h = stairs(v, (1:numel(v))'/numel(v), 'Color', col, 'LineStyle', ls, 'LineWidth', 1.5);
end

function p = prctile_local(v, pct)
    v = sort(v(:));
    n = numel(v);
    if n == 0; p = NaN; return; end
    idx = (pct/100)*(n-1) + 1;
    lo = floor(idx); hi = ceil(idx);
    p = v(lo) + (idx-lo)*(v(hi)-v(lo));
end

function S = err_stats(E, dom, horLim, verLim, outLim)
% 만족율(분모 = 도메인 전체, 예측불가는 불만족), 평균(예측불가·outLim 이상 제외)
    ok = dom & E.valid;
    S.nDomain = nnz(dom);  S.nValid = nnz(ok);
    h = E.H95cm(ok);  v = E.V95cm(ok);
    S.ratioH = 100 * nnz(h <= horLim) / S.nDomain;
    S.ratioV = 100 * nnz(v <= verLim) / S.nDomain;
    S.avgH = mean(h(h < outLim));  S.avgV = mean(v(v < outLim));
    S.maxH = max(h);  S.maxV = max(v);
end

function plot_exceed_fig(figFile, Eold, Enew, glat, glon, latAll, lonAll, isRef, common, horLim, verLim, ruleLabel)
% 유계 초과 분류 지도: 만족=회색, 수직만 초과=주황, 수평 초과=빨강
% 지도류 figure는 한 figure에 지도 1개 규격 — figFile 기저명에 _old/_new를 붙여 망별 저장
    GREY = [0.78 0.78 0.78];  ORNG = [1.0 0.55 0.0];  RED = [0.85 0.1 0.1];
    [fDir, fBase, fExt] = fileparts(figFile);
    sfx = {'_old', '_new'};
    for k = 1:2
        if k == 1
            Ek = Eold;  refLatK = latAll;         refLonK = lonAll;
            netName = sprintf('기존 망 (%d개소)', numel(latAll));
        else
            Ek = Enew;  refLatK = latAll(isRef);  refLonK = lonAll(isRef);
            netName = sprintf('최적화 망 (%d개소)', nnz(isRef));
        end
        okK   = common & Ek.valid;
        sat   = okK & Ek.H95cm <= horLim & Ek.V95cm <= verLim;
        vOnly = okK & Ek.H95cm <= horLim & Ek.V95cm >  verLim;
        hExc  = okK & Ek.H95cm >  horLim;
        nExc  = nnz(vOnly) + nnz(hExc);

        fig = figure('Name', 'validation_lsc_exceed', 'Position', [100 100 960 720], 'Color', 'w');
        gx = geoaxes(fig);
        try
            geobasemap(gx, 'grayland');
        catch
        end
        hold(gx, 'on');
        geoplot(gx, [glat(sat);   NaN], [glon(sat);   NaN], '.', 'Color', GREY, 'MarkerSize', 2);
        geoplot(gx, [glat(vOnly); NaN], [glon(vOnly); NaN], '.', 'Color', ORNG, 'MarkerSize', 5);
        geoplot(gx, [glat(hExc);  NaN], [glon(hExc);  NaN], '.', 'Color', RED,  'MarkerSize', 6);
        geoplot(gx, refLatK, refLonK, 'k^', 'MarkerSize', 4, 'MarkerFaceColor', 'k');
        geolimits(gx, [33 39], [125 131]);
        fprintf('  [exceed] %s: 미달 %d점 (%.2f%%)\n', netName, nExc, 100*nExc/nnz(common));
        title(gx, {sprintf('요구 성능 미달 지점 분포 — %s', ruleLabel), netName});
        legend(gx, {'요구 성능 만족', sprintf('수직 한계 초과 (>%g cm)', verLim), ...
                    sprintf('수평 한계 초과 (>%g cm)', horLim), '기준국'}, 'Location', 'northeast');
        exportgraphics(fig, fullfile(fDir, [fBase sfx{k} fExt]), 'Resolution', 200);
    end
end
