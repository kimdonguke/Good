%% run_plot_qc_status.m — QC 기준국 선별 상태 지도 (RsrchMt 규칙)
%  현행 결과(result_ilp.mat)에 QC 선별 분류를 오버레이:
%   - Availability cut-off 전환국 / SLPS cut-off 전환국 (품질 미달 → 감시국 강제)
%   - 외곽 고정 예외국 (QC 미달이지만 구조상 기준국 유지 — 운영 개선 필요 신호)
%   - 평균 품질(S̄) 미만 기준국 (개별 Score < S̄ = A7 제약의 부담국 — A7은 평균
%     제약이므로 "위반"이 아니라, 고품질 국이 상쇄해 준 저품질 선택국을 뜻함)
close all; clear; clc;

% ---- 프로젝트 경로 자동 설정 ----
thisDir = fileparts(mfilename('fullpath'));
if isempty(thisDir); thisDir = pwd; end
projectRoot = thisDir;
while ~isfolder(fullfile(projectRoot, 'Src'))
    parentDir = fileparts(projectRoot);
    if isempty(parentDir) || strcmp(parentDir, projectRoot); projectRoot = thisDir; break; end
    projectRoot = parentDir;
end
optDir = fileparts(thisDir);
ngiiPaths = {thisDir, optDir, projectRoot, fullfile(projectRoot,'Src'), ...
    fullfile(projectRoot,'Src','Reference Code'), fullfile(projectRoot,'Data','rts'), fullfile(projectRoot,'dd')};
for pIdx = 1:numel(ngiiPaths)
    if isfolder(ngiiPaths{pIdx}); addpath(ngiiPaths{pIdx}); end
end
% ---------------------------------

Rr = load(fullfile(optDir, 'result_ilp.mat'));  R = Rr.R;
lon = R.lon; lat = R.lat; isRef = logical(R.isRef); names = string(R.names);
N = numel(lon);
isB = false(N,1); isB(R.boundarySpec) = true;

[~, ~, ~, T] = load_stations();
cfg = net_config();
qc = qc_rules(T, cfg);
if isfield(qc, 'enabled') && ~qc.enabled
    % QC 비활성 상태에선 "cut-off 전환/외곽 예외" 분류가 성립하지 않음 — 지도 생략.
    % (남아 있으면 QC 규칙망 결과로 오독될 수 있어 기존 산출물도 제거)
    stale = fullfile(optDir, 'result_fig', '01_망설계', 'qc_station_status.png');
    if isfile(stale); delete(stale); end
    fprintf('QC 비활성(cfg.qcEnable=false) — 선별 상태 지도 생략 (qc_station_status.png 제거)\n');
    return;
end

noQC = false(N,1);
if isfield(qc, 'noQC'); noQC = qc.noQC; end        % 신설 QC 미평가국 (컷 면제)
availCut = ~((qc.avail > 0) & (qc.avail >= qc.availThr)) & ~noQC;   % 유효 임계 기준 (0=미제공 포함)
slpsCut  = ~availCut & ~(qc.slps < cfg.qcMaxSLPS) & ~noQC;
cand = ~isB & qc.refOK & ~isnan(qc.score);
Sbar = mean(qc.score(cand));

bExempt     = isB & (availCut | slpsCut);          % 외곽 고정 예외 (QC 미달 유지)
forcedAvail = availCut & ~isB;                     % Availability cut 전환
forcedSlps  = slpsCut  & ~isB;                     % SLPS cut 전환
lowScoreRef = isRef & cand & qc.score < Sbar;      % 선택 기준국 중 개별 Score < S̄
normRef = isRef & ~bExempt & ~lowScoreRef & ~noQC;
normMon = ~isRef & ~forcedAvail & ~forcedSlps & ~noQC;

fprintf('S_bar(후보 평균 Score) = %.3f / 선택 기준국 평균 = %.3f\n', ...
    Sbar, mean(qc.score(isRef & cand)));
