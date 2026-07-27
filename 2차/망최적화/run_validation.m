%% run_validation.m — 최적망 타당성 검증: 기하 비교(1단계) + 오차 모델 전/후 비교(2단계)
% 1단계(기하, 모델 독립):
%   감시국 관점(최근접 기준국 거리·소속 삼각형 기선장) + 서비스 영역 공통 격자 비교
%   + 델로네 간선 길이/maxBaseKm 초과 간선 현황
% 2단계(오차 모델): 이예빈·박병운(2023, J. Adv. Navig. Technol. 27(4)) IDOP·MSD 모델
%   (idop_msd_model.m)을 두 망에 동일 적용 → 수평/수직 95% 예측 오차,
%   요구 성능(수평 5 cm / 수직 10 cm, 논문 목표 성능) 판정, 최적화 전/후 정량 비교.
% 출력: 1단계 validation_geometry.{mat,png} + _summary.txt
%       2단계 validation_error.{mat,png} + _summary.txt + _map.png
%             + _exceed{,_tri,_ring}.png + _monitors.csv
%
% ─── 핵심 해석 노트 ──────────────────────────────────────────────────────
% [모델 계보] σ_axis = sqrt((α·IDOP)² + (β·MSD)²)
%   이예빈·박병운(2023) ← 원 모델: Schwarz, Snay & Soler(2009) OPUS-RS 정확도
%   모델(GPS Solutions 13(2)). 반송파 네트워크 보간 기반이라 NRTK 와 오차 기전 유사.
% [계수 한계] α·β(논문 표 1·2)는 미국 CORS 실측(다국 사용, 최대 9국) 적합값.
%   → 절대값(cm)은 "이 모델 기준 예측"이며 국내 FKP/VRS 실측과 다를 수 있음.
%   → 국내 재추정(논문 식 22, 최소제곱) 시 아래 선택 규칙별로 각각 적합할 것.
% [95% 변환] 논문에 명시 없음 → 표준 관례 채택: 수평 2DRMS = 2·sqrt(σE²+σN²),
%   수직 1.96·σU. 보고서/논문 작성 시 변환식을 반드시 명시할 것.
% [IDOP 해석] IDOP² = 1/n + (사용국 집합 centroid 기준 마할라노비스 거리)²/n.
%   "최근접 기준국까지의 거리"가 아니라 "사용국 집합 내 중심성"을 재는 지표이며,
%   기준국 근접 이득(zero-baseline)은 모델에 존재하지 않음.
% [기준국 선택 규칙 3종]
%   radius150 : 반경 150 km(논문 규칙). 계수 적합 조건과 정합 → 절대 판정용 주 지표.
%   tri(n=3)  : 들로네 셀 설계와 정합하나 ① IDOP 축척 불변 → 망 밀도 변별력 없음
%               (99국/40국 만족율이 사실상 동일), ② 포화 적합(잉여도 0)이라 꼭짓점
%               IDOP=1 → V95≈13.2 cm 로 기준국 주위 도넛형 초과 발생 — 실제 물리
%               (기준국 근처가 최상)와 반대인 아티팩트. 판정 지표로 비권장.
%               (셀 중심 IDOP=1/sqrt(3)=0.577 → V95≈7.6 cm 가 하한)
%   tri1ring  : 소속 삼각형 + 델로네 인접국(n≈10). VRS 마스터+보조국 셀 구성과
%               유사(망 위상 정합) + 계수 적합 범위와도 정합 → 설계 정합 지표로 권장.
% [초과 구역 해석] 요구 성능 초과는 서남해안 앞바다 스트립(볼록껍질 내부이지만
%   기준국 집합의 편측 바깥 = 외삽 구역, IDOP≳0.75)에 국한. 기존 망에도 존재하던
%   구조적 취약지로 최적화가 새로 만든 것이 아니며, 내륙·감시국 전 지점은 요구 성능
%   이내. 해상까지 보장이 필요하면 ILP 에 서남 도서권 기준국 유지 제약 추가 검토.
% [평가 규칙(논문 3-1절)] 만족율 분모 = 도메인 전체 격자점(예측불가는 불만족으로
%   집계), 평균 정확도는 예측불가·100 cm 이상 특이지점 제외. 도메인 = 두 망 공통
%   볼록껍질 내부 격자(해상 포함) — 육지 한정 통계가 필요하면 별도 마스크 적용.
% ─────────────────────────────────────────────────────────────────────────

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

