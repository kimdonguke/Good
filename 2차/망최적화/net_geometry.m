function G = net_geometry(refLon, refLat, qLon, qLat)
% NET_GEOMETRY  망 기하 예측변수 계산 (오차 모델 독립 공통층)
%   거리 기반 오차 모델 error = f(기하량) 가 소비할 값들을 질의점별로 산출한다.
%   거리는 기존 파이프라인과 동일하게 WGS84 대원거리 (distance + deg2km).
%
%   입력:  refLon, refLat  기준국 좌표 [십진도]
%          qLon,   qLat    질의점 좌표 [십진도]
%   출력 G (struct):
%     .nearestKm  질의점별 최근접 기준국 거리 [km]
%     .inTri      기준국 델로네 망 내부 여부 (logical)
%     .triIdx     소속 삼각형 인덱스 (외부 NaN)
%     .triMeanKm  소속 삼각형 3변 평균 기선장 [km] (외부 NaN)
%     .triMaxKm   소속 삼각형 최장 기선장 [km] (외부 NaN)
%     .DT         delaunayTriangulation(기준국)
%     .edgeKm     망 전체 델로네 간선 길이 [km]

    refLon = refLon(:); refLat = refLat(:);
    qLon = qLon(:);     qLat = qLat(:);
    nQ = numel(qLon);   nR = numel(refLon);

    % 최근접 기준국 거리
    dKm = zeros(nQ, nR);
    for j = 1:nR
        dKm(:,j) = deg2km(distance(qLat, qLon, refLat(j), refLon(j)));
    end
    G.nearestKm = min(dKm, [], 2);

    % 델로네 망 + 간선 길이
    G.DT = delaunayTriangulation(refLon, refLat);
    E = edges(G.DT);
    G.edgeKm = deg2km(distance(refLat(E(:,1)), refLon(E(:,1)), ...
                               refLat(E(:,2)), refLon(E(:,2))));

    % 삼각형별 3변 기선장
    CL = G.DT.ConnectivityList;
    triEdgeKm = zeros(size(CL,1), 3);
    for e = 1:3
        a = CL(:,e); b = CL(:,mod(e,3)+1);
        triEdgeKm(:,e) = deg2km(distance(refLat(a), refLon(a), refLat(b), refLon(b)));
    end

    % 질의점 소속 삼각형과 그 기선장
    ti = pointLocation(G.DT, qLon, qLat);
    G.inTri  = ~isnan(ti);
    G.triIdx = ti;
    G.triMeanKm = nan(nQ,1);
    G.triMaxKm  = nan(nQ,1);
    ok = G.inTri;
    G.triMeanKm(ok) = mean(triEdgeKm(ti(ok),:), 2);
    G.triMaxKm(ok)  = max(triEdgeKm(ti(ok),:), [], 2);
end
