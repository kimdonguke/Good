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

%% 1) 데이터 로드 (위성기준점 99개소)
[lon, lat, names] = load_stations();

%% 2) 공통 실험 조건 (net_config.m 단일 소스)
cfg = net_config();
maxBaseKm = cfg.maxBaseKm;
bnd = outer_ring(lon, lat, cfg.nOuter);   % 명시적 외곽 고정 노드 인덱스
fprintf('실험 조건: maxBaseKm=%g km, 최외곽 고정 %d개, 관측소 %d개\n', ...
        maxBaseKm, numel(bnd), numel(lon));

%% 3) 그리디 (비교 기준)
tG = tic;
[isRefG, infoG] = greedy_area_max(lon, lat, maxBaseKm, bnd);
tGreedy = toc(tG);
[aG, ncG] = valid_net_wgs84(lon, lat, isRefG);
save_net_result(fullfile(thisDir,'result_greedy.mat'), 'greedy', lon, lat, isRefG, maxBaseKm, bnd, infoG, names);

%% 4) ILP (전역최적)
tI = tic;
[isRefI, infoI] = ilp_area_max(lon, lat, maxBaseKm, bnd);
tILP = toc(tI);
[aI, ncI] = valid_net_wgs84(lon, lat, isRefI);
save_net_result(fullfile(thisDir,'result_ilp.mat'), 'ilp', lon, lat, isRefI, maxBaseKm, bnd, infoI, names);

%% 5) 실무 내보내기 (ILP 기준)
export_result_mat(fullfile(thisDir,'result_ilp.mat'));    % 관측소 정보표 <maxBaseKm>_result.mat
export_assignment(fullfile(thisDir,'result_ilp.mat'));    % 배정표 assignment_ilp.csv + 전환 목록

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

%% 7) 시각화 — 표준 지도 2장 + 면적 비교 막대
plot_net_map(lon, lat, isRefG, ...
    sprintf('감시가능망 면적 최대화 (그리디) — 기준국 %d, 감시국 %d, %.0f km^2', ...
            sum(isRefG), sum(~isRefG), aG), '그리디 (비교 기준)');
plot_net_map(lon, lat, isRefI, ...
    sprintf('최적 감시망 구성 (ILP) — 기준국 %d, 감시국 %d, 감시가능 면적 %.0f km^2', ...
            sum(isRefI), sum(~isRefI), aI), 'ILP (전역최적)');

figure('Name','면적 비교','Color','w','Position',[80 80 960 720]);
vals = [aG, aI, infoI.lpBound_km2];
bar(categorical({'그리디','ILP최적','LP상한'},{'그리디','ILP최적','LP상한'}), vals, 0.5);
ylabel('감시가능망 면적 (km^2)'); grid on;
title({'감시가능 면적 비교 — Greedy, ILP, LP 상한', ...
       sprintf('Greedy/ILP = %.1f%%,  ILP/상한 = %.1f%%', 100*aG/aI, 100*aI/infoI.lpBound_km2)});
text(1:3, vals, compose('%.0f',vals), 'HorizontalAlignment','center','VerticalAlignment','bottom');

fprintf('통합 파이프라인 완료: %.1f s\n', toc(tAll));
