%% PPT_ILP_STEP_FIGURES  ILP flowchart 단계별 PPT용 figure 생성기
%
%  plots/ilp_flowchart.m 순서도의 각 박스에 대응하는 그림을 생성한다.
%  기존 geoplot(지형도 배경) 스타일 위에 렌더링. 결과는 result_ilp.mat 기반.
%
%  사용법(대화형):  MATLAB에서 실행 → 번호 입력
%     1 : 후보 삼각형 열거·기선 필터        (1a 통과/탈락 예시, 1b 전체 후보)
%     2 : 기하 사전계산 inCirc/inTri        (2a 외접원 확대, 2b 프루닝 후 후보)
%     3 : MILP 제약 조립                    (3a Pack/Clique, 3b Forcing)
%     4 : LP 완화 → 상한                    (상한 vs ILP 목적 vs 실제면적)
%     5 : 분기한정                          (분기+가지치기 개념도)
%     6 : 실제 들로네 재검증                (기선 전수 검사 지도)
%     7 : 최적 망 확정                      (최종 결과 지도)
%     0 : 전체(1~7) 생성   /   Enter : 종료
%  사용법(배치):  setenv('PPT_ILP_STEP','0'); ppt_ilp_step_figures
%
%  생성 PNG → ../figure_for_ppt/ilp_step*.png (200dpi)
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

%% 결과 로드 (좌표·외곽·파라미터의 단일 출처)
resFile = fullfile(optDir, 'result_ilp.mat');
if ~isfile(resFile)
    error('결과 파일이 없습니다: %s\n먼저 run_ilp_area_max.m 을 실행하세요.', resFile);
end
Rr = load(resFile); R = Rr.R;
lon = R.lon(:); lat = R.lat(:); N = numel(lon);
maxBaseKm = R.maxBaseKm;
if isscalar(R.boundarySpec)
    bIdx = boundary(lon, lat, R.boundarySpec);
else
    bIdx = R.boundarySpec(:);
end
isBnd = false(N,1); isBnd(bIdx) = true;

%% 후보 열거 사전계산 (ilp_area_max STAGE1 동일 — 1~3단계 그림 재료)
DT0 = delaunayTriangulation(lon, lat); E0 = edges(DT0);
len0 = deg2km(distance(lat(E0(:,1)),lon(E0(:,1)),lat(E0(:,2)),lon(E0(:,2))));
grandPairs = sort(E0(len0>maxBaseKm,:), 2);

tris = nchoosek(1:N, 3);
d12 = deg2km(distance(lat(tris(:,1)),lon(tris(:,1)),lat(tris(:,2)),lon(tris(:,2))));
d13 = deg2km(distance(lat(tris(:,1)),lon(tris(:,1)),lat(tris(:,3)),lon(tris(:,3))));
d23 = deg2km(distance(lat(tris(:,2)),lon(tris(:,2)),lat(tris(:,3)),lon(tris(:,3))));
ok12 = (d12<=maxBaseKm) | ismember(sort(tris(:,[1 2]),2),grandPairs,'rows');
ok13 = (d13<=maxBaseKm) | ismember(sort(tris(:,[1 3]),2),grandPairs,'rows');
ok23 = (d23<=maxBaseKm) | ismember(sort(tris(:,[2 3]),2),grandPairs,'rows');
goodMask = ok12 & ok13 & ok23;
goodTris = tris(goodMask,:);   dmaxGood = max([d12(goodMask) d13(goodMask) d23(goodMask)],[],2);
badTris  = tris(~goodMask,:);  dBad = [d12(~goodMask) d13(~goodMask) d23(~goodMask)];
Mg = size(goodTris,1);

