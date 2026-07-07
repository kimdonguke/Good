%% Initialize and Setup
close all;
clear;
clc;
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
% (선택) 공유 Google Drive의 'Code' 폴더가 필요하면 본인 환경 경로로 지정 후 주석 해제
% addpath('X:\...\측량학회 [NGII 보정정보 성능 검증]\Code');
% -------------------------------------------------------------------------
%% Load and Preprocess Data (NGII Network)
% Load CORS information (format: shapefile)
rtsStations = struct2table(shaperead('위성기준점(99개소).shp'));
rtsStations.Properties.VariableNames = {'Geometry', 'X_proj', 'Y_proj', 'FID1', 'FID2', ...
                                        'Name', 'RINEX', 'LAT_dms', 'LON_dms', 'Height',...
                                        'X1', 'Y1', 'Proj', 'None1', 'None2'}';
RTSid = (0 : size(rtsStations,1)-1)';
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
%% Plotting and Result Display
TruePos_ECEF = [
    -3020139.799, 4079807.145, 3849130.627; % PALM 1
    -2876283.755, 4149428.408, 3884508.482; % SOCH 2
    -3020236.857, 4136468.616, 3788431.988; % ANHN 3
    -3029436.991, 4174489.865, 3739474.670; % EOCH 4
    -3064945.137, 4170122.441, 3715473.938; % MLDO 5
    -3025924.946, 4288817.018, 3611645.039; % HGDO 6
    -3040228.939, 4325980.929, 3555223.961; % GASE 7 
    -3097626.989, 4256824.484, 3588741.435; % GASA 8 
    -3152604.582, 4244559.537, 3555538.726; % DANG 9
    -3209052.409, 4209084.067, 3547202.181; % GEOM 10
    -3228667.951, 4162214.110, 3584296.756; % SORI 11
    -3163444.449, 4311372.207, 3464865.222; % MARA 12
    -3281490.566, 4090421.629, 3618634.192; % SEOI 13
    -3294232.510, 4057786.202, 3643626.819; % YNDO 14
    -3287391.371, 3978484.960, 3735216.059; % HOMI 15
    -3154854.857, 4099170.444, 3719782.817; % MOOJ 16
    -3196187.662, 4064068.516, 3722851.285; % SEJU 17
    -3138633.993, 4078412.585, 3755410.009; % OKCH 18
    -3169577.644, 4030299.571, 3781067.315; % MUNG 19
    -3123433.261, 4033298.187, 3815900.759; % CCHJ 20
    -3183643.871, 3995960.384, 3805622.050; % YNJU 21
    -3236668.844, 3936353.400, 3822579.047; % JUKB 22
    -3204049.208, 3930214.539, 3855959.433; % SAMC 23
    -3159577.521, 3973889.641, 3848566.324; % PYCH 24
    -3102607.958, 3989929.871, 3877576.742; % HONG 25
    -3078831.376, 3981392.550, 3905083.340; % CCHN 26
    -3130518.687, 3921543.502, 3924167.491; % SOKC 27
    -3160056.141, 3925576.993, 3896541.865; % JUMN 28 
    -3035913.940, 4052535.357, 3865342.823; % GANS 29
    -3044105.929, 4053468.858, 3857988.182; % GUMC 30
    -3047506.741, 4043980.580, 3865243.010; % YONS 31
    -3046229.955, 4034989.023, 3875524.024; % DBON 32
    -3059553.884, 4039145.662, 3860773.000; % SONP 33
    -3253751.004, 4054962.963, 3682413.187; % MLYN 34
    -3161258.981, 3974731.038, 3846954.260  % DONM 35
    ];
% WGS84 타원체
wgs84 = wgs84Ellipsoid('meter');

% ECEF → LLA
lla = ecef2lla(TruePos_ECEF);


% Create new figure
figure('Position',[100 100 850 660]);
gx = geoaxes;
geobasemap(gx, 'topographic')
hold(gx, 'on')
geolimits([33 39], [125 130])
title('원격감시국 + 측량지점 위치 확인')

% Plot NGII CORS Stations
for k = 1:size(netrts,1)
    pg = geopolyshape(netrts.LAT(k, [1 2 3 1]), netrts.LON(k, [1 2 3 1]));
    geoplot(gx, pg, 'k', 'EdgeColor', 'k', 'HandleVisibility', 'off')
end
for i = 1:size(rtsStations, 1)
    geoplot(rtsStations.LAT_deg(i), rtsStations.LON_deg(i), 'gs', 'color', 'k', 'MarkerFaceColor','y', 'LineWidth', 1, 'MarkerSize', 6, 'HandleVisibility', 'off')
end