%% 1) 결과/원망 로드
S = load(fullfile(thisDir, 'result_ilp.mat'));  R = S.R;
lonAll = R.lon(:); latAll = R.lat(:); isRef = logical(R.isRef(:));
lonMon = lonAll(~isRef); latMon = latAll(~isRef);
namesMon = string(R.names(~isRef));
fprintf('최적망 로드: 기준국 %d, 감시국 %d, maxBaseKm=%g\n', nnz(isRef), nnz(~isRef), R.maxBaseKm);

%% 2) 감시국 관점 기하 (최적망)
Gmon = net_geometry(lonAll(isRef), latAll(isRef), lonMon, latMon);

% 이전 망 참고치: 감시국 위치의 주변 국간 간격 (자기 자신 제외 최근접)
nM = numel(lonMon);
dSelf = zeros(nM, numel(lonAll));
for j = 1:numel(lonAll)
    dSelf(:,j) = deg2km(distance(latMon, lonMon, latAll(j), lonAll(j)));
end
dSelf(dSelf < 1e-6) = Inf;              % 자기 자신 제거
oldSpacingKm = min(dSelf, [], 2);

%% 3) 서비스 영역 격자 비교 (이전 99국 망 vs 최적망)
GRID_DEG = 0.025;   % 격자 간격 [deg] (약 2.8 km — 논문 0.1도의 4배 조밀)
[glon, glat] = meshgrid(125:GRID_DEG:131, 33:GRID_DEG:39);
glon = glon(:); glat = glat(:);
Gold = net_geometry(lonAll, latAll, glon, glat);            % 이전 망: 99국 전부 기준국
Gnew = net_geometry(lonAll(isRef), latAll(isRef), glon, glat);
common = Gold.inTri & Gnew.inTri;                            % 공통 도메인
fprintf('격자 %d점 중 공통 도메인 %d점 (이전 망 내부 %d, 최적망 내부 %d)\n', ...
    numel(glon), nnz(common), nnz(Gold.inTri), nnz(Gnew.inTri));

%% 4) 통계 요약 (txt = UTF-8, 콘솔 mojibake 회피)
q = @(v, p) prctile_local(v(~isnan(v)), p);
sumFile = fullfile(thisDir, 'validation_geometry_summary.txt');
fid = fopen(sumFile, 'w', 'n', 'UTF-8');
w = @(varargin) fprintf(fid, varargin{:});

w('===== 망 타당성 검증 1단계: 기하 비교 (%s) =====\n', datestr(now, 'yyyy-mm-dd HH:MM'));
w('최적망: 기준국 %d / 감시국 %d (maxBaseKm=%g, 외곽고정 %s)\n\n', ...
    nnz(isRef), nM, R.maxBaseKm, mat2str(numel(R.boundarySpec)));

w('[1] 델로네 간선 길이 [km]\n');
w('              간선수   평균    중앙    최대   >%gkm\n', R.maxBaseKm);
w('  이전(99국)  %5d  %6.1f  %6.1f  %6.1f  %5d\n', numel(Gold.edgeKm), ...
    mean(Gold.edgeKm), median(Gold.edgeKm), max(Gold.edgeKm), nnz(Gold.edgeKm > R.maxBaseKm));
w('  최적(%2d국)  %5d  %6.1f  %6.1f  %6.1f  %5d\n', nnz(isRef), numel(Gnew.edgeKm), ...
    mean(Gnew.edgeKm), median(Gnew.edgeKm), max(Gnew.edgeKm), nnz(Gnew.edgeKm > R.maxBaseKm));
