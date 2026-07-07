clear; clc;

load('Final_Data.mat');
Point = readtable('검증 대상점 목록_250321.xlsx');
t_lat = Point.x___3;
t_lon = Point.x___4;
for i = 1:length(t_lat)
    t_lat{i,1} = str2double(t_lat{i}(1:3)) + str2double(t_lat{i}(5:6))/60 ...
        + str2double(t_lat{i}(8:end))/3600;
    t_lon{i,1} = str2double(t_lon{i}(1:2)) + str2double(t_lon{i}(3:5))/60 ...
        + str2double(t_lon{i}(8:end))/3600;


end