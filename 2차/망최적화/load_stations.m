function [lon, lat, names, T] = load_stations()
% LOAD_STATIONS  위성기준점(99개소) 데이터 로드 (파이프라인 공통 진입점)
%   [lon, lat, names, T] = load_stations()
%     lon, lat : 십진도 좌표 (DMS 문자열 → dms2deg 변환, WGS84)
%     names    : RINEX 4문자 코드 (실무 배정표/식별자)
%     T        : 전체 속성 테이블 (Name 한글지점명, Height 타원체고, Proj 투영원점 등)
%   shp 원본: Data/rts/위성기준점(99개소).shp — DMS 파싱 실패 행은 제외(validDMS).

% ---- 프로젝트 경로 자동 설정 ----
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
% ---------------------------------

rtsStations = struct2table(shaperead('위성기준점(99개소).shp'));
rtsStations.Properties.VariableNames = {'Geometry','X_proj','Y_proj','FID1','FID2', ...
    'Name','RINEX','LAT_dms','LON_dms','Height','X1','Y1','Proj','None1','None2'}';

latParts = cellfun(@(x) str2double(strsplit(x,'-')), rtsStations.LAT_dms, 'UniformOutput', false);
lonParts = cellfun(@(x) str2double(strsplit(x,'-')), rtsStations.LON_dms, 'UniformOutput', false);
validDMS = ~cellfun('isempty', latParts) & ~cellfun('isempty', lonParts);
rtsStations.LAT_deg(validDMS) = cellfun(@(x) dms2deg(x'), latParts(validDMS));
rtsStations.LON_deg(validDMS) = cellfun(@(x) dms2deg(x'), lonParts(validDMS));

T     = rtsStations(validDMS, :);
lon   = T.LON_deg;
lat   = T.LAT_deg;
names = string(T.RINEX);
end
