%% PPT_STEP_FIGURES  그리디 flowchart 단계별 PPT용 figure 생성기
%
%  figure_for_ppt/greedy_flowchart.png 의 각 박스에 대응하는 그림을 생성한다.
%  기존 geoplot(지형도 배경 + 노랑 기준국/파랑 감시국/빨강 유효셀) 스타일 위에 렌더링.
%
%  사용법(대화형):  MATLAB에서 실행 → 번호 입력
%     1 : 주어진 기준국들로 들로네 삼각분할     (1a 노드만, 1b 삼각망)
%     2 : 감시국 전환 시 면적이득 선계산        (노드별 이득 컬러 버블)
%     3 : 면적이득 정렬 & max 노드 선택         (상위5 순위 + 1위 강조)
%     4 : 제약조건 위반 검사                    (4a 통과, 4b 위반 예시)
%     5 : i번째 노드 감시국 임무 전환           (5a 전환 직전, 5b 직후)
%     6 : 면적이득 수렴 검사                    (6a 수렴곡선, 6b 중간 스냅샷)
%     7 : 면적 최대화 완료                      (최종 결과 지도)
%     0 : 전체(1~7) 생성   /   Enter : 종료
%  사용법(배치):  setenv('PPT_STEP','0'); ppt_step_figures
%
%  생성된 PNG는 figure_for_ppt/ 에 자동 저장된다 (200dpi).
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
optDir = fileparts(thisDir);            % 망최적화 폴더 (알고리즘·결과 파일)
ngiiPaths = {thisDir, optDir, projectRoot, fullfile(projectRoot,'Src'), ...
    fullfile(projectRoot,'Src','Reference Code'), fullfile(projectRoot,'Data','rts'), fullfile(projectRoot,'dd')};
for pIdx = 1:numel(ngiiPaths)
    if isfolder(ngiiPaths{pIdx}); addpath(ngiiPaths{pIdx}); end
end
figDir = fullfile(optDir, 'figure_for_ppt');
if ~isfolder(figDir); mkdir(figDir); end
% ---------------------------------

%% 데이터 로드 (최신 고시 위성기준점, stations_ngii.mat — 공식 파이프라인과 동일 소스)
[lon, lat, names] = load_stations();
lon = lon(:); lat = lat(:);
N = numel(lon);

%% 알고리즘 준비 (한 번만 계산해서 모든 단계가 재사용 — 조건은 net_config 단일 소스)
cfg = net_config();
maxBaseKm = cfg.maxBaseKm;
bnd = outer_ring(lon, lat, cfg.nOuter);
if isfield(cfg, 'outerForce') && ~isempty(cfg.outerForce)
    bnd = unique([bnd(:); find(ismember(names, cfg.outerForce))]);   % 강제 보완국 합집합
end
isBnd = false(N,1); isBnd(bnd) = true;

% grandfather: 초기 전체망의 >maxBaseKm 기선쌍 (도서 연결 면제)
DT0 = delaunayTriangulation(lon, lat);
E0 = edges(DT0);
len0 = deg2km(distance(lat(E0(:,1)),lon(E0(:,1)),lat(E0(:,2)),lon(E0(:,2))));
grandPairs = sort(E0(len0>maxBaseKm,:), 2);

% 초기 한계이득 선계산 (flowchart 2번: 모든 내륙 후보의 전환 이득)
isRef0 = true(N,1);
gain0 = nan(N,1); feas0 = false(N,1);
cand0 = find(~isBnd);
for k = 1:numel(cand0)
    x = cand0(k);
    tent = isRef0; tent(x) = false;
    [f, V] = cfgMetrics(lon, lat, tent, maxBaseKm, grandPairs);
    if f; gain0(x) = V; feas0(x) = true; end   % 초기 V0=0 이므로 이득 = V
end

% 그리디 전체 실행 (flowchart 5~7번: 전환 순서/수렴 이력)
[isRefFinal, info] = greedy_area_max(lon, lat, maxBaseKm, bnd);

fprintf('\n준비 완료: N=%d, 외곽 %d개 고정, 초기 feasible 후보 %d개, 최종 기준국 %d개\n', ...
    N, numel(bnd), sum(feas0), sum(isRefFinal));

