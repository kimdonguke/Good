function S = net_stats(lon, lat, isRef, maxBaseKm, monOK)
% NET_STATS  기준국 배치의 망 통계 (기선장/커버리지/셀면적/감시국 분포)
%   S = net_stats(lon, lat, isRef, maxBaseKm, monOK)
%   isRef: true=기준국(꼭짓점), false=감시국. maxBaseKm: 기선 상한(임계선 표시용).
%   monOK(선택): 감시 인정 마스크(QC 규칙) — 유효셀/셀당 감시국 산정에만 사용.
    if nargin<4 || isempty(maxBaseKm); maxBaseKm = 100; end
    lon=lon(:); lat=lat(:);
    if nargin<5 || isempty(monOK); monOK = true(numel(lon),1); end
    monOK = logical(monOK(:));
    R = find(isRef); M = find(~isRef(:) & monOK);
    lonR=lon(R); latR=lat(R); lonM=lon(M); latM=lat(M);
    lat0=mean(lat); kx=111.320*cosd(lat0); ky=110.574;   % 면적용 등거리 투영

    S.nInit=numel(lon); S.nRef=numel(R); S.nMon=sum(~isRef(:)); S.nMonOK=numel(M);

    DT = delaunayTriangulation(lonR,latR); CL = DT.ConnectivityList;
    S.DT=DT; S.CL=CL; S.lonR=lonR; S.latR=latR; S.lonM=lonM; S.latM=latM;

    % --- 초기(전체망) 100km 초과 기선쌍 = grandfather 집합 (도서 연결 등) ---
    DT0 = delaunayTriangulation(lon,lat); E0 = edges(DT0);
    len0 = deg2km(distance(lat(E0(:,1)),lon(E0(:,1)),lat(E0(:,2)),lon(E0(:,2))));
    grandPairs = sort(E0(len0>maxBaseKm,:),2);
    S.grandPairs = grandPairs;

    % --- 기선장 (현재망 Delaunay edges) ---
    R = find(isRef);   % (로컬 인덱스 → 원본 인덱스 매핑용; 위에서 이미 정의됨)
    E = edges(DT);
    bl = deg2km(distance(latR(E(:,1)),lonR(E(:,1)),latR(E(:,2)),lonR(E(:,2))));
    origPairs = sort(R(E),2);                            % 로컬 → 원본 인덱스
    isGrand = ismember(origPairs, grandPairs, 'rows');   % 초기부터 100km 초과였던 엣지
    blx = bl(~isGrand);                                  % 초기 초과 제외

    S.baselines=bl; S.isGrand=isGrand; S.baselines_ex=blx;
    S.bl_n=numel(bl); S.bl_nGrand=sum(isGrand); S.bl_nEx=numel(blx);
    % 전체
    S.bl_min=min(bl); S.bl_max=max(bl); S.bl_mean=mean(bl); S.bl_med=median(bl); S.bl_std=std(bl);
    S.bl_over=sum(bl>maxBaseKm);
    % 초기 초과 제외
    if isempty(blx)
        S.blx_mean=NaN; S.blx_med=NaN; S.blx_max=NaN; S.blx_std=NaN;
    else
        S.blx_mean=mean(blx); S.blx_med=median(blx); S.blx_max=max(blx); S.blx_std=std(blx);
    end

    % --- 유효셀 (감시국 포함) ---
    if ~isempty(M)
        ti = pointLocation(DT, lonM, latM); ti = ti(~isnan(ti));
    else
        ti = [];
    end
    cells = unique(ti);
    S.validCells=cells; S.nValidCells=numel(cells); S.nTotalCells=size(CL,1);
    S.redFlag = false(size(CL,1),1); S.redFlag(cells)=true;

    % 셀 면적(WGS84 타원체 — valid_net_wgs84 와 동일 산식, 공식 보고 수치와 정합)
    ca = zeros(numel(cells),1);
    for ci = 1:numel(cells)
        nd = fliplr(CL(cells(ci),:));
        ca(ci) = area(geopolyshape([latR(nd); latR(nd(1))], [lonR(nd); lonR(nd(1))]))/1e6;
    end
    S.cellAreas=ca; S.coverage_km2=sum(ca);
    if isempty(ca); S.cell_mean=0;S.cell_med=0;S.cell_min=0;S.cell_max=0;
    else; S.cell_mean=mean(ca); S.cell_med=median(ca); S.cell_min=min(ca); S.cell_max=max(ca); end

    % 셀당 감시국 수(중복도)
    if isempty(cells); S.monPerCell=[];
    else; S.monPerCell = arrayfun(@(c) sum(ti==c), cells); end

    % --- 커버리지 비율 ---
    if numel(R)>=3
        kk = convhull(lonR,latR);
        S.hullArea_km2 = polyarea(lonR(kk)*kx, latR(kk)*ky);
    else
        S.hullArea_km2 = NaN;
    end
    S.KOREA_km2 = 100363;                     % 대한민국 육지 면적(참고)
    S.cover_vs_hull = 100*S.coverage_km2/S.hullArea_km2;
    S.cover_vs_korea = 100*S.coverage_km2/S.KOREA_km2;
end

