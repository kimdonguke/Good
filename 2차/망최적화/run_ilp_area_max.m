%% [실무 주력] 빈-외접원 ILP 면적 최대화 — ILP 단독 실행 + LP 상한 인증 + 실무 내보내기
%  ILP만 실행/저장/내보내기/시각화한다. 그리디는 run_greedy_area_max.m, 비교는 run_pipeline.m.
%  실험 조건(maxBaseKm, nOuter)은 net_config.m 한 곳에서 관리한다.
clear; clc;
tic

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

%% 2) 공통 실험 조건 (net_config.m 단일 소스 — 그리디와 항상 동일 조건) + QC 규칙
cfg = net_config();
maxBaseKm = cfg.maxBaseKm;
bnd = outer_ring(lon, lat, cfg.nOuter);   % 명시적 외곽 고정 노드 인덱스
fprintf('실험 조건: maxBaseKm=%g km, 최외곽 고정 %d개\n', maxBaseKm, numel(bnd));
qc = qc_rules(Tst, cfg);
lowB = bnd(~qc.refOK(bnd));
if ~isempty(lowB)
    fprintf('경고: 외곽 고정국 중 가용성 미달(구조상 기준국 유지): %s\n', strjoin(names(lowB)', ', '));
end

%% 3) ILP 전역최적
tI = tic;
[isRef, info] = ilp_area_max(lon, lat, maxBaseKm, bnd, qc);
tILP = toc(tI);
if isnan(info.ilpObj_km2)
    error('run_ilp_area_max:ilpInfeasible', ...
        'ILP 비실현: maxBaseKm=%g + QC 규칙 조합으로는 망 구성이 불가합니다 (결과 저장 중단).', maxBaseKm);
end
[aI, ncI] = valid_net_wgs84(lon, lat, isRef, qc.monOK);

%% 4) 결과 저장 + 실무 내보내기
save_net_result(fullfile(thisDir,'result_ilp.mat'), 'ilp', lon, lat, isRef, maxBaseKm, bnd, info, names, qc.monOK);
export_result_mat(fullfile(thisDir,'result_ilp.mat'));    % 관측소 정보표 <maxBaseKm>_result.mat
export_assignment(fullfile(thisDir,'result_ilp.mat'));    % 배정표 assignment_ilp.csv + 전환 목록

%% 5) 요약 출력
fprintf('\n===== 빈-외접원 ILP 면적 최대화 (전역최적) =====\n');
fprintf('후보 삼각형        : %d개 (raw %d)\n', info.nCand, info.nCandRaw);
fprintf('no-good 컷 반복     : %d회\n', info.iters);
fprintf('기준국 / 감시국     : %d / %d\n', sum(isRef), sum(~isRef));
fprintf('감시 가능(유효) 셀 : %d개\n', ncI);
fprintf('감시 가능 망 면적  : %.1f km^2 (WGS84)\n', aI);
fprintf('소요 시간          : %.1f s\n', tILP);
fprintf('-----------------------------------------------\n');
fprintf('LP 상한(dual bound): %.1f km^2\n', info.lpBound_km2);
fprintf('ILP 내부 목적값     : %.1f km^2 (실제 재계산 %.1f)\n', info.ilpObj_km2, aI);
fprintf('ILP 최적성 인증     : %.2f%% (ILP/LP상한, 100%%이면 증명완료)\n', 100*aI/info.lpBound_km2);
fprintf('===============================================\n\n');

%% 6) 시각화 — 표준 지도 (plots/plot_net_map.m 공용)
plot_net_map(lon, lat, isRef, ...
    sprintf('최적 감시망 구성 (ILP) — 기준국 %d, 감시국 %d, 감시가능 면적 %.0f km^2', ...
            sum(isRef), sum(~isRef), aI), 'ILP 면적 최대화 (전역최적)', qc.monOK);
toc