% good 후보의 외접원/내부점/프루닝 (최종 후보 = keep)
epsC = 1e-6; tolT = 1e-9;
keep = false(Mg,1); inCircList = cell(Mg,1); inTriList = cell(Mg,1);
ccU = nan(Mg,2); ccR2 = nan(Mg,1);
for t = 1:Mg
    a=goodTris(t,1); b=goodTris(t,2); c=goodTris(t,3);
    [ok,ux,uy,r2] = circum(lon(a),lat(a),lon(b),lat(b),lon(c),lat(c));
    if ~ok; continue; end
    ccU(t,:) = [ux uy]; ccR2(t) = r2;
    d2 = (lon-ux).^2 + (lat-uy).^2;
    inC = find(d2 < r2 - epsC); inC = inC(inC~=a & inC~=b & inC~=c);
    if any(isBnd(inC)); continue; end
    inT = pointsInTri(lon,lat,a,b,c,tolT); inT = inT(inT~=a & inT~=b & inT~=c);
    if isempty(inT); continue; end
    keep(t) = true; inCircList{t} = inC(:); inTriList{t} = inT(:);
end
fprintf('\n준비 완료: 후보 %d(변길이 통과) → 최종 %d개, 외곽 %d개 고정, 결과=%s(기준국 %d)\n', ...
    Mg, sum(keep), numel(bIdx), R.method, R.nRef);

%% 단계 선택 루프 (input) — 배치는 PPT_ILP_STEP 환경변수
envSel = getenv('PPT_ILP_STEP');
if ~isempty(envSel); queue = str2num(envSel); else; queue = []; end %#ok<ST2NM>
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
            case 1, step1_filter(lon, lat, goodTris, dmaxGood, badTris, dBad, maxBaseKm, grandPairs, figDir);
            case 2, step2_geometry(lon, lat, isBnd, goodTris, keep, inCircList, inTriList, ccU, ccR2, figDir);
            case 3, step3_constraints(lon, lat, goodTris, keep, inTriList, badTris, dBad, maxBaseKm, grandPairs, figDir);
            case 4, step4_lp_bound(R, figDir);
            case 5, step5_branch_bound(R, figDir);
            case 6, step6_recheck(R, grandPairs, figDir);
            case 7, step7_final(R, figDir);
            otherwise, fprintf('  1~7 또는 0을 입력하세요.\n');
        end
    end
    if ~isempty(envSel) && isempty(queue); break; end
end
fprintf('\n완료. PNG 저장 폴더: %s\n', figDir);

% ========================================================================
%  STEP 1 : 후보 삼각형 열거 · 기선 ≤100km 필터
% ========================================================================
function step1_filter(lon, lat, goodTris, dmaxGood, badTris, dBad, maxKm, grandPairs, figDir)
    % (1a) 통과/탈락 예시 삼각형 (변 길이 라벨)
    [~, ig] = max(dmaxGood);  Tg = goodTris(ig,:);         % 아슬아슬 통과(최대변 최대)
    dmaxB = max(dBad,[],2);
    cb = find(dmaxB > maxKm & dmaxB <= 140 & min(dBad,[],2) <= 70, 1);  % 보기 좋은 탈락 예시
    Tb = badTris(cb,:);
    gx = newMap('1a 기선 필터 예시');
    drawTriEdges(gx, lon, lat, Tg, '-',  [0 0.45 0.85], 2.2, sprintf('통과 후보 (모든 변 \\leq %dkm)', maxKm));
    drawTriEdges(gx, lon, lat, Tb, '--', [0.9 0.1 0.1], 2.2, sprintf('탈락 (변 > %dkm)', maxKm));
    labelEdges(gx, lon, lat, Tg, [0 0.3 0.6]);
    labelEdges(gx, lon, lat, Tb, [0.75 0 0]);
    geoplot(gx, lat, lon, 'ks', 'MarkerFaceColor','y', 'MarkerSize',5, 'DisplayName','관측소');
    legend(gx, 'Location','northeast');
    title(gx, sprintf('Step 1. 기선장 제약(d \\leq %d km)에 의한 후보 삼각형 선별 (156,849 → %d)', ...
        maxKm, size(goodTris,1)));
    saveFig(figDir, 'ilp_step1a_edge_filter.png');

    % (1b) 변길이 통과 후보 전체
    gx = newMap('1b 후보 전체');
    segTris(gx, lon, lat, goodTris, [0.45 0.55 0.75], 0.25);
    geoplot(gx, lat, lon, 'ks', 'MarkerFaceColor','y', 'MarkerSize',5, 'DisplayName','관측소');
    legend(gx, 'Location','northeast');
    title(gx, sprintf('Step 1. 후보 삼각형 집합 (n = %d)', size(goodTris,1)));
    saveFig(figDir, 'ilp_step1b_candidates.png');
