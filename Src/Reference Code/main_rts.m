clear; clc; %close all;
dbstop if error;
format long;
warning("off");

%% addpath
addpath('src');
addpath('sub');
addpath('data\rts');

%% NTRIP mountpoints
ntrip_mp = readtable("ntrip_mountpoint.csv","Delimiter",';');
ntrip_mp.Properties.VariableNames = ["Type","Mountpoint","ID","Format","Format-Details","Carrier","Nav-System","Network",...
    "Country","Latitude","Longitude","NMEA","Solution","Generator","Compr-Encrp","Authentication","Fee","Bitrate","None"];

%% cors networks
cors_network_temp = readtable("cors_20250403032133.xls","NumHeaderLines",8);
cors_network_temp.Properties.VariableNames = ["Var1","Mountpoint","Var3","Var4","Var5","Var6","Var7","Var8","Var9","ECEFX",...
    "ECEFY","ECEFZ","Var13","Var14","Latitude","Longitude","Altitude","Var18","Var19","Provider","RINEX","Version","HeaderX","HeaderY","HeaderZ","ObsTypes"];

cors_network = table(cors_network_temp.Provider,cors_network_temp.Mountpoint,str2double(cors_network_temp.Latitude),str2double(cors_network_temp.Longitude));
cors_network.Properties.VariableNames = ["Provider","Mountpoint","Latitude","Longitude"];

idx_lat = find(cors_network.Latitude < 32 | cors_network.Latitude > 39);
cors_network(idx_lat,:) = [];

idx_lon = find(cors_network.Longitude < 124 | cors_network.Longitude > 132);
cors_network(idx_lon,:) = [];

cors_network.usedRTS1 = zeros(length(cors_network.Latitude),1);
cors_network.usedRTS2 = zeros(length(cors_network.Latitude),1);
cors_network.providedNTRIP = zeros(length(cors_network.Latitude),1);

%% RTCM ? RINEX ?
for k = 1:length(ntrip_mp.Mountpoint)-1
    mp = extractBetween(ntrip_mp.Mountpoint(k), 1, 4);
    idx_mp = find(strcmp(mp,cors_network.Mountpoint));
    cors_network.providedNTRIP(idx_mp) = 1;
end

%% RTS networks
rts_file_1 = 'RTS1 망.shp';
rts_file_2 = 'RTS2 망.shp';
rts_file_3 = 'RTS3 망.shp';

rts_1 = shaperead(rts_file_1);
rts_2 = shaperead(rts_file_2);
rts_3 = shaperead(rts_file_3);

%% RTS1
rts_1_cors = table([rts_1.Y]', [rts_1.X]', 'VariableNames', {'Latitude', 'Longitude'});
idx_nan = find(isnan(rts_1_cors.Latitude));
rts_1_cors(idx_nan,:) = [];

[~,idx_unique] = unique(rts_1_cors.Latitude);
rts_1_cors = rts_1_cors(idx_unique,:);

