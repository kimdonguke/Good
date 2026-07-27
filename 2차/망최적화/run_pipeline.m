%% [통합 파이프라인] 데이터 → 그리디 → ILP → 비교/인증 → 실무 내보내기 → 시각화
%  두 알고리즘을 동일 조건(net_config.m)으로 실행하고 결과를 비교한다.
%  (MATLAB 은 한글 스크립트명을 실행할 수 없어 파일명은 run_pipeline.m 로 한다)
%  단독 실행: run_greedy_area_max.m / run_ilp_area_max.m
%  상세 통계(3열 표·기선장 분포)는 결과 저장 후 plots/run_stats.m 실행.
clear; clc;
tAll = tic;

%% 0) 경로 설정 (어느 PC에서든 동작)
thisDir = fileparts(mfilename('fullpath'));
if isempty(thisDir); thisDir = pwd; end
projectRoot = thisDir;
while ~isfolder(fullfile(projectRoot, 'Src'))
    parentDir = fileparts(projectRoot);
    if isempty(parentDir) || strcmp(parentDir, projectRoot); projectRoot = thisDir; break; end
    projectRoot = parentDir;
end
ngiiPaths = {thisDir, fullfile(thisDir,'plots'), projectRoot, fullfile(projectRoot,'Src'), ...
    fullfile(projectRoot,'Src','Reference Code'), ...
    fullfile(projectRoot,'Data','rts'), fullfile(projectRoot,'dd')};
for pIdx = 1:numel(ngiiPaths)
    if isfolder(ngiiPaths{pIdx}); addpath(ngiiPaths{pIdx}); end
end

if isempty(which('intlinprog'))
    error('Optimization Toolbox(intlinprog)가 설치되어 있지 않습니다. 설치된 툴박스 확인: ver');
end

%% 1) 데이터 로드 (최신 고시 위성기준점, stations_ngii.mat)
[lon, lat, names, Tst] = load_stations();

%% 2) 공통 실험 조건 (net_config.m 단일 소스) + QC 가용성 규칙
cfg = net_config();
maxBaseKm = cfg.maxBaseKm;
bnd = outer_ring(lon, lat, cfg.nOuter);   % 명시적 외곽 고정 노드 인덱스
if isfield(cfg, 'outerForce') && ~isempty(cfg.outerForce)
    bnd = unique([bnd(:); find(ismember(names, cfg.outerForce))]);   % 강제 보완국 합집합
end
fprintf('실험 조건: maxBaseKm=%g km, 최외곽 고정 %d개, 관측소 %d개\n', ...
        maxBaseKm, numel(bnd), numel(lon));
qc = qc_rules(Tst, cfg);                  % 가용성(2025-Q4) 기반 설계 규칙 마스크
lowB = bnd(~qc.refOK(bnd));
if ~isempty(lowB)
    fprintf('경고: 외곽 고정국 중 가용성 미달(구조상 기준국 유지): %s\n', strjoin(names(lowB)', ', '));
end

%% 3) 그리디 (비교 기준)
tG = tic;
[isRefG, infoG] = greedy_area_max(lon, lat, maxBaseKm, bnd, qc);
tGreedy = toc(tG);
[aG, ncG] = valid_net_wgs84(lon, lat, isRefG, qc.monOK);
save_net_result(fullfile(thisDir,'result_greedy.mat'), 'greedy', lon, lat, isRefG, maxBaseKm, bnd, infoG, names, qc.monOK);

%% 4) ILP (전역최적)
tI = tic;
[isRefI, infoI] = ilp_area_max(lon, lat, maxBaseKm, bnd, qc);
tILP = toc(tI);
if isnan(infoI.ilpObj_km2)
    error('run_pipeline:ilpInfeasible', ...
        'ILP 비실현: maxBaseKm=%g + QC 규칙 조합으로는 망 구성이 불가합니다 (결과 저장 중단).', maxBaseKm);
