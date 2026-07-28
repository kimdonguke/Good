function [outCsv, T] = export_assignment(resultFile)
% EXPORT_ASSIGNMENT  최적화 망 → 실무 반영용 관측소 배정표 (CSV)
%   export_assignment()            : result_ilp.mat 기준 (기본)
%   export_assignment(resultFile)  : 지정 결과 파일 기준 (예: result_greedy.mat)
%   출력: assignment_<method>.csv (RINEX, role, lat, lon) + 감시국 전환 목록 콘솔 출력.
%   "실제로 반영" = 어느 국을 감시국으로 전환할지의 확정 목록.

% ---- 프로젝트 경로 자동 설정 ----
thisDir = fileparts(mfilename('fullpath'));
if isempty(thisDir); thisDir = pwd; end
% ---------------------------------

if nargin < 1 || isempty(resultFile)
    resultFile = fullfile(thisDir, 'result_ilp.mat');
end
if ~isfile(resultFile)
    error('결과 파일이 없습니다:\n  %s\n먼저 run_ilp_area_max.m 을 실행하세요.', resultFile);
end
Rr = load(resultFile); R = Rr.R;
N = numel(R.lon);

% 역할 배정
role = strings(N,1); role(R.isRef) = "기준국"; role(~R.isRef) = "감시국(전환)";
if isfield(R,'names') && numel(R.names)==N
    names = string(R.names(:));
else
    names = "S" + string((1:N)');   % 이름 없으면 인덱스 라벨
end

% 배정표 저장 (역할→이름 순 정렬)
T = table(names, role, R.lat(:), R.lon(:), ...
    'VariableNames', {'RINEX','role','lat','lon'});
T = sortrows(T, {'role','RINEX'});
outCsv = fullfile(thisDir, sprintf('assignment_%s.csv', R.method));
writetable(T, outCsv);
add_utf8_bom(outCsv);   % BOM 없으면 한국어 Windows Excel이 CP949로 해석해 한글 깨짐

fprintf('\n===== [%s] 관측소 배정표 =====\n', R.method);
fprintf('총 %d개  →  기준국 %d, 감시국(전환) %d\n', N, sum(R.isRef), sum(~R.isRef));
fprintf('배정표 저장: %s\n', outCsv);

% 감시국 전환 대상 목록
mn = sort(names(~R.isRef));
fprintf('\n[감시국으로 전환할 관측소 %d개]\n', numel(mn));
for i = 1:6:numel(mn)
    fprintf('  %s\n', strjoin(cellstr(mn(i:min(i+5,numel(mn))))', ', '));
end
fprintf('============================\n\n');
end

% ======================================================================
function add_utf8_bom(f)
    fid = fopen(f, 'r'); raw = fread(fid, '*uint8'); fclose(fid);
    if numel(raw) >= 3 && isequal(raw(1:3)', uint8([239 187 191])); return; end
    fid = fopen(f, 'w'); fwrite(fid, [uint8([239; 187; 191]); raw]); fclose(fid);
end