end

% ========================================================================
%  STEP 2 : 기하 사전계산 — 외접원(inCirc) · 내부점(inTri) · 프루닝
% ========================================================================
function step2_geometry(lon, lat, isBnd, goodTris, keep, inCircList, inTriList, ccU, ccR2, figDir)
    % (2a) 예시 후보: inTri≠∅ 이고 inCirc가 inTri보다 큰 것 (방해점까지 보이게)
    idx = find(keep & cellfun(@numel,inCircList) > cellfun(@numel,inTriList), 1);
    if isempty(idx); idx = find(keep,1); end
    T = goodTris(idx,:); inC = inCircList{idx}; inT = inTriList{idx};
    ux = ccU(idx,1); uy = ccU(idx,2); r = sqrt(ccR2(idx));
    th = linspace(0,2*pi,181);
    gx = newMap('2a 외접원/내부점');
    geoplot(gx, uy + r*sin(th), ux + r*cos(th), '-', 'Color',[0.5 0.3 0.8], ...
        'LineWidth',1.6, 'DisplayName','외접원 (3점으로 유일 결정)');
    drawTriEdges(gx, lon, lat, T, '-', [0 0.45 0.85], 2.2, '후보 삼각형');
    geoplot(gx, lat(T), lon(T), 'ks', 'MarkerFaceColor','y', 'MarkerSize',9, 'DisplayName','꼭짓점 (기준국 요구)');
    geoplot(gx, lat(inT), lon(inT), 'k^', 'MarkerFaceColor','b', 'MarkerSize',9, ...
        'DisplayName','inTri: 내부점 (감시국 후보)');
    only = setdiff(inC, inT);
    if ~isempty(only)
        geoplot(gx, lat(only), lon(only), 'x', 'Color',[0.85 0 0], 'MarkerSize',11, 'LineWidth',2, ...
            'DisplayName','inCirc: 원내 점 (기준국이면 셀 불가)');
    end
    othr = setdiff(1:numel(lon), [T(:); inC(:)]);
    geoplot(gx, lat(othr), lon(othr), 's', 'Color',[0.5 0.5 0.5], 'MarkerSize',4, 'DisplayName','기타 관측소');
    legend(gx, 'Location','northeast');
    zoomTo(gx, lat([T(:); inC(:)]), lon([T(:); inC(:)]), 0.8);
    title(gx, 'Step 2. 외접원 공백 조건의 기하 요소 사전계산 (inCirc, inTri)');
    saveFig(figDir, 'ilp_step2a_circumcircle.png');

    % (2b) 프루닝 후 최종 후보
    gx = newMap('2b 최종 후보');
    segTris(gx, lon, lat, goodTris(keep,:), [0.85 0.45 0.25], 0.3);
    geoplot(gx, lat, lon, 'ks', 'MarkerFaceColor','y', 'MarkerSize',5, 'DisplayName','관측소');
    geoplot(gx, lat(isBnd), lon(isBnd), 'ks', 'MarkerFaceColor',[1 .55 0], 'MarkerSize',7, 'DisplayName','최외곽(고정)');
    legend(gx, 'Location','northeast');
    title(gx, sprintf('Step 2. 후보 축소 결과 — 결정변수 present_T (n = %d)', sum(keep)));
    saveFig(figDir, 'ilp_step2b_pruned.png');
end