% % % seoul
% % geoplot(gx, 37.54104803611111, 127.11667680277777, ...
% %         'o', 'MarkerEdgeColor','k', 'MarkerFaceColor','r', ...
% %         'MarkerSize',5, 'LineStyle','none')
% % U0545
% h2 = geoplot(gx, 36.275526005555555 , 126.91739651111112 , ...
%         'o', 'MarkerEdgeColor','r', 'MarkerFaceColor','r', ...
%         'MarkerSize',5, 'LineStyle','none')
% % U0546
% geoplot(gx, 36.253594875, 126.81402043055554 , ...
%         'o', 'MarkerEdgeColor','r', 'MarkerFaceColor','r', ...
%         'MarkerSize',5, 'LineStyle','none')
% % U0790
% geoplot(gx, 35.64807638333334, 127.69315127222222 , ...
%         'o', 'MarkerEdgeColor','r', 'MarkerFaceColor','r', ...
%         'MarkerSize',5, 'LineStyle','none')
% % U0867
% geoplot(gx, 35.34572, 127.22825, ...
%         'o', 'MarkerEdgeColor','r', 'MarkerFaceColor','r', ...
%         'MarkerSize',5, 'LineStyle','none')
% % U0878
% geoplot(gx, 35.48094759999999, 127.68900919166667, ...
%         'o', 'MarkerEdgeColor','r', 'MarkerFaceColor','r', ...
%         'MarkerSize',5, 'LineStyle','none')
% % U금산77
% geoplot(gx, 36.06338366944444, 127.40187395000001, ...
%         'o', 'MarkerEdgeColor','r', 'MarkerFaceColor','r', ...
%         'MarkerSize',5, 'LineStyle','none')
% % U남원26
% geoplot(gx, 35.41123132777778, 127.31962970555556, ...
%         'o', 'MarkerEdgeColor','r', 'MarkerFaceColor','r', ...
%         'MarkerSize',5, 'LineStyle','none')
% % U무풍36
% geoplot(gx, 35.82898200277778, 127.80787053055555, ...
%         'o', 'MarkerEdgeColor','r', 'MarkerFaceColor','r', ...
%         'MarkerSize',5, 'LineStyle','none')
% % U산청36
% geoplot(gx, 35.40810205277777, 127.89842, ...
%         'o', 'MarkerEdgeColor','r', 'MarkerFaceColor','r', ...
%         'MarkerSize',5, 'LineStyle','none')
% % U안성43
% geoplot(gx, 37.13489016388889, 127.30748126111112, ...
%         'o', 'MarkerEdgeColor','r', 'MarkerFaceColor','r', ...
%         'MarkerSize',5, 'LineStyle','none')
% % U안흥36
% geoplot(gx, 37.40758757222222, 128.14605534444445, ...
%         'o', 'MarkerEdgeColor','r', 'MarkerFaceColor','r', ...
%         'MarkerSize',5, 'LineStyle','none')
% % U음성18
% geoplot(gx, 36.829962775000006, 127.62031629999998, ...
%         'o', 'MarkerEdgeColor','r', 'MarkerFaceColor','r', ...
%         'MarkerSize',5, 'LineStyle','none')
% % U임실24
% geoplot(gx, 35.55011482222222, 127.29328043333335, ...
%         'o', 'MarkerEdgeColor','r', 'MarkerFaceColor','r', ...
%         'MarkerSize',5, 'LineStyle','none')
% % U청도16
% geoplot(gx, 35.51750791111112, 128.64910340833333, ...
%         'o', 'MarkerEdgeColor','r', 'MarkerFaceColor','r', ...
%         'MarkerSize',5, 'LineStyle','none')

h1 = geoplot(gx, lla(:,1), lla(:,2), 'bo', 'MarkerSize', 5, 'MarkerFaceColor', 'b');

% legend([h1 h2], {'원격감시국','FKP or GVRS 성능 저하 구간'}, 'Location','bestoutside');


% % 풍각
% geoplot(gx, 35.640723, 128.577149, ...
%         'o', 'MarkerEdgeColor','k', 'MarkerFaceColor','k', ...
%         'MarkerSize',5, 'LineStyle','none')

% 지리원 제외 CORS 좌표
% Clat = CORS_lla(:,1);
% Clon = CORS_lla(:,2);
% in=0;
% z=0;
% Plot NGII CORS Stations
% for k = 1:size(netrts,1)
%     lat = netrts.LAT(k, [1 2 3]);
%     lon = netrts.LON(k, [1 2 3]);
% CORS_in = inpolygon(Clat, Clon, lat, lon);
% CORS로 커버할수 있는 Network 영역
%     CORS_in = inpolygon(Clat, Clon, lat, lon);
%     if any(CORS_in)
%         facecolor = 'red';
%         facealpha = 0.3;
%     else
%         facecolor = 'black';
%         facealpha = 0.3;
%     end
%     pg = geopolyshape(netrts.LAT(k, [1 2 3 1]), netrts.LON(k, [1 2 3 1]));
%     geoplot(gx, pg, 'k', 'EdgeColor', 'k', 'HandleVisibility', 'off')
%     geoplot(gx, pg, ...
%     'EdgeColor','k', ...    
%     'LineWidth',0.5, ...   
%     'FaceColor',facecolor, ...
%     'FaceAlpha',facealpha, ...
%     'HandleVisibility','off')
% end