fprintf('외곽 예외 %d: %s\n', nnz(bExempt), strjoin(compose("%s(a%.2f/s%.1f)", names(bExempt), qc.avail(bExempt), qc.slps(bExempt))', ', '));
fprintf('Avail 전환 %d: %s\n', nnz(forcedAvail), strjoin(compose("%s(%.2f)", names(forcedAvail), qc.avail(forcedAvail))', ', '));
fprintf('SLPS 전환 %d: %s\n', nnz(forcedSlps), strjoin(compose("%s(%.1f)", names(forcedSlps), qc.slps(forcedSlps))', ', '));
fprintf('S_bar 미만 기준국 %d: %s\n', nnz(lowScoreRef), strjoin(compose("%s(%.3f)", names(lowScoreRef), qc.score(lowScoreRef))', ', '));
if any(noQC)
    fprintf('신설 QC 미평가 %d: %s (기준국 %d / 감시국 %d)\n', nnz(noQC), ...
        strjoin(names(noQC)', ', '), nnz(noQC & isRef), nnz(noQC & ~isRef));
end

%% 지도 (960x720 표준)
fig = figure('Name','qc_station_status','Color','w','Position',[80 80 960 720]);
gx = geoaxes;
try
    geobasemap(gx, 'grayland');
catch
end
hold(gx, 'on');

lonR = lon(isRef); latR = lat(isRef);
DT = delaunayTriangulation(lonR, latR); E = edges(DT);
lat_e = [latR(E(:,1)), latR(E(:,2)), NaN(size(E,1),1)]';
lon_e = [lonR(E(:,1)), lonR(E(:,2)), NaN(size(E,1),1)]';
geoplot(gx, lat_e(:), lon_e(:), '-', 'Color', [0.6 0.6 0.6], 'LineWidth', 0.4, 'HandleVisibility', 'off');

hh = gobjects(0, 1); lbl = {};
hh(end+1,1) = geoplot(gx, lat(normMon), lon(normMon), '^', 'MarkerEdgeColor', [0.3 0.3 0.3], ...
    'MarkerFaceColor', [0.55 0.65 0.95], 'MarkerSize', 4, 'LineStyle', 'none');
lbl{end+1} = sprintf('감시국 (%d개소)', nnz(normMon));
hh(end+1,1) = geoplot(gx, lat(normRef), lon(normRef), 's', 'MarkerEdgeColor', 'k', ...
    'MarkerFaceColor', 'y', 'MarkerSize', 6, 'LineStyle', 'none');
lbl{end+1} = sprintf('기준국 (%d개소)', nnz(normRef));
% 빈 카테고리는 geoplot 이 빈 핸들을 반환해 hh(end+1,1) 대입이 실패 — any() 가드 필수
if any(lowScoreRef)
    hh(end+1,1) = geoplot(gx, lat(lowScoreRef), lon(lowScoreRef), 's', 'MarkerEdgeColor', 'k', ...
        'MarkerFaceColor', [0.95 0.6 0.1], 'MarkerSize', 7, 'LineStyle', 'none');
    lbl{end+1} = sprintf('기준국·평균 품질(S=%.2f) 미만 (%d개소)', Sbar, nnz(lowScoreRef));
end
if any(bExempt)
    hh(end+1,1) = geoplot(gx, lat(bExempt), lon(bExempt), 's', 'MarkerEdgeColor', [0.85 0.1 0.1], ...
        'MarkerFaceColor', 'y', 'MarkerSize', 8, 'LineWidth', 1.6, 'LineStyle', 'none');
    lbl{end+1} = sprintf('기준국·외곽 예외 — QC 미달 유지 (%d개소)', nnz(bExempt));
end
if any(forcedAvail)
    hh(end+1,1) = geoplot(gx, lat(forcedAvail), lon(forcedAvail), 'v', 'MarkerEdgeColor', 'k', ...
        'MarkerFaceColor', [0.85 0.1 0.1], 'MarkerSize', 7, 'LineStyle', 'none');
    lbl{end+1} = sprintf('감시국 전환 — Availability<%.2f (%d개소)', qc.availThr, nnz(forcedAvail));
end
if any(forcedSlps)
    hh(end+1,1) = geoplot(gx, lat(forcedSlps), lon(forcedSlps), 'v', 'MarkerEdgeColor', 'k', ...
        'MarkerFaceColor', [0.8 0.45 0.65], 'MarkerSize', 7, 'LineStyle', 'none');
    lbl{end+1} = sprintf('감시국 전환 — SLPS>=%g (%d개소)', cfg.qcMaxSLPS, nnz(forcedSlps));
end
if any(noQC)
    hh(end+1,1) = geoplot(gx, lat(noQC), lon(noQC), 'd', 'MarkerEdgeColor', 'k', ...
        'MarkerFaceColor', [0.2 0.7 0.3], 'MarkerSize', 7, 'LineStyle', 'none');
    lbl{end+1} = sprintf('신설국 — QC 미평가·정상 운영 판정 (%d개소)', nnz(noQC));
end

% QC 관련 국 코드 라벨
flag = bExempt | forcedAvail | forcedSlps | lowScoreRef | noQC;
for k = find(flag)'
    text(gx, lat(k)+0.07, lon(k)+0.05, names(k), 'FontSize', 7.5, 'Color', [0.15 0.15 0.15]);
end

legend(gx, hh, lbl, 'Location', 'northeast', 'FontSize', 8);
title(gx, sprintf('QC 기준국 선별 상태 — 기선 상한 %g km', R.maxBaseKm));
geolimits(gx, [33 39], [125 132]); hold(gx, 'off');

figSave = fullfile(optDir, 'result_fig', '01_망설계');
if ~isfolder(figSave); mkdir(figSave); end
drawnow;
exportgraphics(fig, fullfile(figSave, 'qc_station_status.png'), 'Resolution', 200);
fprintf('그림 저장: %s\n', fullfile(figSave, 'qc_station_status.png'));
