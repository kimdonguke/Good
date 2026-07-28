function [outFile, stations] = export_result_mat(resultFile)
% EXPORT_RESULT_MAT  최적화 결과 → 관측소 정보 테이블 .mat (<maxBaseKm>_result.mat)
%   export_result_mat()            : result_ilp.mat 기준 (기본)
%   export_result_mat(resultFile)  : 지정 결과 파일 기준 (예: result_greedy.mat)
%
%   출력 파일 : <maxBaseKm>_result.mat  (예: 100_result.mat) — 망최적화 폴더에 저장
%   저장 변수 : stations (table, 원본 관측소 순서)
%     code   : 관측소 코드네임 (RINEX, 예 "GSAN")
%     name   : 관측소 한글 지점명 (예 "괴산")
%     isRef  : 기준국 여부 "T"/"F"  (T=기준국 유지, F=감시국 전환)
%     lat    : 위도 (십진도, WGS84)
%     lon    : 경도 (십진도, WGS84)
%     height : 타원체고 (m)
%     proj   : 투영원점 (서부/중부/동부/동해)

% ---- 프로젝트 경로 자동 설정 ----
thisDir = fileparts(mfilename('fullpath'));
if isempty(thisDir); thisDir = pwd; end
addpath(thisDir);   % load_stations 등 동일 폴더 함수 보장
% ---------------------------------

if nargin < 1 || isempty(resultFile)
    resultFile = fullfile(thisDir, 'result_ilp.mat');
end
if ~isfile(resultFile)
    error('결과 파일이 없습니다:\n  %s\n먼저 run_ilp_area_max.m 을 실행하세요.', resultFile);
end
Rr = load(resultFile); R = Rr.R;
N = numel(R.lon);

% 한글 지점명/타원체고/투영원점은 결과 파일에 없으므로 원본 속성 테이블에서 조인
[~, ~, ~, Tst] = load_stations();
[tf, loc] = ismember(string(R.names(:)), string(Tst.RINEX));
if ~all(tf)
    error('관측소 속성(stations_ngii.mat)에서 찾지 못한 코드: %s (stale 결과 파일 가능 — run_ilp_area_max 재실행)', ...
        strjoin(cellstr(R.names(~tf)), ', '));
end

code   = string(R.names(:));
name   = string(Tst.Name(loc));
isRef  = repmat("F", N, 1);  isRef(R.isRef) = "T";
lat    = R.lat(:);
lon    = R.lon(:);
height = Tst.Height(loc);
proj   = string(Tst.Proj(loc));

stations = table(code, name, isRef, lat, lon, height, proj);

outFile = fullfile(thisDir, sprintf('%g_result.mat', R.maxBaseKm));
save(outFile, 'stations');
fprintf('[결과 저장] %-6s → %s  (기준국 %d, 감시국 %d, 총 %d)\n', ...
        R.method, outFile, sum(R.isRef), sum(~R.isRef), N);
end