% ========================================================================
%  STEP 3 : MILP 제약 — Pack/Clique(겹침 금지) · Forcing(100km 강제)
% ========================================================================
function step3_constraints(lon, lat, goodTris, keep, inTriList, badTris, dBad, maxKm, grandPairs, figDir)
    % (3a) Pack: 한 관측소를 품는 후보들 → 최대 1개만 present
    kIdx = find(keep);
    cnt = zeros(numel(lon),1);
    for t = kIdx'
        cnt(inTriList{t}) = cnt(inTriList{t}) + 1;
    end
    [nc, p] = max(cnt);
    tp = kIdx(cellfun(@(v) any(v==p), inTriList(kIdx)));
    gx = newMap('3a Pack/Clique');
    segTris(gx, lon, lat, goodTris(tp,:), [0.85 0.45 0.25], 0.7);
    geoplot(gx, lat, lon, 'ks', 'MarkerFaceColor','y', 'MarkerSize',5, 'DisplayName','관측소');
    geoplot(gx, lat(p), lon(p), 'k^', 'MarkerFaceColor','b', 'MarkerSize',11, ...
        'DisplayName',sprintf('관측소 p (%d개 후보가 품음)', nc));
    legend(gx, 'Location','northeast');
    vv = unique(goodTris(tp,:));
    zoomTo(gx, lat(vv), lon(vv), 0.5);
    title(gx, sprintf('Step 3. 중첩 배제 제약 \\Sigma_{T\\ni p} present_T \\leq 1 (해당 후보 %d개)', nc));
    saveFig(figDir, 'ilp_step3a_packing.png');

    % (3b) Forcing: >100km 변 가진 삼각형은 Delaunay 셀이 될 수 없음
    dmaxB = max(dBad,[],2);
    cb = find(dmaxB > maxKm & dmaxB <= 140 & min(dBad,[],2) <= 70, 1);
    T = badTris(cb,:); d = dBad(cb,:);
    pairs = [T([1 2]); T([1 3]); T([2 3])];
    gx = newMap('3b Forcing');
    for e = 1:3
        pr = pairs(e,:); bad = d(e) > maxKm && ~ismember(sort(pr), grandPairs, 'rows');
        if bad
            geoplot(gx, lat(pr), lon(pr), '--', 'Color',[0.9 0.1 0.1], 'LineWidth',2.4, ...
                'DisplayName',sprintf('금지 변 %.0f km > %d km', d(e), maxKm));
            text(gx, mean(lat(pr))+0.1, mean(lon(pr))+0.1, sprintf('%.0f km', d(e)), ...
                'Color',[0.85 0 0], 'FontWeight','bold');
        else
            geoplot(gx, lat(pr), lon(pr), '-', 'Color',[0 0.45 0.85], 'LineWidth',1.8, 'HandleVisibility','off');
        end
    end
    geoplot(gx, lat, lon, 'ks', 'MarkerFaceColor','y', 'MarkerSize',5, 'DisplayName','관측소');
    geoplot(gx, lat(T), lon(T), 'ks', 'MarkerFaceColor',[1 .8 0], 'MarkerSize',9, 'HandleVisibility','off');
    legend(gx, 'Location','northeast');
    title(gx, {'Step 3. 기선장 강제 제약 — 초과 기선 삼각형의 셀 형성 배제', ...
        'x_a+x_b+x_c - \Sigma_{p\in inCirc} x_p \leq 2'});
    saveFig(figDir, 'ilp_step3b_forcing.png');
end

