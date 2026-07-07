%% Initialize and Setup
close all;
clear;
clc;

% Add necessary path
% addpath('Src');
addpath('Data');
addpath('Data/rts');
% addpath('검증측량 데이터 전체');
addpath(genpath('Src'));
addpath('/Users/park-inkyeong/Desktop/dbf');
addpath('/Users/park-inkyeong/Desktop/dbf/신규 데이터');

% Load NGII NRTK service validation results
load('new_result.mat');
Total_h=Total_hv(:,[1 3 5 7 9 11 13 15 17 19]);
Total_v=Total_hv(:,[2 4 6 8 10 12 14 16 18 20]);
%%
% Define precision thresholds
horizThreshold = 0.05 *2 ;
vertThreshold = 0.10*2 ;
% Extract horizontal and vertical errors from results
hor_cols  = 1:2:size(Total_hv, 2);
ver_cols = 2:2:size(Total_hv, 2);

horizErrors  = Total_hv(:, hor_cols);
vertErrors = Total_hv(:, ver_cols);
pointNames  = Total_name(:,1);

% % Find test services and other services
% testServices   = [8]; % 검증하고 싶은 service 번호 기입!
% otherServices = setdiff(1:size(horizErrors, 2), testServices);
% 
% isFKP_Degrade  = any(~isnan(horizErrors(:, testServices)) & (horizErrors(:, testServices) > horizThreshold), 2);
% isOther_OK     = all((horizErrors(:, otherServices) <= horizThreshold) | isnan(horizErrors(:, otherServices)), 2);
% mask_horizFail = isFKP_Degrade & isOther_OK;
% 
% isFKP_Vert_Degrade = any(~isnan(vertErrors(:, testServices)) & (vertErrors(:, testServices) > vertThreshold), 2);
% isOther_Vert_OK    = all((vertErrors(:, otherServices) <= vertThreshold) | isnan(vertErrors(:, otherServices)), 2);
% mask_vertFail      = isFKP_Vert_Degrade & isOther_Vert_OK;

%Find test entire services and other services
vrsServices   = [1 2 3 4 5 6 7]; 
fkpServices   = 8;
gvrs1Services = 9;
gvrs2Services = 10;

% vrs fkp 
isvrs_Degrade  = all(~isnan(horizErrors(:, vrsServices)) & (horizErrors(:, vrsServices) < horizThreshold), 2);
isfkp_Degrade  = all((horizErrors(:, fkpServices) >= horizThreshold) & ~isnan(horizErrors(:, fkpServices)), 2);
maskfkp_horizFail = isvrs_Degrade & isfkp_Degrade;

isvrs_vert_Degrade  = all(~isnan(horizErrors(:, vrsServices)) & (vertErrors(:, vrsServices) < vertThreshold), 2);
isfkp_vert_Degrade  = all((horizErrors(:, fkpServices) >= vertThreshold) & ~isnan(vertErrors(:, fkpServices)), 2);
maskfkp_vertFail       = isvrs_vert_Degrade & isfkp_vert_Degrade;

% vrs gvrs1
isvrs_Degrade  = all(~isnan(horizErrors(:, vrsServices)) & (horizErrors(:, vrsServices) < horizThreshold), 2);
isgvrs1_Degrade  = all((horizErrors(:, gvrs1Services) >= horizThreshold) & ~isnan(horizErrors(:, gvrs1Services)), 2);
maskgvrs1_horizFail = isvrs_Degrade & isgvrs1_Degrade;

isvrs_vert_Degrade  = all(~isnan(horizErrors(:, vrsServices)) & (vertErrors(:, vrsServices) < vertThreshold), 2);
isgvrs_vert_Degrade  = all((horizErrors(:, gvrs1Services) >= vertThreshold) & ~isnan(vertErrors(:, gvrs1Services)), 2);
maskgvrs1_vertFail       = isvrs_vert_Degrade & isgvrs_vert_Degrade;

% vrs gvrs2
isvrs_Degrade  = all(~isnan(horizErrors(:, vrsServices)) & (horizErrors(:, vrsServices) < horizThreshold), 2);
isgvrs2_Degrade  = all((horizErrors(:, gvrs2Services) >= horizThreshold) & ~isnan(horizErrors(:, gvrs2Services)), 2);
maskgvrs2_horizFail = isvrs_Degrade & isgvrs2_Degrade;

isvrs_vert_Degrade  = all(~isnan(horizErrors(:, vrsServices)) & (vertErrors(:, vrsServices) < vertThreshold), 2);
isgvrs2_vert_Degrade  = all((horizErrors(:, gvrs2Services) >= vertThreshold) & ~isnan(vertErrors(:, gvrs2Services)), 2);
maskgvrs2_vertFail       = isvrs_vert_Degrade & isgvrs2_vert_Degrade;

pointNames  = Total_name(:,1);
fkpdegradedRows  = find(maskfkp_horizFail | maskfkp_vertFail); % 이상 지점 index
fkpdegradedNames = pointNames(fkpdegradedRows, 1)

gvrs1degradedRows  = find(maskgvrs1_horizFail | maskgvrs1_vertFail); % 이상 지점 index
gvrs1degradedNames = pointNames(gvrs1degradedRows, 1)

gvrs2degradedRows  = find(maskgvrs2_horizFail | maskgvrs2_vertFail); % 이상 지점 index
gvrs2degradedNames = pointNames(gvrs2degradedRows, 1)
%  %수평 성능저하 마스크
% testServices   = [1 2 3 4 5 6 7 8 9 10]; 
% otherServices = setdiff(1:size(horizErrors, 2), testServices);
% 
% istest_Degrade  = all(~isnan(horizErrors(:, testServices)) & (horizErrors(:, testServices) > horizThreshold), 2);
% mask_horizFail = istest_Degrade;
% 
% istest_Vert_Degrade = all(~isnan(vertErrors(:, testServices)) & (vertErrors(:, testServices) > vertThreshold), 2);
% mask_vertFail      = istest_Vert_Degrade ;