%% 단계 선택 루프 (input) — 배치는 PPT_STEP 환경변수
envSel = getenv('PPT_STEP');
if ~isempty(envSel)
    queue = str2num(envSel); %#ok<ST2NM>  배치 모드
else
    queue = [];                            % 대화형 모드
end
while true
    if ~isempty(envSel)
        if isempty(queue); break; end
        sel = queue(1); queue(1) = [];
    else
        sel = input('\n생성할 단계 번호 (1~7, 0=전체, Enter=종료): ');
        if isempty(sel); break; end
    end
    steps = sel; if sel == 0; steps = 1:7; end
    for s = steps
        switch s
            case 1, step1_init(lon, lat, isBnd, figDir);
            case 2, step2_gains(lon, lat, isBnd, gain0, figDir);
            case 3, step3_select(lon, lat, isBnd, gain0, feas0, figDir);
            case 4, step4_check(lon, lat, isBnd, isRefFinal, gain0, feas0, maxBaseKm, grandPairs, figDir);
            case 5, step5_switch(lon, lat, info, figDir);
            case 6, step6_converge(lon, lat, info, figDir);
            case 7, step7_final(lon, lat, isRefFinal, figDir);
            otherwise, fprintf('  1~7 또는 0을 입력하세요.\n');
        end
    end
    if ~isempty(envSel) && isempty(queue); break; end
end
fprintf('\n완료. PNG 저장 폴더: %s\n', figDir);

% ========================================================================
%  STEP 1 : 주어진 기준국들로 들로네 삼각분할 (initializing)
% ========================================================================
function step1_init(lon, lat, isBnd, figDir)
    % (1a) 노드만 — 입력 데이터
    gx = newMap('1a 기준국 노드');
    geoplot(gx, lat, lon, 'ks', 'MarkerFaceColor','y', 'MarkerSize',6, ...
        'DisplayName', sprintf('기준국 (%d개소)', numel(lat)));
    geoplot(gx, lat(isBnd), lon(isBnd), 'ks', 'MarkerFaceColor',[1 .55 0], 'MarkerSize',7, ...
        'DisplayName','최외곽 기준국 (고정)');
    legend(gx, 'Location','northeast');
    title(gx, sprintf('STEP 1. 입력: 위성기준점 %d개소', numel(lat)));
    saveFig(figDir, 'step1a_nodes.png');

    % (1b) 들로네 삼각분할 — 망 초기화
    gx = newMap('1b 들로네 삼각분할');
    DT = delaunayTriangulation(lon, lat);
    drawEdges(gx, DT, lon, lat, 0.7, 'k', '기선(Delaunay)');
    geoplot(gx, lat, lon, 'ks', 'MarkerFaceColor','y', 'MarkerSize',6, ...
        'DisplayName','기준국');
    geoplot(gx, lat(isBnd), lon(isBnd), 'ks', 'MarkerFaceColor',[1 .55 0], 'MarkerSize',7, ...
        'DisplayName','최외곽(고정)');
    legend(gx, 'Location','northeast');
    title(gx, sprintf('STEP 1. 들로네 삼각분할 (셀 %d개, 기선 %d개)', ...
        size(DT.ConnectivityList,1), size(edges(DT),1)));
    saveFig(figDir, 'step1b_delaunay.png');
end

% ========================================================================
%  STEP 2 : 내륙 기준국들의 감시국 전환 시 면적이득 선계산
% ========================================================================
function step2_gains(lon, lat, isBnd, gain0, figDir)
    gx = newMap('2 면적이득 선계산');
    DT = delaunayTriangulation(lon, lat);
    drawEdges(gx, DT, lon, lat, 0.4, [0.55 0.55 0.55], '');
    % 이득을 색+크기로 (내륙 feasible 후보만)
    ok = ~isBnd & ~isnan(gain0);
    g = gain0(ok);
    sz = 30 + 90*(g - min(g)) ./ max(max(g)-min(g), eps);
    geoscatter(gx, lat(ok), lon(ok), sz, g, 'filled', 'MarkerEdgeColor','k', ...
        'DisplayName','후보 이득 (색·크기)');
    colormap(gx, turbo);   % 이득은 색·크기로 표현 (colorbar 제거: 지도 영역 통일)
    % 외곽(고정) + 계산 제외 노드
    geoplot(gx, lat(isBnd), lon(isBnd), 'ks', 'MarkerFaceColor',[1 .55 0], 'MarkerSize',7, ...
        'DisplayName','최외곽(고정)');
    inf_ = ~isBnd & isnan(gain0);
    if any(inf_)
        geoplot(gx, lat(inf_), lon(inf_), 'kx', 'MarkerSize',8, 'LineWidth',1.4, ...
            'DisplayName','제약위반(전환불가)');
    end
    legend(gx, 'Location','northeast');
    title(gx, 'STEP 2. 감시국 전환 시 면적이득 선계산 (전 후보)');
    saveFig(figDir, 'step2_gains.png');
