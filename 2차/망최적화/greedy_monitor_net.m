function [isRef, info] = greedy_monitor_net(lon, lat, maxBaseKm, boundaryShrink, objective)
% GREEDY_MONITOR_NET  기준국->감시국 임무전환 그리디 (감시가능망 최적화 엔진)
%
%   [isRef, info] = greedy_monitor_net(lon, lat, maxBaseKm, boundaryShrink, objective)
%
%   objective : 'area'  -> 감시가능망 "면적" 최대화 (단조, 수확체감)
%               'count' -> 감시가능망 "셀 개수" 최대화 (비단조, 내부 최적)
%
%   유효셀 = R(기준국)의 Delaunay 셀 중 감시국(∈M)을 포함하는 셀.
%   제약: (1) 외곽 노드 보존  (2) 전환 후 새 기선 <= maxBaseKm
%         (단, 초기 전체망 기선쌍 ∈ grandPairs 는 면제/grandfather)
%   매 스텝 한계이득(면적 또는 개수)이 최대인 feasible 노드를 전환, 양(+)이득 없으면 종료.

    if nargin < 3 || isempty(maxBaseKm);      maxBaseKm = 100;    end
    if nargin < 4 || isempty(boundaryShrink); boundaryShrink = 0.5; end
    if nargin < 5 || isempty(objective);      objective = 'area'; end
    isArea = strcmpi(objective, 'area');

    lon = lon(:); lat = lat(:);
    N = numel(lon);

    % --- 1) 외곽(경계) 노드 보존 ---
    %   boundaryShrink 가 스칼라면 boundary()의 shrink factor,
    %   벡터면 명시적 외곽 노드 인덱스로 사용(예: outer_ring(lon,lat,13)).
    if isscalar(boundaryShrink)
        bIdx = boundary(lon, lat, boundaryShrink);
    else
        bIdx = boundaryShrink(:);
    end
    isBoundary = false(N,1);
    isBoundary(bIdx) = true;

    % --- 2) grandfather: 초기 전체망의 초과 기선쌍 ---
    DT0  = delaunayTriangulation(lon, lat);
    E0   = edges(DT0);
    len0 = deg2km(distance(lat(E0(:,1)), lon(E0(:,1)), lat(E0(:,2)), lon(E0(:,2))));
    grandPairs = sort(E0(len0 > maxBaseKm, :), 2);

    % --- 3) 초기 상태 ---
    isRef = true(N,1);
    [~, Va, Nc] = configMetrics(lon, lat, isRef, maxBaseKm, grandPairs);
    cur = pick(isArea, Va, Nc);

    removedOrder = zeros(0,1);
    VareaHist = Va;  NcellHist = Nc;  nRefHist = sum(isRef);

    % --- 4) 그리디 ---
    thr = pick(isArea, 1e-6, 0.5);      % 최소 유효이득 (면적:eps, 개수:>=1)
    while true
        cand = find(isRef & ~isBoundary);
        bestGain = thr; bestX = 0; bestVa = Va; bestNc = Nc;
        for ii = 1:numel(cand)
            x = cand(ii);
            tent = isRef; tent(x) = false;
            [feas, Va_x, Nc_x] = configMetrics(lon, lat, tent, maxBaseKm, grandPairs);
            if ~feas; continue; end
            g = pick(isArea, Va_x, Nc_x) - cur;
            if g > bestGain
                bestGain = g; bestX = x; bestVa = Va_x; bestNc = Nc_x;
            end
        end
        if bestX == 0; break; end

        isRef(bestX) = false;
        Va = bestVa; Nc = bestNc; cur = pick(isArea, Va, Nc);
        removedOrder(end+1,1) = bestX;   %#ok<AGROW>
        VareaHist(end+1,1) = Va;         %#ok<AGROW>
        NcellHist(end+1,1) = Nc;         %#ok<AGROW>
        nRefHist(end+1,1)  = sum(isRef); %#ok<AGROW>
    end

    info = struct('objective', lower(objective), 'removedOrder', removedOrder, ...
                  'Varea_km2', VareaHist, 'Ncells', NcellHist, 'nRefHist', nRefHist, ...
                  'isBoundary', isBoundary, 'grandPairs', grandPairs, 'maxBaseKm', maxBaseKm);
end

% ========================================================================
function v = pick(isArea, a, c)
    if isArea; v = a; else; v = c; end
end

% ========================================================================
function [feasible, Varea, Ncells] = configMetrics(lon, lat, isRef, maxBaseKm, grandPairs)
    R = find(isRef);
    if numel(R) < 3; feasible = false; Varea = 0; Ncells = 0; return; end
    lonR = lon(R); latR = lat(R);
    DT = delaunayTriangulation(lonR, latR);
    if isempty(DT.ConnectivityList); feasible = false; Varea = 0; Ncells = 0; return; end

    % (1) 제약
    E = edges(DT);
    lenKm = deg2km(distance(latR(E(:,1)), lonR(E(:,1)), latR(E(:,2)), lonR(E(:,2))));
    bad = lenKm > maxBaseKm;
    if any(bad)
        badPairs = sort(R(E(bad,:)), 2);
        feasible = all(ismember(badPairs, grandPairs, 'rows'));
    else
        feasible = true;
    end

    % (2) 유효셀: 감시국 포함 셀
    M = find(~isRef);
    if isempty(M); Varea = 0; Ncells = 0; return; end
    triIdx = pointLocation(DT, lon(M), lat(M));
    triIdx = triIdx(~isnan(triIdx));
    cells  = unique(triIdx);
    Ncells = numel(cells);
    if Ncells == 0; Varea = 0; return; end
    Varea = sum(triAreasKm(lonR, latR, DT.ConnectivityList(cells, :)));
end

% ========================================================================
function A = triAreasKm(lonR, latR, CL)
    lat0 = mean(latR);
    kx = 111.320 * cosd(lat0);  ky = 110.574;
    X = lonR * kx;  Y = latR * ky;
    x1 = X(CL(:,1)); y1 = Y(CL(:,1));
    x2 = X(CL(:,2)); y2 = Y(CL(:,2));
    x3 = X(CL(:,3)); y3 = Y(CL(:,3));
    A = 0.5 * abs((x2-x1).*(y3-y1) - (x3-x1).*(y2-y1));
end
