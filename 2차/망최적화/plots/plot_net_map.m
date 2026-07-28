function [fig, gx] = plot_net_map(lon, lat, isRef, ttl, figName, monOK)
% PLOT_NET_MAP  최적화 망 표준 지도 (기준국 삼각망 + 유효셀 빨강/무효셀 회색)
%   [fig, gx] = plot_net_map(lon, lat, isRef, ttl, figName, monOK)
%   드라이버(run_greedy / run_ilp / 통합파이프라인) 공용 — 표준 규격:
%   960×720(4:3), legend 지도내 northeast, colorbar 없음, geolimits [33 39]/[125 131].
%   monOK(선택): 감시 인정 마스크(QC 규칙) — 유효셀(빨강) 판정에만 사용,
%   마커는 전 감시국 표시. 생략 시 전 감시국 인정(legacy).

    if nargin < 5 || isempty(figName); figName = ttl; end
    lon = lon(:); lat = lat(:);
    if nargin < 6 || isempty(monOK); monOK = true(numel(lon),1); end
    isRef = logical(isRef(:)); monOK = logical(monOK(:));
    lonR = lon(isRef);  latR = lat(isRef);
    lonM = lon(~isRef); latM = lat(~isRef);

    DT = delaunayTriangulation(lonR, latR);
    CL = DT.ConnectivityList;
    ti = pointLocation(DT, lon(~isRef & monOK), lat(~isRef & monOK)); ti = ti(~isnan(ti));
    red_tri  = unique(ti);
    gray_tri = setdiff((1:size(CL,1))', red_tri);

    fig = figure('Name',figName,'Color','w','Position',[80 80 960 720]);
    gx = geoaxes(fig);
    try
        geobasemap(gx,'topographic');   % 오프라인/헤드리스에서는 기본 축으로 대체
    catch
    end
    hold(gx,'on');

    % 셀 렌더: 색 클래스별 NaN 구분 멀티리전 geopolyshape 1개 (셀별 geoplot 반복 제거)
    plot_cells_batch(gx, latR, lonR, CL(gray_tri,:), ...   % 회색 셀 = 감시국 미포함(무효)
        'k','EdgeColor','k','HandleVisibility','off');
    plot_cells_batch(gx, latR, lonR, CL(red_tri,:), ...    % 빨강 셀 = 감시국 포함(감시가능)
        'EdgeColor','k','LineWidth',0.5,'FaceColor','r','FaceAlpha',0.3,'HandleVisibility','off');
    E = edges(DT);
    lat_e = [latR(E(:,1)), latR(E(:,2)), NaN(size(E,1),1)]';
    lon_e = [lonR(E(:,1)), lonR(E(:,2)), NaN(size(E,1),1)]';
    geoplot(gx, lat_e(:), lon_e(:), 'k-','LineWidth',0.5,'HandleVisibility','off');

    geoplot(gx, latR, lonR, 'ks','MarkerFaceColor','y','MarkerSize',6);
    geoplot(gx, latM, lonM, 'k^','MarkerFaceColor','b','MarkerSize',5);
    % 개수는 legend가 담당 (타이틀 규약: 제목 = 주제·조건만, 산출 통계 제외)
    legend(gx, {sprintf('기준국 (%d개소)', nnz(isRef)), ...
                sprintf('감시국 (%d개소)', nnz(~isRef))}, 'Location','northeast');
    title(gx, ttl);
    geolimits(gx, [33 39], [125 131]);
    hold(gx,'off');
end

% ======================================================================
function h = plot_cells_batch(gx, latR, lonR, CLsub, varargin)
% 삼각형 셀 집합을 geopolyshape 객체 배열 + geoplot 1회로 렌더 (셀별 geoplot 반복 제거)
%   주의: NaN 멀티리전 1개로 합치면 변을 공유한 삼각형들이 even-odd 규칙으로
%   구멍 처리되는 체커보드 아티팩트 발생 — 셀별 독립 shape 배열은 상호작용 없음.
    h = gobjects(0);
    if isempty(CLsub); return; end
    shp = arrayfun(@(i) geopolyshape([latR(CLsub(i,:)); latR(CLsub(i,1))], ...
                                     [lonR(CLsub(i,:)); lonR(CLsub(i,1))]), (1:size(CLsub,1))');
    h = geoplot(gx, shp, varargin{:});
end
