clear; clc; close all;

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

MS = readtable('Main_Station.xlsx');

Point_lla = [MS.Point_Lat, MS.Point_Lon, MS.Point_h];
Station_lla = [MS.Station_Lat, MS.Station_Lon, MS.Station_h];
Point_ENU = zeros(height(Point_lla),4);
ENU_error = [MS.East_Error, MS.North_Error, MS.Up_Error];
horz_error = zeros(150,1);

for i=1:height(Point_lla)
    Point_ENU(i,1:3) = lla2enu(Point_lla(i,1:3),Station_lla(i,1:3),'ellipsoid'); % 주기준국으로부터 ENU 계산
    Point_ENU(i,4) = norm(Point_ENU(i,:)); % ENU 거리 계산
    horz_error(i,1) = norm(ENU_error(i,1:2)); % 수평 오차 계산
end

% 수직 오차 계산 
vert_error = ENU_error(:,3); 

% 거리 오름차순 정렬 및 idx
[unique_dist, ia] = unique(Point_ENU(:,4)); 

% 거리에 따른 오차 순서 정렬
East_Error = MS.East_Error(ia);
North_Error = MS.North_Error(ia);
Up_Error = MS.Up_Error(ia);

Horizontal_Error = horz_error(ia);
Vertical_Error = vert_error(ia);

Total_Error = sqrt(East_Error.^2 + North_Error.^2 + Up_Error.^2); 

MS_revised = MS(ia,:);

%% Error_Distance Plot
% figure;
% axs(1) = subplot(3,1,1);
% plot(unique_dist,East_Error,'r-','LineWidth',1.2);
% hold on;
% plot([min(unique_dist) max(unique_dist)],[0.1 0.1],'k--');
% plot([min(unique_dist) max(unique_dist)],[-0.1 -0.1],'k--');
% xlim([min(unique_dist) max(unique_dist)]);
% ylim([min(MS.East_Error) max(MS.East_Error)]);
% title('East Error');
% 
% axs(2) = subplot(3,1,2);
% plot(unique_dist,North_Error,'g-','LineWidth',1.2);
% hold on;
% plot([min(unique_dist) max(unique_dist)],[0.1 0.1],'k--');
% plot([min(unique_dist) max(unique_dist)],[-0.1 -0.1],'k--');
% xlim([min(unique_dist) max(unique_dist)]);
% ylim([min(MS.North_Error) max(MS.North_Error)]);
% title('North Error');
% 
% axs(3) = subplot(3,1,3);
% plot(unique_dist, Up_Error,'b-','LineWidth',1.2);
% hold on;
% plot([min(unique_dist) max(unique_dist)],[0.2 0.2],'k--');
% plot([min(unique_dist) max(unique_dist)],[-0.2 -0.2],'k--');
% xlim([min(unique_dist) max(unique_dist)]);
% ylim([min(MS.Up_Error) max(MS.Up_Error)]);
% title('Up Error');
% 
% linkaxes(axs, 'x');
% 
% figure;
% ax(1) = subplot(2,1,1);
% plot(unique_dist, Horizontal_Error,'r-','LineWidth',1.5);
% xlabel('Station to Point Distance [m]');
% ylabel('Horizontal Error [m]');
% 
% ax(2) = subplot(2,1,2);
% plot(unique_dist, Up_Error,'b-','LineWidth',1.5);
% xlabel('Station to Point Distance [m]');
% ylabel('Vertical Error [m]');
% linkaxes(ax,'x');
% linkaxes(ax,'y');
% 
% figure;
% plot(unique_dist, Total_Error,'b-','LineWidth',1.5);
% xlabel('Station to Point Distance [m]');
% ylabel('Error Distance [m]');
% % 
% figure;
% axs(1) = subplot(3,1,1);
% plot(unique_dist,abs(East_Error),'r-','LineWidth',1.2);
% hold on;
% plot([min(unique_dist) max(unique_dist)],[0.1 0.1],'k--');
% xlim([min(unique_dist) max(unique_dist)]);
% ylim([0 max(abs(MS.East_Error))]);
% title('East Error');
% xlabel('Distance [m]');
% ylabel('East [m]')
% 
% axs(2) = subplot(3,1,2);
% plot(unique_dist,abs(North_Error),'g-','LineWidth',1.2);
% hold on;
% plot([min(unique_dist) max(unique_dist)],[0.1 0.1],'k--');
% xlim([min(unique_dist) max(unique_dist)]);
% ylim([0 max(abs(MS.North_Error))]);
% title('North Error');
% xlabel('Distance [m]');
% ylabel('North [m]')
% 
% axs(3) = subplot(3,1,3);
% plot(unique_dist, abs(Up_Error),'b-','LineWidth',1.2);
% hold on;
% plot([min(unique_dist) max(unique_dist)],[0.2 0.2],'k--');
% xlim([min(unique_dist) max(unique_dist)]);
% ylim([0 max(abs(MS.Up_Error))]);
% title('Up Error');
% xlabel('Distance [m]');
% ylabel('Up [m]')
% 
% linkaxes(axs, 'x');

% b = table2cell(MS_revised);
% tmp = b(:,5:7);
% b(:,5) = b(:,8); b(:,6) = b(:,9); b(:,7) = b(:,10);
% for k=1:height(b)
%     b{k,8} = unique_dist(k);
% end
% b(:,9) = tmp(:,1); b(:,10) = tmp(:,2); b(:,11) = tmp(:,3);
% 
% Baseline = cell2table(b,'VariableNames',{'Point_Name','Point_Lat','Point_Lon','Point_H','Station_Lat',...
%     'Station_Lon','Station_H','Distance','East_Error','North_Error','Up_Error'});


