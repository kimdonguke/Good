%% run_validation.m — 최적망 타당성 검증: 기하 비교(1단계) + 오차 모델 전/후 비교(2단계)
% 1단계(기하, 모델 독립):
%   감시국 관점(최근접 기준국 거리·소속 삼각형 기선장) + 서비스 영역 공통 격자 비교
%   + 델로네 간선 길이/maxBaseKm 초과 간선 현황
% 2단계(오차 모델): 이예빈·박병운(2023, J. Adv. Navig. Technol. 27(4)) IDOP·MSD 모델
%   (idop_msd_model.m)을 두 망에 동일 적용 → 수평/수직 95% 예측 오차,
%   유계(수평 5 cm / 수직 10 cm, 논문 목표 성능) 판정, 최적화 전/후 정량 비교.
%   계수는 논문 표 1·2 값 사용 (추후 국내 실측 기반 재추정 예정).
% 출력: 1단계 validation_geometry.{mat,png} + _summary.txt
%       2단계 validation_error.{mat,png} + _summary.txt + _map.png + _monitors.csv

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
[glon, glat] = meshgrid(125:0.05:131, 33:0.05:39);
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

w('[3] 서비스 영역 격자 비교 (공통 도메인 %d점, 0.05도 격자)\n', nnz(common));
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

%% 6) 분포 figure (960x720 표준)
fig = figure('Name', 'validation_geometry', 'Position', [100 100 960 720], 'Color', 'w');
subplot(1,2,1);
stairs_cdf(Gold.nearestKm(common), 'b-'); hold on;
stairs_cdf(Gnew.nearestKm(common), 'r-');
grid on; xlabel('최근접 기준국 거리 [km]'); ylabel('누적확률');
title('격자점 최근접 기준국 거리 CDF');
legend({'이전 망 (99국)', sprintf('최적망 (%d국)', nnz(isRef))}, 'Location', 'northeast'); % 표준: legend northeast
subplot(1,2,2);
stairs_cdf(Gold.triMeanKm(common), 'b-'); hold on;
stairs_cdf(Gnew.triMeanKm(common), 'r-');
grid on; xlabel('소속 삼각형 평균 기선장 [km]'); ylabel('누적확률');
title('격자점 소속셀 평균 기선장 CDF');
legend({'이전 망 (99국)', sprintf('최적망 (%d국)', nnz(isRef))}, 'Location', 'northeast');
print(fig, fullfile(thisDir, 'validation_geometry.png'), '-dpng', '-r200');
fprintf('figure 저장: validation_geometry.png\n');

fprintf('검증 1단계(기하) 완료\n');

%% ===== 2단계: 오차 모델 적용 (이예빈·박병운 2023, IDOP·MSD) =====
% 두 망에 동일 모델·동일 계수(논문 표 1·2)를 적용해 전/후 측위 성능을 정량 비교.
% 유계(목표 성능, 논문 III장): 수평 95% <= 5 cm, 수직 95% <= 10 cm.
% 평가 규칙(논문 3-1절): 만족율 분모 = 도메인 전체 격자점,
%   평균 정확도는 예측불가(150 km 내 <3국)·100 cm 이상 특이지점 제외.
HOR_LIM = 5; VER_LIM = 10; OUT_LIM = 100;   % [cm]

fprintf('[2단계] 오차 모델 적용 중 (격자 %d점 + 감시국 %d점) x 2망...\n', numel(glon), nM);
EoldG = idop_msd_model(lonAll, latAll, glon, glat);
EnewG = idop_msd_model(lonAll(isRef), latAll(isRef), glon, glat);
EoldM = idop_msd_model(lonAll, latAll, lonMon, latMon);
EnewM = idop_msd_model(lonAll(isRef), latAll(isRef), lonMon, latMon);

SoldG = err_stats(EoldG, common, HOR_LIM, VER_LIM, OUT_LIM);
SnewG = err_stats(EnewG, common, HOR_LIM, VER_LIM, OUT_LIM);

