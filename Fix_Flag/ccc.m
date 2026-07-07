clear; clc;

load("Ffinal_Data.mat");
load('Net_FKP.mat');

%% Horizontal
% idx = find(contains(Data.Point,'U0545','IgnoreCase',true));
idx_H = [];
for i = 1:height(Net_H)
    current_match = find(contains(Data.Point,Net_H.Point(i),'IgnoreCase',true));

    idx_H = [idx_H; current_match];
end
Horizontal = Data(idx_H,:);
current_match = find(contains(Data.Point,'uhs88','IgnoreCase',true));
Horizontal = [Horizontal; Data(current_match,:)];

current_match = find(contains(Data.Point,'ugs77','IgnoreCase',true));
Horizontal = [Horizontal; Data(current_match,:)];

current_match = find(contains(Data.Point,'ump63','IgnoreCase',true));
Horizontal = [Horizontal; Data(current_match,:)];

i1 = find(contains(Data.Point,'rtk','IgnoreCase',true) | ...
    contains(Data.Point,'rtcm23','IgnoreCase',true) | ...
    contains(Data.Point,'rts3','IgnoreCase',true) |...
    contains(Data.Point,'gvr','IgnoreCase',true) |...
    contains(Data.Point,'cmrx','IgnoreCase',true));
Data(i1,:) = [];

%% Vertical

idx_V = [];
for i = 1:height(Net_V)
    current_match = find(contains(Data.Point,Net_V.Point(i),'IgnoreCase',true));

    idx_V = [idx_V; current_match];
end
Vertical = Data(idx_V,:);

i2 = find(contains(Vertical.Point,'rtk','IgnoreCase',true) | ...
    contains(Vertical.Point,'rtcm23','IgnoreCase',true) | ...
    contains(Vertical.Point,'rts3','IgnoreCase',true) |...
    contains(Vertical.Point,'cmrx','IgnoreCase',true));
Vertical(i2,:) = [];


%% Horizontal + Vertical

idx_P = [];
for i = 1:height(Net_P)
    current_match = find(contains(Data.Point,Net_P.Point(i),'IgnoreCase',true));
    idx_P = [idx_P; current_match];
end
Position = Data(idx_P,:);

current_match = find(contains(Data.Point,'uhongcheon','IgnoreCase',true));
Position = [Position; Data(current_match,:)];

i3 = find(contains(Position.Point,'rtk','IgnoreCase',true) | ...
    contains(Position.Point,'rtcm23','IgnoreCase',true) | ...
    contains(Position.Point,'rts3','IgnoreCase',true) |...
    contains(Position.Point,'cmrx','IgnoreCase',true));
Position(i3,:) = [];