end

% ========================================================================
%  STEP 3 : 면적이득 순 정렬 → max(Node_i) 선택
% ========================================================================
function step3_select(lon, lat, isBnd, gain0, feas0, figDir)
    gx = newMap('3 최대이득 노드 선택');
    DT = delaunayTriangulation(lon, lat);
    drawEdges(gx, DT, lon, lat, 0.4, [0.55 0.55 0.55], '');
    geoplot(gx, lat, lon, 'ks', 'MarkerFaceColor','y', 'MarkerSize',6, 'DisplayName','기준국');
    geoplot(gx, lat(isBnd), lon(isBnd), 'ks', 'MarkerFaceColor',[1 .55 0], 'MarkerSize',7, ...
        'DisplayName','최외곽(고정)');
    % feasible 이득 상위 5 순위 표시
    g = gain0; g(~feas0) = -inf;
    [~, ord] = sort(g, 'descend');
    top5 = ord(1:5);
    geoplot(gx, lat(top5), lon(top5), 'o', 'Color',[0.85 0.2 0.2], ...
        'MarkerSize',13, 'LineWidth',1.5, 'DisplayName','이득 상위 5');
    geoplot(gx, lat(top5(1)), lon(top5(1)), 'o', 'Color',[0.85 0.2 0.2], ...
        'MarkerSize',20, 'LineWidth',2.5, 'DisplayName','max(Node_i) : 1위');
    for r = 1:5
        text(gx, lat(top5(r))+0.09, lon(top5(r))+0.09, sprintf('%d위', r), ...
            'Color',[0.75 0.1 0.1], 'FontWeight','bold', 'FontSize',10);
    end
    legend(gx, 'Location','northeast');
    title(gx, sprintf('STEP 3. 면적이득 정렬 → 최대 이득 노드 선택 (1위 = %.0f km^2)', g(top5(1))));
    saveFig(figDir, 'step3_selection.png');
end

% ========================================================================
%  STEP 4 : 제약조건(신규 기선 ≤ 100 km) 위반 검사 — 통과/위반 예시
% ========================================================================
function step4_check(lon, lat, isBnd, isRefFinal, gain0, feas0, maxKm, grandPairs, figDir)
    N = numel(lon);
    % --- (4a) 통과 예시: 초기 상태에서 feasible 최대이득 노드 ---
    g = gain0; g(~feas0) = -inf; [~, xPass] = max(g);
    [newP, newL] = newBaselines(lon, lat, true(N,1), xPass);
    gx = newMap('4a 제약 검사: 통과');
    drawEdges(gx, delaunayTriangulation(lon,lat), lon, lat, 0.4, [0.6 0.6 0.6], '');
    plotPairs(gx, lon, lat, newP, '-', [0 0.45 0.85], 2.0, '신규 기선 (전환 후 생성)');
    geoplot(gx, lat, lon, 'ks', 'MarkerFaceColor','y', 'MarkerSize',6, 'DisplayName','기준국');
    geoplot(gx, lat(xPass), lon(xPass), 'o', 'Color','m', 'MarkerSize',16, 'LineWidth',2.5, ...
        'DisplayName','검사 대상 노드');
    legend(gx, 'Location','northeast');
    title(gx, sprintf('STEP 4a. 제약 검사 통과: 신규 기선 최대 %.1f km \\leq %d km', max(newL), maxKm));
    saveFig(figDir, 'step4a_check_pass.png');

    % --- (4b) 위반 예시: 전환하면 >100km 신규 기선이 생기는 노드 탐색 ---
    [xViol, isRefCtx] = findViolationNode(lon, lat, isBnd, isRefFinal, maxKm, grandPairs);
    if isempty(xViol)
        fprintf('  [4b] 위반 예시 노드를 찾지 못했습니다(생략).\n'); return;
    end
    [newP, newL] = newBaselines(lon, lat, isRefCtx, xViol);
    bad = newL > maxKm & ~ismember(sort(newP,2), grandPairs, 'rows');
    gx = newMap('4b 제약 검사: 위반');
    R = find(isRefCtx);
    drawEdges(gx, delaunayTriangulation(lon(R),lat(R)), lon(R), lat(R), 0.4, [0.6 0.6 0.6], '');
    plotPairs(gx, lon, lat, newP(~bad,:), '-',  [0 0.45 0.85], 1.6, '신규 기선 (\leq100km)');
    plotPairs(gx, lon, lat, newP(bad,:),  '--', [0.9 0.1 0.1], 2.4, '위반 기선 (>100km)');
    geoplot(gx, lat(R), lon(R), 'ks', 'MarkerFaceColor','y', 'MarkerSize',6, 'DisplayName','기준국');
    geoplot(gx, lat(xViol), lon(xViol), 'o', 'Color','m', 'MarkerSize',16, 'LineWidth',2.5, ...
        'DisplayName','검사 대상 노드');
    bi = find(bad, 1);
    text(gx, mean(lat(newP(bi,:)))+0.10, mean(lon(newP(bi,:)))+0.10, ...
        sprintf('%.0f km > %d km', newL(bi), maxKm), ...
        'Color',[0.85 0 0], 'FontWeight','bold', 'FontSize',11);
    legend(gx, 'Location','northeast');
    title(gx, 'STEP 4b. 제약 위반 → 이 노드는 전환 불가, 다음 순위로');
    saveFig(figDir, 'step4b_check_violation.png');