% ---- 요약 txt (UTF-8) ----
sumFile2 = fullfile(thisDir, 'validation_error_summary.txt');
fid = fopen(sumFile2, 'w', 'n', 'UTF-8');
w = @(varargin) fprintf(fid, varargin{:});
w('===== 망 타당성 검증 2단계: 오차 모델 전/후 비교 (%s) =====\n', datestr(now,'yyyy-mm-dd HH:MM'));
w('모델: sigma_axis = sqrt((a*IDOP)^2 + (b*MSD)^2) — 이예빈·박병운(2023), 원모델 Schwarz et al.(2009, OPUS-RS)\n');
w('계수: 논문 표 1·2 (미국 CORS 실측 기반 — 추후 국내 실측 재추정 예정), 사용 기준국 = 반경 150 km\n');
w('95%% 변환: 수평 2DRMS = 2*sqrt(sE^2+sN^2), 수직 = 1.96*sU (논문 미명시 -> 표준 관례)\n');
w('유계(목표 성능): 수평 95%% <= %g cm, 수직 95%% <= %g cm\n\n', HOR_LIM, VER_LIM);

w('[1] 서비스 영역 격자 (공통 도메인 %d점, 0.05도 — 논문 0.1도보다 조밀)\n', nnz(common));
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
save(fullfile(thisDir, 'validation_error.mat'), 'E');
fprintf('오차 모델 결과 저장: validation_error.mat\n');

% ---- figure: CDF (960x720 표준) ----
fig2 = figure('Name','validation_error','Position',[100 100 960 720],'Color','w');
subplot(1,2,1);
stairs_cdf(EoldG.H95cm(common & EoldG.valid), 'b-'); hold on;
stairs_cdf(EnewG.H95cm(common & EnewG.valid), 'r-');
xline(HOR_LIM, 'k--', sprintf('유계 %g cm', HOR_LIM));
grid on; xlabel('수평 95% 예측 오차 [cm]'); ylabel('누적확률'); xlim([0 20]);
title('격자점 수평 95% 오차 CDF');
legend({'이전 망 (99국)', sprintf('최적망 (%d국)', nnz(isRef))}, 'Location', 'southeast');
subplot(1,2,2);
stairs_cdf(EoldG.V95cm(common & EoldG.valid), 'b-'); hold on;
stairs_cdf(EnewG.V95cm(common & EnewG.valid), 'r-');
xline(VER_LIM, 'k--', sprintf('유계 %g cm', VER_LIM));
grid on; xlabel('수직 95% 예측 오차 [cm]'); ylabel('누적확률'); xlim([0 40]);
title('격자점 수직 95% 오차 CDF');
legend({'이전 망 (99국)', sprintf('최적망 (%d국)', nnz(isRef))}, 'Location', 'southeast');
print(fig2, fullfile(thisDir, 'validation_error.png'), '-dpng', '-r200');

% ---- figure: 수평 95% 오차 지도 (성능 heat map — colorbar 필요 예외) ----
fig3 = figure('Name','validation_error_map','Position',[100 100 960 720],'Color','w');
tl = tiledlayout(fig3, 1, 2, 'TileSpacing', 'compact');
okO = common & EoldG.valid;  okN = common & EnewG.valid;
cl = [0, prctile_local([EoldG.H95cm(okO); EnewG.H95cm(okN)], 99)];
mapTtl = {sprintf('이전 망 (99국) — 평균 %.2f cm', SoldG.avgH), ...
          sprintf('최적망 (%d국) — 평균 %.2f cm', nnz(isRef), SnewG.avgH)};
for k = 1:2
    gx = geoaxes(tl); gx.Layout.Tile = k;
    try
        geobasemap(gx, 'grayland');
    catch
    end
    hold(gx, 'on');
    if k == 1
        geoscatter(gx, glat(okO), glon(okO), 8, EoldG.H95cm(okO), 'filled');
        geoplot(gx, latAll, lonAll, 'k^', 'MarkerSize', 3, 'MarkerFaceColor', 'k');
    else
        geoscatter(gx, glat(okN), glon(okN), 8, EnewG.H95cm(okN), 'filled');
        geoplot(gx, latAll(isRef), lonAll(isRef), 'k^', 'MarkerSize', 3, 'MarkerFaceColor', 'k');
    end
    geolimits(gx, [33 39], [125 131]);
    clim(gx, cl); colorbar(gx);
    title(gx, mapTtl{k});
end
title(tl, '수평 95% 예측 오차 [cm] (검정 삼각형 = 기준국)');
print(fig3, fullfile(thisDir, 'validation_error_map.png'), '-dpng', '-r200');
fprintf('figure 저장: validation_error.png / validation_error_map.png\n');

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
