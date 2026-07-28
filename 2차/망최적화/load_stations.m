function [lon, lat, names, T] = load_stations(mode)
% LOAD_STATIONS  국토지리정보원 위성기준점 데이터 로드 (파이프라인 공통 진입점)
%   [lon, lat, names, T] = load_stations()        — 설계용(기본): status=="ok" 만
%   [lon, lat, names, T] = load_stations('all')   — 고시 전체(미가동 신설국 포함)
%     lon, lat : 십진도 좌표 (고시 ECEF X,Y,Z → GRS80 측지 변환, KGD2002 정의 타원체)
%     names    : RINEX 4문자 코드 (실무 배정표/식별자)
%     T        : 속성 테이블 (RINEX/Name 한글지점명/lat/lon/Height 타원체고/
%                Proj 투영원점/status/src/qcOkDays2025)
%
%   데이터 소스: stations_ngii.mat — make_stations_ngii.m 이 최신 고시
%   (Data/CORS_coordinate_최종본.xlsx, 2026-07 반영 102개소)로부터 생성.
%   기본 설계셋은 가동 97개소 (status=="missing" 미가동 신설 도서국
%   CJDO·GMDO·HSDO·JJNG·ULDO 제외 — 상세 근거는 make_stations_ngii.m 헤더).
%
%   (legacy) 구 소스 Data/rts/위성기준점(99개소).shp — 2026-07-22 이전 결과가
%   이 기준. 신구 차이: +5 신설 / −2 제외(JINJ·YECH) / GGEO·SGWI 좌표 정정.

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

if nargin < 1 || isempty(mode); mode = 'design'; end

matFile = fullfile(thisDir, 'stations_ngii.mat');
if ~isfile(matFile)
    error(['load_stations: %s 가 없습니다.\n' ...
           '먼저 make_stations_ngii.m 을 실행해 최신 고시 데이터셋을 생성하세요.'], matFile);
end
L = load(matFile);
T = L.S;

% 신선도 확인: 소스 xlsx(고시 좌표/QC)가 mat보다 새로우면 재생성 필요 — stale 전파 방지
matInfo = dir(matFile);
srcInfo = [dir(fullfile(projectRoot, 'Data', 'CORS_coordinate_최종본.xlsx')); ...
           dir(fullfile(projectRoot, 'Data', 'NGII_daily_QC_*.xlsx'))];
if ~isempty(srcInfo) && any([srcInfo.datenum] > matInfo.datenum)
    warning('load_stations:stale', ...
        'stations_ngii.mat 가 소스 xlsx보다 오래되었습니다 — make_stations_ngii 재실행 필요.');
end

switch lower(string(mode))
    case "design"
        T = T(T.status == "ok", :);
    case "all"
        % 전체 유지
    otherwise
        error('load_stations: 알 수 없는 mode "%s" (design | all)', mode);
end

lon   = T.lon;
lat   = T.lat;
names = string(T.RINEX);
end
