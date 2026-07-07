clear; clc;
% 
% load("result.mat");
% 
% T = readtable('통합 문서1.xlsx');
% T_summary = groupsummary(T,'StationID','mean',{'East_Error','North_Error','Up_Error'});
% ENU_Error = T_summary(:,[1,3:5]);
% ENU_Error = renamevars(ENU_Error,{'mean_East_Error','mean_North_Error','mean_Up_Error'},...
%     {'East_Error','North_Error','Up_Error'});
% 
% for i = 1:height(ENU_Error)
%      idx(i,1) = find(strcmp(ENU_Error.StationID(i),Total_sample(:,1)));
% end
% 
% Station_Point = Total_sample(idx,:);
% Station_Point(:,5) = num2cell(ENU_Error.East_Error(:));
% Station_Point(:,6) = num2cell(ENU_Error.North_Error(:));
% Station_Point(:,7) = num2cell(ENU_Error.Up_Error(:));
% 
% 
% FKP_Hor = Total_hv(:,15);
% FKP_Ver = Total_hv(:,16);
% % FKP = readtable("new_point_error.xlsx");
% FKP_Error = Total_enu(:,22:24);
% 
% FKP = [];
% for i=1:height(Total)
%     idx = strcmpi(Total{i}(:,3),'FKP-RTCM31');
%     if any(idx) 
%         FKP = [FKP; Total{i}(idx,:)];
%     end
% end
% 
% table(FKP,'VariableNames',{'StationID','Service','Network','East_Error','North_Error','Up_Error'});
% T_summary = groupsummary(FKP)









FKP = readtable("New_Data.xlsx");