exceedNew = sort(Gnew.edgeKm(Gnew.edgeKm > R.maxBaseKm), 'descend');
if ~isempty(exceedNew)
    w('  최적망 %gkm 초과 간선: %s km\n', R.maxBaseKm, mat2str(round(exceedNew(:)',1)));
end
w('\n');

w('[2] 감시국 %d점 관점 (최적망)\n', nM);
w('  최근접 기준국 거리 [km] : 평균 %.1f / 중앙 %.1f / 95%% %.1f / 최대 %.1f\n', ...
    mean(Gmon.nearestKm), median(Gmon.nearestKm), q(Gmon.nearestKm,95), max(Gmon.nearestKm));
w('  소속 삼각형 평균기선 [km]: 평균 %.1f / 중앙 %.1f / 95%% %.1f / 최대 %.1f\n', ...
    mean(Gmon.triMeanKm,'omitnan'), median(Gmon.triMeanKm,'omitnan'), ...
    q(Gmon.triMeanKm,95), max(Gmon.triMeanKm,[],'omitnan'));
w('  소속 삼각형 최장기선 [km]: 평균 %.1f / 최대 %.1f\n', ...
    mean(Gmon.triMaxKm,'omitnan'), max(Gmon.triMaxKm,[],'omitnan'));
w('  망 외부(삼각형 미소속) 감시국: %d점', nnz(~Gmon.inTri));
if any(~Gmon.inTri); w(' (%s)', strjoin(namesMon(~Gmon.inTri), ', ')); end
w('\n  (참고) 이전 망 주변 국간 간격 [km]: 평균 %.1f / 최대 %.1f — 이전 망에서 이 지점들은 기준국 자체(기선 0)\n\n', ...
    mean(oldSpacingKm), max(oldSpacingKm));

w('[3] 서비스 영역 격자 비교 (공통 도메인 %d점, %g도 격자)\n', nnz(common), GRID_DEG);
w('  지표: 최근접 기준국 거리 [km]        이전    최적    배율\n');
w('    평균                            %6.1f  %6.1f  %5.2fx\n', ...
    mean(Gold.nearestKm(common)), mean(Gnew.nearestKm(common)), ...
    mean(Gnew.nearestKm(common))/mean(Gold.nearestKm(common)));
w('    중앙                            %6.1f  %6.1f  %5.2fx\n', ...
    median(Gold.nearestKm(common)), median(Gnew.nearestKm(common)), ...
    median(Gnew.nearestKm(common))/median(Gold.nearestKm(common)));
w('    95%%                             %6.1f  %6.1f  %5.2fx\n', ...
    q(Gold.nearestKm(common),95), q(Gnew.nearestKm(common),95), ...
    q(Gnew.nearestKm(common),95)/q(Gold.nearestKm(common),95));
w('    최대                            %6.1f  %6.1f  %5.2fx\n', ...
    max(Gold.nearestKm(common)), max(Gnew.nearestKm(common)), ...
    max(Gnew.nearestKm(common))/max(Gold.nearestKm(common)));
w('  지표: 소속 삼각형 평균기선 [km]      이전    최적    배율\n');
w('    평균                            %6.1f  %6.1f  %5.2fx\n', ...
    mean(Gold.triMeanKm(common)), mean(Gnew.triMeanKm(common)), ...
    mean(Gnew.triMeanKm(common))/mean(Gold.triMeanKm(common)));
w('    95%%                             %6.1f  %6.1f  %5.2fx\n', ...
    q(Gold.triMeanKm(common),95), q(Gnew.triMeanKm(common),95), ...
    q(Gnew.triMeanKm(common),95)/q(Gold.triMeanKm(common),95));
w('    최대                            %6.1f  %6.1f  %5.2fx\n', ...
    max(Gold.triMeanKm(common)), max(Gnew.triMeanKm(common)), ...
    max(Gnew.triMeanKm(common))/max(Gold.triMeanKm(common)));
w('\n다음 단계: ref 문헌의 거리-오차 모델 + 규정 유계값 적용 → 오차 열화/유계 판정\n');
fclose(fid);
fprintf('요약 저장: %s\n', sumFile);

%% 5) 결과 저장 (.mat — 오차 모델 단계에서 재사용)
V = struct('created', datestr(now), 'maxBaseKm', R.maxBaseKm, ...
    'lonMon', lonMon, 'latMon', latMon, 'namesMon', {namesMon}, ...
    'Gmon', Gmon, 'oldSpacingKm', oldSpacingKm, ...
    'glon', glon, 'glat', glat, 'common', common, ...
    'gridOld', struct('nearestKm', Gold.nearestKm, 'triMeanKm', Gold.triMeanKm, ...
                      'triMaxKm', Gold.triMaxKm, 'inTri', Gold.inTri), ...
    'gridNew', struct('nearestKm', Gnew.nearestKm, 'triMeanKm', Gnew.triMeanKm, ...
                      'triMaxKm', Gnew.triMaxKm, 'inTri', Gnew.inTri));
save(fullfile(thisDir, 'validation_geometry.mat'), 'V');
fprintf('기하 결과 저장: validation_geometry.mat\n');

%% 6) 분포 figure (960x720 표준) — figure는 result_fig/02_망검증_IDOP-MSD 에 저장
figDir = fullfile(thisDir, 'result_fig', '02_망검증_IDOP-MSD');
if ~isfolder(figDir); mkdir(figDir); end
fig = figure('Name', 'validation_geometry', 'Position', [100 100 960 720], 'Color', 'w');
subplot(1,2,1);
stairs_cdf(Gold.nearestKm(common), 'b-'); hold on;
stairs_cdf(Gnew.nearestKm(common), 'r-');
grid on; xlabel('최근접 기준국 거리 [km]'); ylabel('누적 확률');
title('(a) 최근접 기준국 거리 누적분포');
legend({'기존 망 (99개소)', sprintf('최적화 망 (%d개소)', nnz(isRef))}, 'Location', 'northeast'); % 표준: legend northeast
subplot(1,2,2);
stairs_cdf(Gold.triMeanKm(common), 'b-'); hold on;
stairs_cdf(Gnew.triMeanKm(common), 'r-');
grid on; xlabel('소속 삼각형 평균 기선장 [km]'); ylabel('누적 확률');
title('(b) 소속 삼각형 평균 기선장 누적분포');
legend({'기존 망 (99개소)', sprintf('최적화 망 (%d개소)', nnz(isRef))}, 'Location', 'northeast');
print(fig, fullfile(figDir, 'validation_geometry.png'), '-dpng', '-r200');
fprintf('figure 저장: validation_geometry.png\n');

fprintf('검증 1단계(기하) 완료\n');

%% ===== 2단계: 오차 모델 적용 (이예빈·박병운 2023, IDOP·MSD) =====
% 두 망에 동일 모델·동일 계수(논문 표 1·2)를 적용해 전/후 측위 성능을 정량 비교.
% 요구 성능(논문 III장 목표 성능): 수평 95% <= 5 cm, 수직 95% <= 10 cm.
% 평가 규칙(논문 3-1절): 만족율 분모 = 도메인 전체 격자점,
%   평균 정확도는 예측불가(사용국 <3 또는 망 외부)·100 cm 이상 특이지점 제외.
HOR_LIM = 5; VER_LIM = 10; OUT_LIM = 100;   % [cm]

% 기준국 선택 규칙 3종: 논문 규칙(주 지표) + VRS 설계 정합 규칙 2종
modes     = {'radius150', 'tri', 'tri1ring'};
modeLabel = {'반경 150 km (논문 규칙)', '들로네 삼각형 n=3 (설계 정합)', '삼각형+델로네 인접국 (VRS 셀 유사)'};
fprintf('[2단계] 오차 모델 적용 중 (격자 %d점 x 2망 x %d규칙 + 감시국 %d점)...\n', ...
    numel(glon), numel(modes), nM);
Eo = cell(1,numel(modes)); En = Eo; So = Eo; Sn = Eo;
for m = 1:numel(modes)
    Eo{m} = idop_msd_model(lonAll, latAll, glon, glat, modes{m});
    En{m} = idop_msd_model(lonAll(isRef), latAll(isRef), glon, glat, modes{m});
    So{m} = err_stats(Eo{m}, common, HOR_LIM, VER_LIM, OUT_LIM);
    Sn{m} = err_stats(En{m}, common, HOR_LIM, VER_LIM, OUT_LIM);
end
EoldG = Eo{1};  EnewG = En{1};   % 주 지표(논문 규칙) — 이하 CDF·heat map 에서 사용
SoldG = So{1};  SnewG = Sn{1};
EoldM = idop_msd_model(lonAll, latAll, lonMon, latMon);
EnewM = idop_msd_model(lonAll(isRef), latAll(isRef), lonMon, latMon);

% ---- 요약 txt (UTF-8) ----
sumFile2 = fullfile(thisDir, 'validation_error_summary.txt');
fid = fopen(sumFile2, 'w', 'n', 'UTF-8');
w = @(varargin) fprintf(fid, varargin{:});
w('===== 망 타당성 검증 2단계: 오차 모델 전/후 비교 (%s) =====\n', datestr(now,'yyyy-mm-dd HH:MM'));
w('모델: sigma_axis = sqrt((a*IDOP)^2 + (b*MSD)^2) — 이예빈·박병운(2023), 원모델 Schwarz et al.(2009, OPUS-RS)\n');
w('계수: 논문 표 1·2 (미국 CORS 실측 기반 — 추후 국내 실측 재추정 예정), 사용 기준국 = 반경 150 km\n');
w('95%% 변환: 수평 2DRMS = 2*sqrt(sE^2+sN^2), 수직 = 1.96*sU (논문 미명시 -> 표준 관례)\n');
w('유계(목표 성능): 수평 95%% <= %g cm, 수직 95%% <= %g cm\n\n', HOR_LIM, VER_LIM);

w('[1] 서비스 영역 격자 (공통 도메인 %d점, %g도 — 논문 0.1도보다 조밀)\n', nnz(common), GRID_DEG);
w('                            이전(99국)    최적(%d국)      변화\n', nnz(isRef));
w('  만족율 수평 [%%]          %8.2f     %8.2f     %+7.2f %%p\n', SoldG.ratioH, SnewG.ratioH, SnewG.ratioH-SoldG.ratioH);
w('  만족율 수직 [%%]          %8.2f     %8.2f     %+7.2f %%p\n', SoldG.ratioV, SnewG.ratioV, SnewG.ratioV-SoldG.ratioV);
w('  평균 수평 95%% [cm]       %8.2f     %8.2f     %+7.2f (%.2fx)\n', SoldG.avgH, SnewG.avgH, SnewG.avgH-SoldG.avgH, SnewG.avgH/SoldG.avgH);
w('  평균 수직 95%% [cm]       %8.2f     %8.2f     %+7.2f (%.2fx)\n', SoldG.avgV, SnewG.avgV, SnewG.avgV-SoldG.avgV, SnewG.avgV/SoldG.avgV);
w('  최대 수평 95%% [cm]       %8.2f     %8.2f\n', SoldG.maxH, SnewG.maxH);
w('  최대 수직 95%% [cm]       %8.2f     %8.2f\n', SoldG.maxV, SnewG.maxV);
w('  예측 불가 지점            %8d     %8d\n', SoldG.nDomain-SoldG.nValid, SnewG.nDomain-SnewG.nValid);
w('  이전망 가능 -> 최적망 불가 지점: %d\n\n', nnz(common & EoldG.valid & ~EnewG.valid));

w('[2] 감시국 %d점 (전환 지점 자체의 측위 성능)\n', nM);
w('                            이전(99국)    최적(%d국)      변화\n', nnz(isRef));
w('  평균 수평 95%% [cm]       %8.2f     %8.2f     %+7.2f\n', ...
    mean(EoldM.H95cm,'omitnan'), mean(EnewM.H95cm,'omitnan'), mean(EnewM.H95cm,'omitnan')-mean(EoldM.H95cm,'omitnan'));
w('  평균 수직 95%% [cm]       %8.2f     %8.2f     %+7.2f\n', ...
    mean(EoldM.V95cm,'omitnan'), mean(EnewM.V95cm,'omitnan'), mean(EnewM.V95cm,'omitnan')-mean(EoldM.V95cm,'omitnan'));
w('  최대 수평 95%% [cm]       %8.2f     %8.2f\n', max(EoldM.H95cm,[],'omitnan'), max(EnewM.H95cm,[],'omitnan'));
w('  최대 수직 95%% [cm]       %8.2f     %8.2f\n', max(EoldM.V95cm,[],'omitnan'), max(EnewM.V95cm,[],'omitnan'));
badH = EnewM.H95cm > HOR_LIM;  badV = EnewM.V95cm > VER_LIM;
w('  유계 초과 감시국 (최적망): 수평 %d점, 수직 %d점', nnz(badH), nnz(badV));
if any(badH | badV); w(' — %s', strjoin(namesMon(badH | badV), ', ')); end
w('\n');

w('\n[3] 기준국 선택 규칙별 격자 지표 (동일 계수, 공통 도메인 %d점)\n', nnz(common));
w('  규칙                                 망     만족율H%%  만족율V%%  평균H cm  평균V cm  IDOP중앙\n');
for m = 1:numel(modes)
    io = common & Eo{m}.valid;  ik = common & En{m}.valid;
    w('  %-34s 이전  %8.2f  %8.2f  %8.2f  %8.2f  %8.3f\n', modeLabel{m}, ...
        So{m}.ratioH, So{m}.ratioV, So{m}.avgH, So{m}.avgV, median(Eo{m}.IDOP(io)));
    w('  %-34s 최적  %8.2f  %8.2f  %8.2f  %8.2f  %8.3f\n', '', ...
        Sn{m}.ratioH, Sn{m}.ratioV, Sn{m}.avgH, Sn{m}.avgV, median(En{m}.IDOP(ik)));
end
w('  주의: 계수 α·β 는 다국 기반(OPUS-RS, 최대 9국) 적합값 — n=3 규칙(tri)은 IDOP 하한\n');
w('        1/sqrt(3)=0.577, 꼭짓점 1.0 구조라 절대값이 보수적으로 편향되고 축척 불변성 때문에\n');
w('        망 밀도 변별력도 낮음. 국내 실측 재추정 시 규칙별로 α·β 를 각각 적합할 것.\n');
fclose(fid);
fprintf('요약 저장: %s\n', sumFile2);

% ---- 감시국별 CSV (최적망 수평 오차 내림차순) ----
[~, si] = sort(EnewM.H95cm, 'descend');
Tm = table(namesMon(si), latMon(si), lonMon(si), ...
    round(EoldM.H95cm(si),2), round(EnewM.H95cm(si),2), round(EnewM.H95cm(si)-EoldM.H95cm(si),2), ...
    round(EoldM.V95cm(si),2), round(EnewM.V95cm(si),2), round(EnewM.V95cm(si)-EoldM.V95cm(si),2), ...
    EnewM.nUsed(si), ...
    'VariableNames', {'RINEX','lat','lon','H95_old_cm','H95_new_cm','dH95_cm', ...
                      'V95_old_cm','V95_new_cm','dV95_cm','nRef150km_new'});
csvFile = fullfile(thisDir, 'validation_error_monitors.csv');
writetable(Tm, csvFile, 'Encoding', 'UTF-8');
fprintf('감시국별 예측 오차 저장: %s\n', csvFile);

% ---- mat 저장 ----
E = struct('created', datestr(now), 'HOR_LIM', HOR_LIM, 'VER_LIM', VER_LIM, 'OUT_LIM', OUT_LIM, ...
    'gridOld', EoldG, 'gridNew', EnewG, 'monOld', EoldM, 'monNew', EnewM, ...
    'statsOld', SoldG, 'statsNew', SnewG);
E.modes = modes;  E.modeLabel = modeLabel;
E.gridOldByMode = Eo;  E.gridNewByMode = En;
E.statsOldByMode = So; E.statsNewByMode = Sn;
save(fullfile(thisDir, 'validation_error.mat'), 'E');
fprintf('오차 모델 결과 저장: validation_error.mat\n');

% ---- figure: CDF (960x720 표준) ----
fig2 = figure('Name','validation_error','Position',[100 100 960 720],'Color','w');
subplot(1,2,1);
stairs_cdf(EoldG.H95cm(common & EoldG.valid), 'b-'); hold on;
stairs_cdf(EnewG.H95cm(common & EnewG.valid), 'r-');
xline(HOR_LIM, 'k--', sprintf('요구 성능 %g cm', HOR_LIM));
grid on; xlabel('수평 측위오차 예측치 (95%) [cm]'); ylabel('누적 확률'); xlim([0 20]);
title('(a) 수평 측위오차 (95%) 누적분포');
legend({'기존 망 (99개소)', sprintf('최적화 망 (%d개소)', nnz(isRef))}, 'Location', 'southeast');
subplot(1,2,2);
stairs_cdf(EoldG.V95cm(common & EoldG.valid), 'b-'); hold on;
stairs_cdf(EnewG.V95cm(common & EnewG.valid), 'r-');
xline(VER_LIM, 'k--', sprintf('요구 성능 %g cm', VER_LIM));
grid on; xlabel('수직 측위오차 예측치 (95%) [cm]'); ylabel('누적 확률'); xlim([0 40]);
title('(b) 수직 측위오차 (95%) 누적분포');
legend({'기존 망 (99개소)', sprintf('최적화 망 (%d개소)', nnz(isRef))}, 'Location', 'southeast');
print(fig2, fullfile(figDir, 'validation_error.png'), '-dpng', '-r200');

% ---- figure: 수평 95% 오차 지도 (성능 heat map — colorbar 필요 예외) ----
% 지도류 figure는 한 figure에 지도 1개 규격 — 망별 개별 파일, clim 공유로 비교 가능
okO = common & EoldG.valid;  okN = common & EnewG.valid;
cl = [0, prctile_local([EoldG.H95cm(okO); EnewG.H95cm(okN)], 99)];
mapFile = {'validation_error_map_old.png', 'validation_error_map_new.png'};
mapTtl = {sprintf('기존 망 (%d개소)', numel(latAll)), ...
          sprintf('최적화 망 (%d개소)', nnz(isRef))};
for k = 1:2
    fig3 = figure('Name','validation_error_map','Position',[100 100 960 720],'Color','w');
    gx = geoaxes(fig3);
    try
        geobasemap(gx, 'grayland');
    catch
    end
    hold(gx, 'on');
    if k == 1
        geoscatter(gx, glat(okO), glon(okO), 6, EoldG.H95cm(okO), 'filled');
        geoplot(gx, latAll, lonAll, 'k^', 'MarkerSize', 4, 'MarkerFaceColor', 'k');
    else
        geoscatter(gx, glat(okN), glon(okN), 6, EnewG.H95cm(okN), 'filled');
        geoplot(gx, latAll(isRef), lonAll(isRef), 'k^', 'MarkerSize', 4, 'MarkerFaceColor', 'k');
    end
    geolimits(gx, [33 39], [125 131]);
    clim(gx, cl); colorbar(gx);
    title(gx, {'수평 측위오차 예측치 (95%) [cm] — 기준국 선택: 반경 150 km (▲: 기준국)', mapTtl{k}});
    print(fig3, fullfile(figDir, mapFile{k}), '-dpng', '-r200');
end

% ---- figure: 요구 성능 미달 지점 지도, 규칙별 (만족=회색, 수직만 초과=주황, 수평 초과=빨강) ----
% 수직 한계(10 cm)가 수평(5 cm)보다 먼저 걸리는 구조(α_U/α_E ≈ 3.6)라
% "수평 한계 초과" 지점은 사실상 수평·수직 동시 초과를 의미한다.
excFile = {'validation_error_exceed.png', 'validation_error_exceed_tri.png', 'validation_error_exceed_ring.png'};
for m = 1:numel(modes)
    plot_exceed_fig(fullfile(figDir, excFile{m}), Eo{m}, En{m}, glat, glon, ...
        latAll, lonAll, isRef, common, HOR_LIM, VER_LIM, modeLabel{m});
end
fprintf('figure 저장: validation_error.png / validation_error_map_{old,new}.png / %s (각 _old/_new)\n', strjoin(excFile, ' / '));

fprintf('검증 2단계(오차 모델) 완료\n');

%% ---- 로컬 함수 ----
function stairs_cdf(v, style)
% 통계 툴박스 없이 경험적 CDF
    v = sort(v(~isnan(v)));
    stairs(v, (1:numel(v))'/numel(v), style, 'LineWidth', 1.5);
end

function p = prctile_local(v, pct)
% 통계 툴박스 없이 백분위수 (선형보간)
    v = sort(v(:));
    n = numel(v);
    if n == 0; p = NaN; return; end
    idx = (pct/100)*(n-1) + 1;
    lo = floor(idx); hi = ceil(idx);
    p = v(lo) + (idx-lo)*(v(hi)-v(lo));
end

function S = err_stats(E, dom, horLim, verLim, outLim)
% 논문 평가지표: 만족율(분모 = 도메인 전체 격자점, 예측불가는 불만족으로 집계),
%                평균 정확도(예측불가·outLim 이상 특이지점 제외)
    ok = dom & E.valid;
    S.nDomain = nnz(dom);  S.nValid = nnz(ok);
    h = E.H95cm(ok);  v = E.V95cm(ok);
    S.ratioH = 100 * nnz(h <= horLim) / S.nDomain;
    S.ratioV = 100 * nnz(v <= verLim) / S.nDomain;
    S.avgH = mean(h(h < outLim));  S.avgV = mean(v(v < outLim));
    S.maxH = max(h);  S.maxV = max(v);
end

function plot_exceed_fig(figFile, Eold, Enew, glat, glon, latAll, lonAll, isRef, common, horLim, verLim, ruleLabel)
% 유계 초과 분류 지도 (규칙 공용): 만족=회색, 수직만 초과=주황, 수평 초과=빨강
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

        fig = figure('Name', 'validation_error_exceed', 'Position', [100 100 960 720], 'Color', 'w');
        gx = geoaxes(fig);
        try
            geobasemap(gx, 'grayland');
        catch
        end
        hold(gx, 'on');
        % 빈 분류가 있어도 legend 순서가 유지되도록 NaN 점 하나를 덧붙여 그린다
        geoplot(gx, [glat(sat);   NaN], [glon(sat);   NaN], '.', 'Color', GREY, 'MarkerSize', 2);
        geoplot(gx, [glat(vOnly); NaN], [glon(vOnly); NaN], '.', 'Color', ORNG, 'MarkerSize', 5);
        geoplot(gx, [glat(hExc);  NaN], [glon(hExc);  NaN], '.', 'Color', RED,  'MarkerSize', 6);
        geoplot(gx, refLatK, refLonK, 'k^', 'MarkerSize', 4, 'MarkerFaceColor', 'k');
        geolimits(gx, [33 39], [125 131]);
        fprintf('  [exceed/%s] %s: 미달 %d점 (%.2f%%)\n', ruleLabel, netName, nExc, 100*nExc/nnz(common));
        title(gx, {sprintf('요구 성능 미달 지점 분포 — 기준국 선택: %s', ruleLabel), netName});
        legend(gx, {'요구 성능 만족', sprintf('수직 한계 초과 (>%g cm)', verLim), ...
                    sprintf('수평 한계 초과 (>%g cm)', horLim), '기준국'}, 'Location', 'northeast');
        print(fig, fullfile(fDir, [fBase sfx{k} fExt]), '-dpng', '-r200');
    end
end
