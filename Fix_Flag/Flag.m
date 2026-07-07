clear; clc;

% ---- 프로젝트 경로 자동 설정 (절대경로 → 상대경로: 어느 PC에서든 동작) ----
thisDir = fileparts(mfilename('fullpath'));
if isempty(thisDir); thisDir = pwd; end
projectRoot = thisDir;
while ~isfolder(fullfile(projectRoot, 'Src'))
    parentDir = fileparts(projectRoot);
    if isempty(parentDir) || strcmp(parentDir, projectRoot); projectRoot = thisDir; break; end
    projectRoot = parentDir;
end
ngiiPaths = {thisDir, projectRoot, fullfile(projectRoot,'Src'), ...
    fullfile(projectRoot,'Src','Reference Code'), ...
    fullfile(projectRoot,'Data','rts'), fullfile(projectRoot,'dd')};
for pIdx = 1:numel(ngiiPaths)
    if isfolder(ngiiPaths{pIdx}); addpath(ngiiPaths{pIdx}); end
end
% -------------------------------------------------------------------------

dbf = readtable('dbf 정리파일.xlsx');
% dbf(:,1:3) = [];
for i=1:height(dbf)
    Pointname(i,1) = {cell2mat([dbf.x__(i),'-',dbf.x___(i),'-',dbf.x______(i)])};
end
dbf(:,6:8) = [];
T_new = readtable("T_new.xlsx");
T_new(:,9:end) = [];

Pointname = [Pointname; T_new.Pointname];

dbf.Properties.VariableNames = {'Point','Haccuracy','Vaccuracy',...
    'Lat','Lon','Epoch','Satellites','El'};
dbf.Epoch = str2double(dbf.Epoch);
dbf.Satellites = str2double(dbf.Satellites);
dbf.El = str2double(dbf.El);
dbf.Haccuracy = str2double(dbf.Haccuracy);
dbf.Vaccuracy = str2double(dbf.Vaccuracy);


T_new.Properties.VariableNames = {'Point','Haccuracy','Vaccuracy',...
    'Lat','Lon','Epoch','Satellites','El'};

Data = [dbf; T_new];

find(contains(Data.Point,'U장성08'))