for k = 1:length(rts_1_cors.Latitude)
    enu = lla2enu([cors_network.Latitude,cors_network.Longitude,zeros(length(cors_network.Latitude),1)],[rts_1_cors.Latitude(k),rts_1_cors.Longitude(k),0],"flat");
    idx_cors = find(vecnorm(enu')' < 10);
    cors_network.usedRTS1(idx_cors) = 1;
end

%% RTS2
rts_2_cors = table([rts_2.Y]', [rts_2.X]', 'VariableNames', {'Latitude', 'Longitude'});
idx_nan = find(isnan(rts_2_cors.Latitude));
rts_2_cors(idx_nan,:) = [];

[~,idx_unique] = unique(rts_2_cors.Latitude);
rts_2_cors = rts_2_cors(idx_unique,:);

for k = 1:length(rts_2_cors.Latitude)
    enu = lla2enu([cors_network.Latitude,cors_network.Longitude,zeros(length(cors_network.Latitude),1)],[rts_2_cors.Latitude(k),rts_2_cors.Longitude(k),0],"flat");
    idx_cors = find(vecnorm(enu')' < 10);
    cors_network.usedRTS2(idx_cors) = 1;
end

limit_axis = [125,131,33,39];

%% post-processing
figure(101);
subplot(121);
hold on; grid on; box on;
set(gca,'Color','none');
axis(gca,'square');
axis(limit_axis);
set(gca, 'FontSize', 20, 'FontWeight', 'Bold','LineWidth', 2);
xlabel('Longitude');
ylabel('Latitude');
title('NGII RTS1 Network','FontWeight','bold');
mapshow(rts_1,'FaceColor','red','FaceAlpha',0.2);

idx_rts1_off = find(cors_network.usedRTS1 == 0);
plot(cors_network.Longitude(idx_rts1_off),cors_network.Latitude(idx_rts1_off),'^','LineWidth',2,'Color','k','MarkerFaceColor','b','MarkerSize',8);

idx_rts1_on = find(cors_network.usedRTS1 == 1);
plot(cors_network.Longitude(idx_rts1_on),cors_network.Latitude(idx_rts1_on),'s','LineWidth',2,'Color','k','MarkerFaceColor','y','MarkerSize',8);

isInside = nan(length(cors_network.Latitude),1);

%%
num_of_rts_1_post_in = 0;

for k = 1:length(rts_1)
    lon_b = rts_1(k).X(1:3);
    lat_b = rts_1(k).Y(1:3);
    for kk = 1:length(cors_network.Latitude(idx_rts1_off))
        isInside(idx_rts1_off(kk),:) = isPointInTriangle(cors_network.Latitude(idx_rts1_off(kk)), cors_network.Longitude(idx_rts1_off(kk)), lat_b(1), lon_b(1), lat_b(2), lon_b(2), lat_b(3), lon_b(3));
    end
    if(any(isInside))
        mapshow(rts_1(k),'FaceColor','black','FaceAlpha',0.5);
        num_of_rts_1_post_in = num_of_rts_1_post_in + 1;
        idx = find(isInside == 1);
        cors_network.usedRTS1monitorPost(idx) = 1;
    end
end

%%
subplot(122);
hold on; grid on; box on;
set(gca,'Color','none');
axis(gca,'square');
axis(limit_axis);
set(gca, 'FontSize', 20, 'FontWeight', 'Bold','LineWidth', 2);
xlabel('Longitude');
ylabel('Latitude');
title('NGII RTS2 Network','FontWeight','bold');

mapshow(rts_2,'FaceColor','green','FaceAlpha',0.2);

idx_rts2_off = find(cors_network.usedRTS2 == 0);
plot(cors_network.Longitude(idx_rts2_off),cors_network.Latitude(idx_rts2_off),'^','LineWidth',2,'Color','k','MarkerFaceColor','b','MarkerSize',8);

idx_rts2_on = find(cors_network.usedRTS2 == 1);
plot(cors_network.Longitude(idx_rts2_on),cors_network.Latitude(idx_rts2_on),'s','LineWidth',2,'Color','k','MarkerFaceColor','y','MarkerSize',8);

%%
num_of_rts_2_post_in = 0;

for k = 1:length(rts_2)
    lon_b = rts_2(k).X(1:3);
    lat_b = rts_2(k).Y(1:3);
    for kk = 1:length(cors_network.Latitude(idx_rts2_off))
        isInside(idx_rts2_off(kk),:) = isPointInTriangle(cors_network.Latitude(idx_rts2_off(kk)), cors_network.Longitude(idx_rts2_off(kk)), lat_b(1), lon_b(1), lat_b(2), lon_b(2), lat_b(3), lon_b(3));
    end
    if(any(isInside))
        mapshow(rts_2(k),'FaceColor','black','FaceAlpha',0.5);
        num_of_rts_2_post_in = num_of_rts_2_post_in + 1;
        idx = find(isInside == 1);
        cors_network.usedRTS2monitorPost(idx) = 1;
    end
end

%% real-time
figure(102);
subplot(121);
hold on; grid on; box on;
set(gca,'Color','none');
axis(gca,'square');
axis(limit_axis);
set(gca, 'FontSize', 20, 'FontWeight', 'Bold','LineWidth', 2);
xlabel('Longitude');
ylabel('Latitude');
title('NGII RTS1 Network','FontWeight','bold');

mapshow(rts_1,'FaceColor','red','FaceAlpha',0.2);

idx_rts1_off = find(cors_network.usedRTS1 == 0 & cors_network.providedNTRIP == 1);
plot(cors_network.Longitude(idx_rts1_off),cors_network.Latitude(idx_rts1_off),'o','LineWidth',2,'Color','k','MarkerFaceColor','r','MarkerSize',8);

idx_rts1_on = find(cors_network.usedRTS1 == 1);
plot(cors_network.Longitude(idx_rts1_on),cors_network.Latitude(idx_rts1_on),'s','LineWidth',2,'Color','k','MarkerFaceColor','y','MarkerSize',8);

%%
num_of_rts_1_real_in = 0;

for k = 1:length(rts_1)
    lon_b = rts_1(k).X(1:3);
    lat_b = rts_1(k).Y(1:3);
    for kk = 1:length(cors_network.Latitude(idx_rts1_off))
        isInside(idx_rts1_off(kk),:) = isPointInTriangle(cors_network.Latitude(idx_rts1_off(kk)), cors_network.Longitude(idx_rts1_off(kk)), lat_b(1), lon_b(1), lat_b(2), lon_b(2), lat_b(3), lon_b(3));
    end
    if(any(isInside))
        mapshow(rts_1(k),'FaceColor','black','FaceAlpha',0.5);
        num_of_rts_1_real_in = num_of_rts_1_real_in + 1;
        idx = find(isInside == 1);
        cors_network.usedRTS1monitorReal(idx) = 1;
    end
end

%%
subplot(122);
hold on; grid on; box on;
set(gca,'Color','none');
axis(gca,'square');
axis(limit_axis);
set(gca, 'FontSize', 20, 'FontWeight', 'Bold','LineWidth', 2);
xlabel('Longitude');
ylabel('Latitude');
title('NGII RTS2 Network','FontWeight','bold');

mapshow(rts_2,'FaceColor','green','FaceAlpha',0.2);

idx_rts2_off = find(cors_network.usedRTS2 == 0 & cors_network.providedNTRIP == 1);
plot(cors_network.Longitude(idx_rts2_off),cors_network.Latitude(idx_rts2_off),'o','LineWidth',2,'Color','k','MarkerFaceColor','r','MarkerSize',8);

idx_rts2_on = find(cors_network.usedRTS2 == 1);
plot(cors_network.Longitude(idx_rts2_on),cors_network.Latitude(idx_rts2_on),'s','LineWidth',2,'Color','k','MarkerFaceColor','y','MarkerSize',8);

%%
num_of_rts_2_real_in = 0;

for k = 1:length(rts_2)
    lon_b = rts_2(k).X(1:3);
    lat_b = rts_2(k).Y(1:3);
    for kk = 1:length(cors_network.Latitude(idx_rts2_off))
        isInside(idx_rts2_off(kk),:) = isPointInTriangle(cors_network.Latitude(idx_rts2_off(kk)), cors_network.Longitude(idx_rts2_off(kk)), lat_b(1), lon_b(1), lat_b(2), lon_b(2), lat_b(3), lon_b(3));
    end
    if(any(isInside))
        mapshow(rts_2(k),'FaceColor','black','FaceAlpha',0.5);
        num_of_rts_2_real_in = num_of_rts_2_real_in + 1;
        idx = find(isInside == 1);
        cors_network.usedRTS2monitorReal(idx) = 1;
    end
end

%%
usedRTS1monitorPost = sum(cors_network.usedRTS1monitorPost)
usedRTS2monitorPost = sum(cors_network.usedRTS2monitorPost)
usedRTS1monitorReal = sum(cors_network.usedRTS1monitorReal)
usedRTS2monitorReal = sum(cors_network.usedRTS2monitorReal)


idx_lxsiri = length(find(cors_network_temp.Provider == "LXSIRI"))
idx_nmsc = length(find(cors_network_temp.Provider == "NMSC"))
idx_nmpnt = length(find(cors_network_temp.Provider == "NMPNT"))
idx_ngii = length(find(cors_network_temp.Provider == "NGII"))
idx_eseoul = length(find(cors_network_temp.Provider == "ESEOUL"))
idx_kswc = length(find(cors_network_temp.Provider == "KSWC"))
idx_kigam = length(find(cors_network_temp.Provider == "KIGAM"))
idx_kasi = length(find(cors_network_temp.Provider == "KASI"))

keyboard;

%% fig
fig = figure('Position', [100,100,1600,800], 'Name', 'Select Options', 'NumberTitle', 'off');

ax = axes('Parent', fig, 'Position', [0.1, 0.1, 0.65, 0.85]);
grid(ax, 'on');
hold(ax, 'on');
box(ax, 'on');
set(ax,'Color','none');
axis(ax,'square');
limit_axis = [124,132,33,39];

mapshow(ax,rts_1,'FaceColor','red','FaceAlpha',0.2);

idx_ngii = find(cors_network.Provider == "NGII");
plot(ax, cors_network.Longitude(idx_ngii),cors_network.Latitude(idx_ngii),'s','LineWidth',2,'Color','k','MarkerFaceColor','y','MarkerSize',10);

idx_nmpnt = find(cors_network.Provider == "NMPNT");
plot(ax, cors_network.Longitude(idx_nmpnt),cors_network.Latitude(idx_nmpnt),'^','LineWidth',2,'Color','k','MarkerFaceColor','b','MarkerSize',10);

idx_lxsiri = find(cors_network.Provider == "LXSIRI");
plot(ax, cors_network.Longitude(idx_lxsiri),cors_network.Latitude(idx_lxsiri),'o','LineWidth',2,'Color','k','MarkerFaceColor','r','MarkerSize',10);

idx_nmsc = find(cors_network.Provider == "NMSC");
plot(ax, cors_network.Longitude(idx_nmsc),cors_network.Latitude(idx_nmsc),'pentagram','LineWidth',2,'Color','k','MarkerFaceColor','g','MarkerSize',10);


%% gui
checkbox_gui(ntrip_mp,rts_1,rts_2,rts_3);

