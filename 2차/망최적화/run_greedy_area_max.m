%% [비교 기준] 감시가능망 면적 최대화 — 그리디 단독 실행
%  그리디만 실행/저장/시각화한다. ILP는 run_ilp_area_max.m, 둘의 비교는 run_pipeline.m.
%  실험 조건(maxBaseKm, nOuter)은 net_config.m 한 곳에서 관리한다.
clear; clc;

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

%% 1) 데이터 로드 (위성기준점 99개소)
[lon, lat, names] = load_stations();

%% 2) 공통 실험 조건 (net_config.m 단일 소스 — ILP와 항상 동일 조건)
cfg = net_config();
maxBaseKm = cfg.maxBaseKm;
bnd = outer_ring(lon, lat, cfg.nOuter);   % 명시적 외곽 고정 노드 인덱스
fprintf('실험 조건: maxBaseKm=%g km, 최외곽 고정 %d개\n', maxBaseKm, numel(bnd));

%% 3) 그리디 실행
tG = tic;
[isRef, info] = greedy_area_max(lon, lat, maxBaseKm, bnd);
tGreedy = toc(tG);
[aG, ncG] = valid_net_wgs84(lon, lat, isRef);

%% 4) 결과 저장 (plots/·export 가 이 파일만 로드)
save_net_result(fullfile(thisDir,'result_greedy.mat'), 'greedy', lon, lat, isRef, maxBaseKm, bnd, info, names);

%% 5) 요약 출력
fprintf('\n===== 감시가능망 면적 최대화 (그리디) =====\n');
fprintf('초기 기준국        : %d개\n', numel(lon));
fprintf('최적화 후 기준국   : %d개\n', sum(isRef));
fprintf('전환된 감시국      : %d개\n', sum(~isRef));
fprintf('감시 가능(유효) 셀 : %d개\n', ncG);
fprintf('감시 가능 망 면적  : %.2f km^2 (WGS84)\n', aG);
fprintf('소요 시간          : %.1f s\n', tGreedy);
fprintf('==========================================\n\n');

%% 6) 시각화 — 표준 지도 (plots/plot_net_map.m 공용)
plot_net_map(lon, lat, isRef, ...
    sprintf('감시가능망 면적 최대화 (그리디) — 기준국 %d, 감시국 %d, %.0f km^2', ...
            sum(isRef), sum(~isRef), aG), '그리디 면적 최대화');

% 수렴 곡선 (기준국 수 감소 vs 유효면적 증가)
figure('Name','그리디 수렴 곡선','Color','w','Position',[80 80 960 720]);
plot(info.nRefHist, info.Varea_km2, '-o', 'LineWidth',1.2, 'MarkerSize',4);
set(gca,'XDir','reverse'); grid on;
xlabel('기준국 수 (전환 진행 →)'); ylabel('유효면적 (km^2, 평면근사)');
title('전환에 따른 감시가능망 면적 변화 (그리디)');