end

% ========================================================================
%  STEP 5 : i번째 노드 감시국으로 임무 전환 (전환 직전 / 직후)
% ========================================================================
function step5_switch(lon, lat, info, figDir)
    N = numel(lon);
    xSel = info.removedOrder(1);            % 그리디가 실제로 첫 번째 전환한 노드

    % (5a) 전환 직전
    gx = newMap('5a 전환 직전');
    drawEdges(gx, delaunayTriangulation(lon,lat), lon, lat, 0.5, [0.45 0.45 0.45], '');
    geoplot(gx, lat, lon, 'ks', 'MarkerFaceColor','y', 'MarkerSize',6, 'DisplayName','기준국');
    geoplot(gx, lat(xSel), lon(xSel), 'o', 'Color','m', 'MarkerSize',16, 'LineWidth',2.5, ...
        'DisplayName','선택된 max(Node_i)');
    legend(gx, 'Location','northeast');
    title(gx, 'STEP 5. 전환 직전: 선택 노드는 아직 기준국');
    saveFig(figDir, 'step5a_before.png');

    % (5b) 전환 직후: 재삼각분할 + 해당 노드가 든 셀 = 유효셀(빨강)
    isRef1 = true(N,1); isRef1(xSel) = false;
    R = find(isRef1); lonR = lon(R); latR = lat(R);
    DT = delaunayTriangulation(lonR, latR); CL = DT.ConnectivityList;
    ti = pointLocation(DT, lon(xSel), lat(xSel));
    gx = newMap('5b 전환 직후');
    if ~isnan(ti)
        n = CL(ti,:);
        geoplot(gx, geopolyshape([latR(n);latR(n(1))],[lonR(n);lonR(n(1))]), ...
            'EdgeColor','k','LineWidth',0.5,'FaceColor','r','FaceAlpha',0.35,'HandleVisibility','off');
    end
    drawEdges(gx, DT, lonR, latR, 0.5, [0.45 0.45 0.45], '');
    geoplot(gx, latR, lonR, 'ks', 'MarkerFaceColor','y', 'MarkerSize',6, 'DisplayName','기준국');
    geoplot(gx, lat(xSel), lon(xSel), 'k^', 'MarkerFaceColor','b', 'MarkerSize',9, ...
        'DisplayName','감시국으로 전환');
    legend(gx, 'Location','northeast');
    title(gx, 'STEP 5. 전환 직후: 재삼각분할 + 감시국이 포함된 셀 = 감시가능(빨강)');
    saveFig(figDir, 'step5b_after.png');
end

