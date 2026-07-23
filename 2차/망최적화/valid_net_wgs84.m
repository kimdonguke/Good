function [area_km2, nCells, DT, red_tri, lonR, latR] = valid_net_wgs84(lon, lat, isRef, monOK)
% VALID_NET_WGS84  최종 배치의 유효셀(감시국 포함 셀) 정확 면적/개수 (WGS84)
%   기존 NRTK_with_CORS.m 과 동일하게 geopolyshape+area, 꼭짓점 fliplr 부호보정.
%   monOK(선택): N×1 감시 인정 마스크 (QC 규칙, qc_rules.m) — 미달 국은 셀 유효
%   판정에 카운트하지 않음. 생략 시 전 감시국 인정(legacy).
    lon = lon(:); lat = lat(:);
    if nargin < 4 || isempty(monOK); monOK = true(numel(lon),1); end
    monOK = logical(monOK(:));
    lonR = lon(isRef);  latR = lat(isRef);
    lonM = lon(~isRef & monOK); latM = lat(~isRef & monOK);
    DT = delaunayTriangulation(lonR, latR);
    CL = DT.ConnectivityList;
    red_tri = zeros(0,1); area_km2 = 0; nCells = 0;
    if isempty(lonM) || isempty(CL); return; end

    ti = pointLocation(DT, lonM, latM);
    ti = ti(~isnan(ti));
    red_tri = unique(ti);
    nCells  = numel(red_tri);
    for i = 1:nCells
        nodes = fliplr(CL(red_tri(i),:));
        pa = [latR(nodes); latR(nodes(1))];
        po = [lonR(nodes); lonR(nodes(1))];
        area_km2 = area_km2 + area(geopolyshape(pa,po))/1e6;
    end
end
