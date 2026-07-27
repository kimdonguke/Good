function outFile = export_station_list(resultFile)
% EXPORT_STATION_LIST  최적화 결과 → 기준국/감시국 명단 xlsx (최종 실무 산출물)
%   export_station_list()            : result_ilp.mat 기준 (기본)
%   export_station_list(resultFile)  : 지정 결과 파일 기준 (예: result_greedy.mat)
%
%   출력 파일 : <maxBaseKm>_station_list.xlsx  (예: 100_station_list.xlsx) — 망최적화 폴더
%   시트 구성 : '기준국' / '감시국'  (NGII 위성기준점만 대상)
%   열        : code (RINEX 4문자) / name (한글 지점명)  — code 오름차순

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

% 한글 지점명은 결과 파일에 없으므로 원본 속성 테이블에서 조인
[~, ~, ~, Tst] = load_stations();
[tf, loc] = ismember(string(R.names(:)), string(Tst.RINEX));
if ~all(tf)
    error('관측소 속성에서 찾지 못한 코드: %s', strjoin(cellstr(R.names(~tf)), ', '));
end

code  = string(R.names(:));
name  = string(Tst.Name(loc));
isRef = logical(R.isRef(:));

Tref = sortrows(table(code(isRef),  name(isRef),  'VariableNames', {'code','name'}), 'code');
Tmon = sortrows(table(code(~isRef), name(~isRef), 'VariableNames', {'code','name'}), 'code');

outFile = fullfile(thisDir, sprintf('%g_station_list.xlsx', R.maxBaseKm));
if isfile(outFile); delete(outFile); end   % 이전 실행의 잔존 시트 방지
writetable(Tref, outFile, 'Sheet', '기준국');
writetable(Tmon, outFile, 'Sheet', '감시국');

fprintf('[명단 저장] %s  (기준국 %d / 감시국 %d)\n', outFile, height(Tref), height(Tmon));
end