% ========================================================================
%  STEP 6 : 면적이득 수렴 검사 (수렴 곡선 + 중간 스냅샷)
% ========================================================================
function step6_converge(lon, lat, info, figDir)
    % (6a) 수렴 곡선
    figure('Name','6a 수렴 곡선','Color','w','Position',[80 80 960 720]);
    plot(info.nRefHist, info.Varea_km2, '-o', 'LineWidth',1.4, 'MarkerSize',4, ...
        'Color',[0.2 0.45 0.85], 'MarkerFaceColor',[0.2 0.45 0.85]);
    set(gca,'XDir','reverse'); grid on;
    xlabel('기준국 수 (전환 진행 →)'); ylabel('감시가능 면적 (km^2)');
    title('STEP 6. 반복별 면적이득 — 이득이 0이 되면 수렴');
    yl = ylim; hold on;
    plot(info.nRefHist(end), info.Varea_km2(end), 'p', 'MarkerSize',16, ...
        'MarkerFaceColor',[0.85 0.2 0.2], 'MarkerEdgeColor','k');
    text(double(info.nRefHist(end))+1.2, double(info.Varea_km2(end)), '수렴(종료)', ...
        'Color',[0.75 0.1 0.1], 'FontWeight','bold');
    ylim(yl); hold off;
    saveFig(figDir, 'step6a_convergence.png');

    % (6b) 중간(50%) 스냅샷 지도
    N = numel(lon);
    half = round(numel(info.removedOrder)/2);
    isRefH = true(N,1); isRefH(info.removedOrder(1:half)) = false;
    gx = newMap('6b 중간 스냅샷');
    drawNetState(gx, lon, lat, isRefH);
    title(gx, sprintf('STEP 6. 반복 진행 중 (전환 %d/%d)', half, numel(info.removedOrder)));
    saveFig(figDir, 'step6b_snapshot.png');
end

% ========================================================================
%  STEP 7 : 면적 최대화 완료(수렴) — 최종 결과
% ========================================================================
function step7_final(lon, lat, isRefFinal, figDir)
    [aFin, ncFin] = valid_net_wgs84(lon, lat, isRefFinal);
    gx = newMap('7 최종 결과');
    drawNetState(gx, lon, lat, isRefFinal);
    title(gx, sprintf('STEP 7. 면적 최대화 완료: 기준국 %d, 감시국 %d, 유효셀 %d개, %.0f km^2', ...
        sum(isRefFinal), sum(~isRefFinal), ncFin, aFin));
    saveFig(figDir, 'step7_final.png');
end

% ========================================================================
%  공통 헬퍼
% ========================================================================
function gx = newMap(name)
    figure('Name',name,'Color','w','Position',[80 80 960 720]);
    gx = geoaxes; hold(gx,'on');
    try, geobasemap(gx,'topographic'); catch, end   % 오프라인이면 배경 생략
    geolimits(gx, [33 39], [125 131]);
end

function saveFig(figDir, fname)
    drawnow;
    print(gcf, fullfile(figDir,fname), '-dpng', '-r200');   % 캔버스 그대로 → 픽셀 크기 통일
    fprintf('  저장: %s\n', fname);
end

function drawEdges(gx, DT, lonV, latV, lw, col, name)
%  삼각망 기선 일괄 렌더. name 비면 legend에서 숨김.
    E = edges(DT);
    lat_e = [latV(E(:,1)), latV(E(:,2)), NaN(size(E,1),1)]';
    lon_e = [lonV(E(:,1)), lonV(E(:,2)), NaN(size(E,1),1)]';
    h = geoplot(gx, lat_e(:), lon_e(:), '-', 'LineWidth', lw, 'Color', col);
    if isempty(name); h.HandleVisibility = 'off'; else; h.DisplayName = name; end
end

function plotPairs(gx, lon, lat, P, spec, col, lw, name)
%  원본 인덱스 쌍 P의 선분들 렌더 (신규/위반 기선 강조용)
    if isempty(P); return; end
    la = [lat(P(:,1)), lat(P(:,2)), NaN(size(P,1),1)]';
    lo = [lon(P(:,1)), lon(P(:,2)), NaN(size(P,1),1)]';
    geoplot(gx, la(:), lo(:), spec, 'Color', col, 'LineWidth', lw, 'DisplayName', name);
end