end
[aI, ncI] = valid_net_wgs84(lon, lat, isRefI, qc.monOK);
save_net_result(fullfile(thisDir,'result_ilp.mat'), 'ilp', lon, lat, isRefI, maxBaseKm, bnd, infoI, names, qc.monOK);

%% 5) 실무 내보내기 (ILP 기준)
export_result_mat(fullfile(thisDir,'result_ilp.mat'));    % 관측소 정보표 <maxBaseKm>_result.mat
export_assignment(fullfile(thisDir,'result_ilp.mat'));    % 배정표 assignment_ilp.csv + 전환 목록
export_station_list(fullfile(thisDir,'result_ilp.mat'));  % 기준국/감시국 명단 <maxBaseKm>_station_list.xlsx

%% 6) 비교 요약 + 최적성 인증
fprintf('\n===== 통합 파이프라인: 그리디 vs ILP (면적 최대화) =====\n');
fprintf('후보 삼각형        : %d개 (raw %d)\n', infoI.nCand, infoI.nCandRaw);
fprintf('no-good 컷 반복     : %d회\n', infoI.iters);
fprintf('-----------------------------------------------------------\n');
fprintf('%-10s | %6s %6s %10s %8s\n','방법','기준국','유효셀','면적(km^2)','시간(s)');
fprintf('%-10s | %6d %6d %10.1f %8.1f\n','그리디', sum(isRefG), ncG, aG, tGreedy);
fprintf('%-10s | %6d %6d %10.1f %8.1f\n','ILP최적', sum(isRefI), ncI, aI, tILP);
fprintf('-----------------------------------------------------------\n');
fprintf('LP 상한(dual bound): %.1f km^2\n', infoI.lpBound_km2);
fprintf('ILP 내부 목적값     : %.1f km^2 (실제 재계산 %.1f)\n', infoI.ilpObj_km2, aI);
fprintf('그리디 최적성       : %.2f%% (그리디/ILP)\n', 100*aG/aI);
fprintf('그리디 갭(면적)     : %.1f km^2  (ILP−그리디)\n', aI-aG);
fprintf('ILP 최적성 인증     : %.2f%% (ILP/LP상한, 100%%이면 증명완료)\n', 100*aI/infoI.lpBound_km2);
fprintf('===========================================================\n');
fprintf('상세 통계(3열 표·기선장 분포): plots/run_stats.m 실행\n\n');

%% 7) 시각화 — 표준 지도 2장 + 면적 비교 막대 (result_fig/01_망설계 에 자동 저장)
figDir = fullfile(thisDir, 'result_fig', '01_망설계');
if ~isfolder(figDir); mkdir(figDir); end
[fG, ~] = plot_net_map(lon, lat, isRefG, ...
    '감시가능망 구성 — 그리디 (비교 기준)', '그리디 (비교 기준)', qc.monOK);
[fI, ~] = plot_net_map(lon, lat, isRefI, ...
    '최적 감시망 구성 — ILP (전역최적)', 'ILP (전역최적)', qc.monOK);

fB = figure('Name','면적 비교','Color','w','Position',[80 80 960 720]);
vals = [aG, aI, infoI.lpBound_km2];
bar(categorical({'그리디','ILP최적','LP상한'},{'그리디','ILP최적','LP상한'}), vals, 0.5);
ylabel('감시가능망 면적 (km^2)'); grid on;
title('감시가능 면적 비교 — 그리디 · ILP · LP 상한');
text(1:3, vals, compose('%.0f',vals), 'HorizontalAlignment','center','VerticalAlignment','bottom');

drawnow;
exportgraphics(fG, fullfile(figDir, 'Greedy_plot.png'), 'Resolution', 200);   % 여백 자동 크롭
exportgraphics(fI, fullfile(figDir, 'ILP_plot.png'), 'Resolution', 200);
exportgraphics(fB, fullfile(figDir, 'area_compare.png'), 'Resolution', 200);
fprintf('그림 저장: %s (Greedy_plot / ILP_plot / area_compare)\n', figDir);

fprintf('통합 파이프라인 완료: %.1f s\n', toc(tAll));