% ========================================================================
%  STEP 4 : LP 완화 → 상한 (dual bound)
% ========================================================================
function step4_lp_bound(R, figDir)
    lpB  = R.info.lpBound_km2;
    ilpO = R.info.ilpObj_km2;
    act  = R.area_km2;
    figure('Color','w','Position',[80 80 960 720]);
    vals = [lpB, ilpO, act];
    b = bar(categorical({'LP 완화 상한','ILP 목적값','실제 면적(WGS84)'}, ...
            {'LP 완화 상한','ILP 목적값','실제 면적(WGS84)'}), vals, 0.55);
    b.FaceColor = 'flat'; b.CData = [0.6 0.6 0.6; 0.85 0.33 0.10; 0.2 0.5 0.9];
    grid on; ylabel('감시가능 면적 (km^2)');
    text(1:3, vals, compose('%.0f', vals), 'HorizontalAlignment','center', ...
        'VerticalAlignment','bottom', 'FontWeight','bold');
    title({'Step 4. LP 완화에 의한 상한 (dual bound)', ...
        sprintf('정수최적 \\leq %.0f km^2,  달성률 %.1f%%', lpB, 100*ilpO/lpB)});
    saveFig(figDir, 'ilp_step4_lp_bound.png');
end

% ========================================================================
%  STEP 5 : 분기한정 (개념도)
% ========================================================================
function step5_branch_bound(R, figDir)
    lpB = R.info.lpBound_km2; best = R.area_km2;
    figure('Color','w','Position',[80 80 960 720]);
    ax = axes('Position',[0 0 1 1]); hold(ax,'on'); xlim([0 1]); ylim([0 1]); axis off;
    BL = [0.27 0.45 0.77];
    nodeBox(ax, 0.5, 0.87, 0.46, 0.10, {sprintf('LP 완화: 상한 %.0f', lpB), 'x_{37} = 0.6 (분수) \rightarrow 분기'}, BL);
    plot(ax,[0.5 0.28],[0.82 0.66],'-','Color',BL,'LineWidth',1.3);
    plot(ax,[0.5 0.72],[0.82 0.66],'-','Color',BL,'LineWidth',1.3);
    text(ax,0.33,0.75,'x_{37}=0 (감시국)','FontSize',10,'HorizontalAlignment','right');
    text(ax,0.67,0.75,'x_{37}=1 (기준국)','FontSize',10,'HorizontalAlignment','left');
    nodeBox(ax, 0.28, 0.60, 0.34, 0.09, {sprintf('LP 상한 %.0f', best*1.02), '분수 남음 \rightarrow 계속 분기'}, BL);
    nodeBox(ax, 0.72, 0.60, 0.34, 0.09, {sprintf('LP 상한 %.0f', best*0.99), ''}, BL);
    text(ax, 0.72, 0.505, sprintf('상한 < 현재 최선 %.0f', best), 'HorizontalAlignment','center', ...
        'Color',[0.85 0 0], 'FontSize',10, 'FontWeight','bold');
    text(ax, 0.72, 0.465, '\times 가지치기 (통째로 버림)', 'HorizontalAlignment','center', ...
        'Color',[0.85 0 0], 'FontSize',11, 'FontWeight','bold');
    plot(ax,[0.28 0.18],[0.55 0.40],'-','Color',BL,'LineWidth',1.3);
    plot(ax,[0.28 0.40],[0.55 0.40],'-','Color',BL,'LineWidth',1.3);
    text(ax,0.18,0.36,'...','FontSize',14,'HorizontalAlignment','center');
    nodeBox(ax, 0.44, 0.33, 0.34, 0.10, {'\bf정수해 (잎)', sprintf('%.0f km^2  \\leftarrow 현재 최선', best)}, [0.1 0.55 0.25]);
    text(ax, 0.5, 0.14, {'모든 가지가 잘리거나 탐색되면: 최선 정수해 = 전역최적 (증명 완료)', ...
        '시간초과 시: 그때까지의 최선 정수해 반환 (본 결과)'}, ...
        'HorizontalAlignment','center', 'FontSize',10.5);
    title(ax, 'Step 5. 분기한정법 — 분기와 상한 기반 가지치기 (개념도)', ...
        'FontSize',12, 'FontWeight','bold');
    saveFig(figDir, 'ilp_step5_branch_bound.png');
end