function drawNetState(gx, lon, lat, isRef)
%  기준국망 상태(유효셀 빨강 + 기준국/감시국)를 지도에 렌더
    R = find(isRef); lonR = lon(R); latR = lat(R);
    lonM = lon(~isRef); latM = lat(~isRef);
    DT = delaunayTriangulation(lonR, latR); CL = DT.ConnectivityList;
    ti = pointLocation(DT, lonM, latM); ti = ti(~isnan(ti));
    red = unique(ti);
    for i = 1:numel(red)
        n = CL(red(i),:);
        geoplot(gx, geopolyshape([latR(n);latR(n(1))],[lonR(n);lonR(n(1))]), ...
            'EdgeColor','k','LineWidth',0.5,'FaceColor','r','FaceAlpha',0.3,'HandleVisibility','off');
    end
    drawEdges(gx, DT, lonR, latR, 0.5, [0.45 0.45 0.45], '');
    geoplot(gx, latR, lonR, 'ks', 'MarkerFaceColor','y', 'MarkerSize',6, 'DisplayName','기준국');
    geoplot(gx, latM, lonM, 'k^', 'MarkerFaceColor','b', 'MarkerSize',5, 'DisplayName','감시국');
    legend(gx, 'Location','northeast');
end

function [newP, newL] = newBaselines(lon, lat, isRefCtx, x)
%  상태 isRefCtx에서 노드 x를 전환했을 때 "새로 생기는" 기선(원본 인덱스 쌍)과 길이(km)
    R0 = find(isRefCtx);
    E_before = pairSet(lon, lat, R0);
    R1 = setdiff(R0, x);
    E_after = pairSet(lon, lat, R1);
    newP = setdiff(E_after, E_before, 'rows');
    newL = deg2km(distance(lat(newP(:,1)),lon(newP(:,1)),lat(newP(:,2)),lon(newP(:,2))));
end

function P = pairSet(lon, lat, R)
    DT = delaunayTriangulation(lon(R), lat(R));
    E = edges(DT);
    P = sort(R(E), 2);
end

function [xViol, isRefCtx] = findViolationNode(lon, lat, isBnd, isRefFinal, maxKm, grandPairs)
%  전환 시 >100km 신규 기선(비면제)이 생기는 노드를 탐색. 초기 상태 → 최종 상태 순.
    ctxs = {true(numel(lon),1), isRefFinal};
    for c = 1:2
        isRefCtx = ctxs{c};
        cand = find(isRefCtx & ~isBnd);
        for k = 1:numel(cand)
            x = cand(k);
            [newP, newL] = newBaselines(lon, lat, isRefCtx, x);
            bad = newL > maxKm & ~ismember(sort(newP,2), grandPairs, 'rows');
            if any(bad); xViol = x; return; end
        end
    end
    xViol = []; isRefCtx = [];
end

function [feas, V] = cfgMetrics(lon, lat, isRef, maxKm, grandPairs)
%  greedy_monitor_net.configMetrics 동일 로직(면적 목적): 제약검사 + 유효면적(평면근사)
    R = find(isRef);
    if numel(R) < 3; feas = false; V = 0; return; end
    lonR = lon(R); latR = lat(R);
    DT = delaunayTriangulation(lonR, latR);
    if isempty(DT.ConnectivityList); feas = false; V = 0; return; end
    E = edges(DT);
    lenKm = deg2km(distance(latR(E(:,1)),lonR(E(:,1)),latR(E(:,2)),lonR(E(:,2))));
    bad = lenKm > maxKm;
    if any(bad)
        feas = all(ismember(sort(R(E(bad,:)),2), grandPairs, 'rows'));
    else
        feas = true;
    end
    if ~feas; V = 0; return; end
    M = find(~isRef);
    if isempty(M); V = 0; return; end
    ti = pointLocation(DT, lon(M), lat(M)); ti = ti(~isnan(ti));
    cells = unique(ti);
    if isempty(cells); V = 0; return; end
    lat0 = mean(latR); kx = 111.320*cosd(lat0); ky = 110.574;
    X = lonR*kx; Y = latR*ky; CL = DT.ConnectivityList(cells,:);
    V = sum(0.5*abs((X(CL(:,2))-X(CL(:,1))).*(Y(CL(:,3))-Y(CL(:,1))) ...
                  - (X(CL(:,3))-X(CL(:,1))).*(Y(CL(:,2))-Y(CL(:,1)))));
end
