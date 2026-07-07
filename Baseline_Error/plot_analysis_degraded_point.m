%% NGII Network RTK Correction Service Analysis


%% Initialize and Setup
% close all;
clear;
clc;

% Add necessary path
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

% Initialize constants
% initconst();

%% Load and Preprocess Data (NGII Network)

% Load NGII NRTK service validation results
load('rslt.mat');

% Load CORS information (format: shapefile)
rtsStations = struct2table(shaperead('위성기준점(99개소).shp'));
rtsStations.Properties.VariableNames = {'Geometry', 'X_proj', 'Y_proj', 'FID1', 'FID2', 'Name', 'RINEX', 'LAT_dms', 'LON_dms'...
                                       ,'Height', 'X1', 'Y1', 'Proj', 'None1', 'None2'}';

RTSid = [0 : size(rtsStations,1)-1]';
rtsStations.RTSid = RTSid; 

% Convert DMS to decimal degree
latParts = cellfun(@(x) str2double(strsplit(x, '-')), rtsStations.LAT_dms, 'UniformOutput', false);
lonParts = cellfun(@(x) str2double(strsplit(x, '-')), rtsStations.LON_dms, 'UniformOutput', false);

validDMS = ~cellfun('isempty', latParts) & ~cellfun('isempty', lonParts);
rtsStations.LAT_deg(validDMS) = cellfun(@(x) dms2deg(x'), latParts(validDMS));
rtsStations.LON_deg(validDMS) = cellfun(@(x) dms2deg(x'), lonParts(validDMS));

% Load CORS Network information (format: shapefile)
netrtsfile  = shaperead('위성기준점(99개소) 망.shp');

for i = 1:size(netrtsfile, 1)
    idxA = find((netrtsfile(i).POINTA == [rtsStations.RTSid]') & (netrtsfile(i).X(1) == [rtsStations.X_proj]'));
    idxB = find((netrtsfile(i).POINTB == [rtsStations.RTSid]') & (netrtsfile(i).X(2) == [rtsStations.X_proj]'));
    idxC = find((netrtsfile(i).POINTC == [rtsStations.RTSid]') & (netrtsfile(i).X(3) == [rtsStations.X_proj]'));

    networkLats(i,1) = rtsStations.LAT_deg(idxA);
    networkLats(i,2) = rtsStations.LAT_deg(idxB);
    networkLats(i,3) = rtsStations.LAT_deg(idxC);

    networkLons(i,1) = rtsStations.LON_deg(idxA);
    networkLons(i,2) = rtsStations.LON_deg(idxB);
    networkLons(i,3) = rtsStations.LON_deg(idxC);
end

netrts = table(networkLats, networkLons, [netrtsfile.POINTA]', [netrtsfile.POINTB]', [netrtsfile.POINTC]', 'VariableNames', {'LAT', 'LON', 'POINTA', 'POINTB', 'POINTC'});

%% Load and Preprocess Data (Test Points)

% Load test points information (True Position)
testPoints = readtable('검증 대상점 목록_250321.xlsx', 'VariableNamingRule', 'preserve');
testPoints.Properties.VariableNames = ["Location","Gridnum", "Name", "Var1","Lon_dms", "Lat_dms", "X", "Y", "h", "H", "Var2", "Var3",...
                                       "RINEX", "Var4", "Var5", "Var6"];

latParts_vp = cellfun(@(x) str2double(split(x)), testPoints.Lat_dms, 'UniformOutput', false);
lonParts_vp = cellfun(@(x) str2double(split(x)), testPoints.Lon_dms, 'UniformOutput', false);

validDMS_vp = ~cellfun('isempty', latParts_vp) & ~cellfun('isempty', lonParts_vp);
testPoints.Lat_deg(validDMS_vp) = cellfun(@(x) dms2deg(x'), latParts_vp(validDMS_vp));
testPoints.Lon_deg(validDMS_vp) = cellfun(@(x) dms2deg(x'), lonParts_vp(validDMS_vp));

% Test points positioning performance analysis

% Define precision thresholds
horizThreshold = 0.05 * 2;  % Horizontal precision threshold (e.g., 10 cm)
vertThreshold  = 0.10 * 2;  % Vertical precision threshold (e.g., 20 cm)

% Extract horizontal and vertical errors from results
horizErrors = rslt{1,2};
vertErrors  = rslt{1,3};
pointNames  = rslt{1,1};

% Find FKP services and other services
fkpServices   = [9, 10]; 
otherServices = setdiff(1:size(horizErrors, 2), fkpServices);

isFKP_Degrade  = any(~isnan(horizErrors(:, fkpServices)) & (horizErrors(:, fkpServices) > horizThreshold), 2);
isOther_OK     = all((horizErrors(:, otherServices) <= horizThreshold) | isnan(horizErrors(:, otherServices)), 2);
mask_horizFail = isFKP_Degrade & isOther_OK;

isFKP_Vert_Degrade = any(~isnan(vertErrors(:, fkpServices)) & (vertErrors(:, fkpServices) > vertThreshold), 2);
isOther_Vert_OK    = all((horizErrors(:, otherServices) <= horizThreshold) | isnan(horizErrors(:, otherServices)), 2);
mask_vertFail      = isFKP_Vert_Degrade;

% Combine masks to get all degraded points
degradedRows  = find(mask_horizFail | mask_vertFail);
degradedNames = pointNames(degradedRows, 2);

[~, idxFailing, ~] = intersect(testPoints.Name, degradedNames);


%% Plotting and Result Display

% Create new figure
figure;
gx = geoaxes;
geobasemap(gx, 'topographic')
hold(gx, 'on')
geolimits([33 39], [124 132])
title('NGII NRTK Service Performance Analysis')

% Plot NGII CORS Networks (polygons)
for k = 1:size(netrts,1)
    pg = geopolyshape(netrts.LAT(k, [1 2 3 1]), netrts.LON(k, [1 2 3 1]));
    geoplot(gx, pg, 'k', 'EdgeColor', 'k', 'HandleVisibility', 'off')
end

% Plot NGII CORS Stations
for i = 1:size(rtsStations, 1)
    geoplot(rtsStations.LAT_deg(i), rtsStations.LON_deg(i), 'gs', 'color', 'k', 'MarkerFaceColor','y', 'LineWidth', 1, 'MarkerSize', 6, 'HandleVisibility', 'off')
end

% Plot all test points
[~, idxValid, ~] = intersect(testPoints.Name, pointNames(:,2));
geoplot(gx, testPoints.Lat_deg(idxValid), testPoints.Lon_deg(idxValid), 'b^','MarkerFaceColor','b', 'LineWidth', 1, 'MarkerSize', 5);

% Plot performance degraded points
geoplot(gx, testPoints.Lat_deg(idxFailing), testPoints.Lon_deg(idxFailing), 'r^', ...
       'MarkerFaceColor','r', 'LineWidth', 1, 'MarkerSize', 5, 'DisplayName', 'Failing Points')