% ========================================================================
%  STEP 6 : 실제 들로네 재검증 (100km 전수 검사)
% ========================================================================
function step6_recheck(R, grandPairs, figDir)
    lon = R.lon; lat = R.lat; isRef = R.isRef; maxKm = R.maxBaseKm;
    Ridx = find(isRef); lonR = lon(Ridx); latR = lat(Ridx);
    DT = delaunayTriangulation(lonR, latR); E = edges(DT);
    lenKm = deg2km(distance(latR(E(:,1)),lonR(E(:,1)),latR(E(:,2)),lonR(E(:,2))));
    isGrand = ismember(sort(Ridx(E),2), grandPairs, 'rows');
    viol = lenKm > maxKm & ~isGrand;
    gx = newMap('6 재검증');
    segPairs(gx, lonR, latR, E(~isGrand & ~viol,:), '-',  [0.35 0.35 0.35], 0.7, sprintf('기선 \\leq %d km (%d개)', maxKm, sum(~isGrand & ~viol)));
    segPairs(gx, lonR, latR, E(isGrand,:),          '--', [1 .55 0],        1.3, sprintf('초기 초과 면제 (%d개)', sum(isGrand)));
    if any(viol)
        segPairs(gx, lonR, latR, E(viol,:), '--', [0.9 0.1 0.1], 2.4, sprintf('위반! (%d개) \\rightarrow no-good', sum(viol)));
    end
    geoplot(gx, latR, lonR, 'ks', 'MarkerFaceColor','y', 'MarkerSize',6, 'DisplayName','기준국');
    geoplot(gx, lat(~isRef), lon(~isRef), 'k^', 'MarkerFaceColor','b', 'MarkerSize',5, 'DisplayName','감시국');
    legend(gx, 'Location','northeast');
    if any(viol); vs = '제약 위반 — no-good 컷 적용'; else; vs = '제약 충족'; end
    title(gx, sprintf('Step 6. 들로네 재검증 — 최대 신규 기선 %.1f km (%s)', max(lenKm(~isGrand)), vs));
    saveFig(figDir, 'ilp_step6_recheck.png');
end

% ========================================================================
%  STEP 7 : 최적 망 확정
% ========================================================================
function step7_final(R, figDir)
    lon = R.lon; lat = R.lat; isRef = R.isRef;
    Ridx = find(isRef); lonR = lon(Ridx); latR = lat(Ridx);
    lonM = lon(~isRef); latM = lat(~isRef);
    DT = delaunayTriangulation(lonR, latR); CL = DT.ConnectivityList;
    ti = pointLocation(DT, lonM, latM); ti = ti(~isnan(ti)); red = unique(ti);
    gx = newMap('7 최종 결과');
    for i = 1:numel(red)
        n = CL(red(i),:);
        geoplot(gx, geopolyshape([latR(n);latR(n(1))],[lonR(n);lonR(n(1))]), ...
            'EdgeColor','k','LineWidth',0.5,'FaceColor','r','FaceAlpha',0.3,'HandleVisibility','off');
    end
    segPairs(gx, lonR, latR, edges(DT), '-', [0.45 0.45 0.45], 0.5, '');
    geoplot(gx, latR, lonR, 'ks', 'MarkerFaceColor','y', 'MarkerSize',6, 'DisplayName','기준국');
    geoplot(gx, latM, lonM, 'k^', 'MarkerFaceColor','b', 'MarkerSize',5, 'DisplayName','감시국');
    legend(gx, 'Location','northeast');
    title(gx, sprintf('Step 7. 최적 감시망 구성 — 기준국 %d, 감시국 %d, 감시가능 면적 %.0f km^2', ...
        R.nRef, R.nMon, R.area_km2));
    saveFig(figDir, 'ilp_step7_final.png');
end

% ========================================================================
%  공통 헬퍼
% ========================================================================
function gx = newMap(name)
    figure('Name',name,'Color','w','Position',[80 80 960 720]);
    gx = geoaxes; hold(gx,'on');
    try, geobasemap(gx,'topographic'); catch, end
    geolimits(gx, [33 39], [125 131]);
end

function saveFig(figDir, fname)
    drawnow;
    print(gcf, fullfile(figDir,fname), '-dpng', '-r200');   % 캔버스 그대로 → 픽셀 크기 통일
    fprintf('  저장: %s\n', fname);
