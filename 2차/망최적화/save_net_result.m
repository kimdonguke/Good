function R = save_net_result(outFile, method, lon, lat, isRef, maxBaseKm, boundarySpec, info, names, monOK)
% SAVE_NET_RESULT  망 최적화 결과를 표준 struct R 로 .mat 저장.
%   R = save_net_result(outFile, method, lon, lat, isRef, maxBaseKm, boundarySpec, info, names, monOK)
%   플롯/통계/배포가 이 파일만 로드하면 되도록 좌표+분할+식별자+요약을 모두 담는다.
%   names: 관측소 식별자(RINEX 등) N×1 (실무 배포표용). 생략 시 인덱스 라벨.
%   monOK(선택): 감시 인정 마스크 (QC 규칙) — 면적/유효셀 산정과 R.monOK 저장에 사용.
    if nargin < 8 || isempty(info);  info = struct(); end
    lon = lon(:); lat = lat(:); isRef = logical(isRef(:));
    if nargin < 9 || isempty(names); names = "S" + string((1:numel(lon))'); end
    if nargin < 10 || isempty(monOK); monOK = true(numel(lon),1); end
    names = string(names(:)); monOK = logical(monOK(:));
    [area_km2, nValidCells] = valid_net_wgs84(lon, lat, isRef, monOK);
    R = struct('method', method, 'lon', lon, 'lat', lat, 'isRef', isRef, 'names', names, ...
               'maxBaseKm', maxBaseKm, 'boundarySpec', boundarySpec(:), ...
               'nRef', sum(isRef), 'nMon', sum(~isRef), 'monOK', monOK, ...
               'area_km2', area_km2, 'nValidCells', nValidCells, ...
               'info', info, 'created', datestr(now));
    save(outFile, 'R');
    fprintf('[결과 저장] %-6s → %s  (기준국 %d, 감시국 %d, %.0f km^2)\n', ...
            method, outFile, R.nRef, R.nMon, R.area_km2);
end
