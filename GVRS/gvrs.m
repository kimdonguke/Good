clear; clc;
load("gvrs_error.mat");
load("netRts.mat");
GNSS = readtable("cors_20251110011510.xls");

GNSS(1:5,:)=[];

ii = find(strcmp(GNSS.Var2,'국토지리정보원'));
GNSS(ii,:) = [];
GNSS.Var15 = str2double(GNSS.Var15);
GNSS.Var16 = str2double(GNSS.Var16);

Station = table(GNSS.Var2,GNSS.Var15,GNSS.Var16);

GVRS_Horizontal = readtable("dbf 정리파일수정본.xlsx",'Sheet','GVRS_Horizontal');
GVRS_Vertical = readtable("dbf 정리파일수정본.xlsx",'Sheet','GVRS_Vertical');

Hor_Lat = GVRS_Horizontal.Latitude;
Hor_Lon = GVRS_Horizontal.Longitude;

Ver_Lat = GVRS_Vertical.Latitude;
Ver_Lon = GVRS_Vertical.Longitude;




figure;
gx = geoaxes;
geobasemap(gx, 'topographic')
hold(gx, 'on')

geolimits([33 39], [124 132])
title('Station near the GVRS Horizontal anomaly point')

% --- 4. CORS 네트워크 플롯 (기존과 동일) ---
for k = 1:size(netrts,1)
    pg = geopolyshape(netrts.LAT(k, [1 2 3 1]), netrts.LON(k, [1 2 3 1]));
    geoplot(gx, pg, 'k', 'EdgeColor', 'k', 'HandleVisibility', 'off')
end
geoplot(Hor_Lat,Hor_Lon,'ko','MarkerFaceColor','w','MarkerSize',4)
% geoplot(Station.Var2(1:30),Station.Var3(1:30),'ko','LineWidth',1.2,'MarkerFaceColor','r');
% geoplot(Station.Var2(31:52),Station.Var3(31:52),'ko','LineWidth',1.2,'MarkerFaceColor','g');
% geoplot(Station.Var2(53:84),Station.Var3(53:84),'ko','LineWidth',1.2,'MarkerFaceColor','b');
% geoplot(Station.Var2(85:89),Station.Var3(85:89),'ko','LineWidth',1.2,'MarkerFaceColor','c');
% geoplot(Station.Var2(90:94),Station.Var3(90:94),'ko','LineWidth',1.2,'MarkerFaceColor','m');
% geoplot(Station.Var2(95:112),Station.Var3(95:112),'ko','LineWidth',1.2,'MarkerFaceColor','y');
% geoplot(Station.Var2(113:end),Station.Var3(113:end),'ko','LineWidth',1.2,'MarkerFaceColor',[1 0.5 0]);
% legend('수평 이상지점','공간정보연구원','국가기상위성센터','국립해양측위정보원','서울시','우주전파센터','한국지질자원연구원','한국천문연구원');


figure;
gx = geoaxes;
geobasemap(gx, 'topographic')
hold(gx, 'on')

geolimits([33 39], [124 132])
title('Station near the GVRS Vertical anomaly point')

% --- 4. CORS 네트워크 플롯 (기존과 동일) ---
for k = 1:size(netrts,1)
    pg = geopolyshape(netrts.LAT(k, [1 2 3 1]), netrts.LON(k, [1 2 3 1]));
    geoplot(gx, pg, 'k', 'EdgeColor', 'k', 'HandleVisibility', 'off')
end
geoplot(Ver_Lat,Ver_Lon,'ko','MarkerFaceColor','w','MarkerSize',4)
% geoplot(Station.Var2(1:30),Station.Var3(1:30),'ko','LineWidth',1.2,'MarkerFaceColor','r');
% geoplot(Station.Var2(31:52),Station.Var3(31:52),'ko','LineWidth',1.2,'MarkerFaceColor','g');
% geoplot(Station.Var2(53:84),Station.Var3(53:84),'ko','LineWidth',1.2,'MarkerFaceColor','b');
% geoplot(Station.Var2(85:89),Station.Var3(85:89),'ko','LineWidth',1.2,'MarkerFaceColor','c');
% geoplot(Station.Var2(90:94),Station.Var3(90:94),'ko','LineWidth',1.2,'MarkerFaceColor','m');
% geoplot(Station.Var2(95:112),Station.Var3(95:112),'ko','LineWidth',1.2,'MarkerFaceColor','y');
% geoplot(Station.Var2(113:end),Station.Var3(113:end),'ko','LineWidth',1.2,'MarkerFaceColor',[1 0.5 0]);
% legend('수직 이상지점','공간정보연구원','국가기상위성센터','국립해양측위정보원','서울시','우주전파센터','한국지질자원연구원','한국천문연구원');
