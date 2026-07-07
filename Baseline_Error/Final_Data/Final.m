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

load("Final_result.mat");
load("netRts.mat");

dataCols = {'Lat','Lon','Alt','East','North','Up'};
Total = cell(length(dbf_Table),1);

NewNames = {'Point','Network','Service','Point_Lat','Point_Lon','Point_H',...
    'East_Error','North_Error','Up_Error'};

FKP = table(); 
for i=1:length(dbf_Table)
    Total{i,1} = groupsummary(dbf_Table{i},{'Col1','Col2','Col3'},'mean',dataCols);
    Total{i,1}(:,'GroupCount') = [];
    Total{i,1}.Properties.VariableNames = NewNames;
    if any(strcmpi(Total{i,1}.Service,'FKP-RTCM31'))
        idx = find(strcmpi(Total{i,1}.Service,'FKP-RTCM31'));
        FKP(end+1,:) = Total{i,1}(idx,:);
    end
end


figure;
gx = geoaxes;
geobasemap(gx, 'topographic')
hold(gx, 'on')
geolimits([33 39], [124 132])
title('NGII NRTK Service Performance Analysis (Position Error)')

% --- 4. CORS 네트워크 플롯 (기존과 동일) ---
for k = 1:size(netrts,1)
    pg = geopolyshape(netrts.LAT(k, [1 2 3 1]), netrts.LON(k, [1 2 3 1]));
    geoplot(gx, pg, 'k', 'EdgeColor', 'k', 'HandleVisibility', 'off')
end



% U790 : 50, U고창21 : 76, 
% U연곡07 : 144, U장성08 : 169