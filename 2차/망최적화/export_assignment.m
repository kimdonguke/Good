%% ILP 최적화 망 → 실무 반영용 관측소 배정표 (CSV)
%  저장된 결과(result_ilp.mat)를 로드해 각 관측소의 역할(기준국/감시국)을 표로 출력.
%  "실제로 반영" = 어느 국을 감시국으로 전환할지의 확정 목록.
close all; clear; clc;

% ---- 프로젝트 경로 자동 설정 ----
thisDir = fileparts(mfilename('fullpath'));
if isempty(thisDir); thisDir = pwd; end
projectRoot = thisDir;
while ~isfolder(fullfile(projectRoot, 'Src'))
    parentDir = fileparts(projectRoot);
    if isempty(parentDir) || strcmp(parentDir, projectRoot); projectRoot = thisDir; break; end
    projectRoot = parentDir;
end
% ---------------------------------

%% 결과 로드 (← 'result_greedy.mat' 로 바꾸면 그리디 배정표)
resultFile = fullfile(thisDir, 'result_ilp.mat');
if ~isfile(resultFile)
    error(['결과 파일이 없습니다:\n  %s\n먼저 run_ilp_area_max.m 을 실행하세요.'], resultFile);
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

%% 배정표 저장 (역할→이름 순 정렬)
T = table(names, role, R.lat(:), R.lon(:), ...
    'VariableNames', {'RINEX','role','lat','lon'});
T = sortrows(T, {'role','RINEX'});
outCsv = fullfile(thisDir, sprintf('assignment_%s.csv', R.method));
writetable(T, outCsv);

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
