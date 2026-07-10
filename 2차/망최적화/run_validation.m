%% run_validation.m — 최적망 타당성 검증 1단계: 기하 비교 (이전 99국 망 vs 최적망)
% 오차 모델(추후 ref 문헌 기반 확정)과 무관하게 필요한 기하 예측변수를 산출·비교한다.
%   1) 감시국 관점 : 각 감시국의 최근접 기준국 거리, 소속 삼각형 기선장
%                    (이전 망에서는 자기 자신이 기준국이라 기선 0 → 주변 국간 간격을 참고치로)
%   2) 서비스 영역 : 공통 격자(두 망 모두 내부인 점)에서 이전 망 vs 최적망 예측변수 분포
%   3) 망 자체     : 델로네 간선 길이 분포, maxBaseKm 초과 간선(그랜드파더/헐) 현황
% 출력: validation_geometry.mat / validation_geometry_summary.txt / validation_geometry.png
% 이후 단계: 사용자 제공 ref 의 거리-오차 모델 + 규정 유계값을 얹어 오차 열화·유계 판정.

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