end

function zoomTo(gx, latV, lonV, pad)
    geolimits(gx, [min(latV)-pad, max(latV)+pad], [min(lonV)-pad*1.2, max(lonV)+pad*1.2]);
end

function segTris(gx, lon, lat, T, col, lw)
%  다수 삼각형의 변을 한 번에 렌더 (NaN 구분자 배치)
    P = [T(:,[1 2]); T(:,[1 3]); T(:,[2 3])];
    la = [lat(P(:,1)), lat(P(:,2)), NaN(size(P,1),1)]';
    lo = [lon(P(:,1)), lon(P(:,2)), NaN(size(P,1),1)]';
    geoplot(gx, la(:), lo(:), '-', 'Color', col, 'LineWidth', lw, 'HandleVisibility','off');
end

function segPairs(gx, lonV, latV, E, spec, col, lw, name)
    if isempty(E); return; end
    la = [latV(E(:,1)), latV(E(:,2)), NaN(size(E,1),1)]';
    lo = [lonV(E(:,1)), lonV(E(:,2)), NaN(size(E,1),1)]';
    h = geoplot(gx, la(:), lo(:), spec, 'Color', col, 'LineWidth', lw);
    if isempty(name); h.HandleVisibility = 'off'; else; h.DisplayName = name; end
end

function drawTriEdges(gx, lon, lat, T, spec, col, lw, name)
    la = [lat(T([1 2 3 1]))];  lo = [lon(T([1 2 3 1]))];
    geoplot(gx, la, lo, spec, 'Color', col, 'LineWidth', lw, 'DisplayName', name);
end

function labelEdges(gx, lon, lat, T, col)
    prs = [T([1 2]); T([1 3]); T([2 3])];
    for e = 1:3
        pr = prs(e,:);
        d = deg2km(distance(lat(pr(1)),lon(pr(1)),lat(pr(2)),lon(pr(2))));
        text(gx, mean(lat(pr)), mean(lon(pr)), sprintf(' %.0fkm', d), ...
            'Color', col, 'FontSize',9, 'FontWeight','bold');
    end
end

function nodeBox(ax, cx, cy, w, h, lines, col)
    rectangle(ax, 'Position',[cx-w/2, cy-h/2, w, h], 'EdgeColor',col, 'LineWidth',1.5, 'FaceColor','w');
    text(ax, cx, cy+0.016, lines{1}, 'HorizontalAlignment','center', 'FontSize',10.5, 'FontWeight','bold');
    text(ax, cx, cy-0.018, lines{2}, 'HorizontalAlignment','center', 'FontSize',9.5, 'Color',[0.25 0.25 0.25]);
end

function [ok,ux,uy,r2] = circum(ax,ay,bx,by,cx,cy)
    d = 2*(ax*(by-cy)+bx*(cy-ay)+cx*(ay-by));
    if abs(d) < 1e-12; ok=false; ux=0; uy=0; r2=0; return; end
    a2=ax^2+ay^2; b2=bx^2+by^2; c2=cx^2+cy^2;
    ux = (a2*(by-cy)+b2*(cy-ay)+c2*(ay-by))/d;
    uy = (a2*(cx-bx)+b2*(ax-cx)+c2*(bx-ax))/d;
    r2 = (ax-ux)^2+(ay-uy)^2; ok = true;
end

function idx = pointsInTri(X,Y,a,b,c,tol)
    x1=X(a);y1=Y(a);x2=X(b);y2=Y(b);x3=X(c);y3=Y(c);
    d = (y2-y3).*(x1-x3) + (x3-x2).*(y1-y3);
    l1 = ((y2-y3).*(X-x3) + (x3-x2).*(Y-y3))/d;
    l2 = ((y3-y1).*(X-x3) + (x1-x3).*(Y-y3))/d;
    l3 = 1 - l1 - l2;
    idx = find(l1>tol & l2>tol & l3>tol);
end
