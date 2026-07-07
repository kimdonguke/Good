%% pre-install
% 1. install python
% 2. pip install selenium

%%
clear; clc; %close all;
dbstop if error;
format long;
warning("off");

%% addpath
addpath('src');
addpath('sub');
addpath('data\rts');

%% cors networks
cors_network_temp = readtable("cors_20250403032133.xls","NumHeaderLines",8);
cors_network_temp.Properties.VariableNames = ["Var1","Mountpoint","Var3","Var4","Var5","Var6","Var7","Var8","Var9","ECEFX",...
    "ECEFY","ECEFZ","Var13","Var14","Latitude","Longitude","Altitude","Var18","Var19","Provider","RINEX","Version","HeaderX","HeaderY","HeaderZ"];

cors_network = table(cors_network_temp.Provider,cors_network_temp.Mountpoint,cors_network_temp.RINEX,cors_network_temp.Version,...
    str2double(cors_network_temp.ECEFX),str2double(cors_network_temp.ECEFY),str2double(cors_network_temp.ECEFZ), ...
    cors_network_temp.HeaderX,cors_network_temp.HeaderY,cors_network_temp.HeaderZ);
cors_network.Properties.VariableNames = ["Provider","Mountpoint","RINEX","Version","ECEFX","ECEFY","ECEFZ","HeaderX","HeaderY","HeaderZ"];

%% import rtklib
convbin_path = strcat(cd,'\rtklib\','convbin.exe');

%% python processing
folder_temp = input('시작일을 입력하세요 (예: YYYY-MM-DD): ', 's');
folder_temp_end = input('종료일을 입력하세요 (예: YYYY-MM-DD): ', 's');
command = sprintf('python download_rinex.py %s %s %s',folder_temp,folder_temp_end,'ALL');
system(command);

%% gunzip I
folder = strcat("data\ngii\",folder_temp);
cd(folder);
file_list_1 = dir; file_list_1 = file_list_1(~[file_list_1.isdir]);

for nFile = 1:length(file_list_1)
    filename = file_list_1(nFile).name;
    if(contains(filename,'zip'))
        %% unzip
        unzip(filename);
        fprintf(strcat(filename,'\n'));
    end
end

%% gunzip II
folder_name_temp = strsplit(folder,"\");
folder_name = strsplit(folder_name_temp(3),"-");
targetDate = datetime(str2double(folder_name(1)), str2double(folder_name(2)), str2double(folder_name(3)));
doy = sprintf('%03d', day(targetDate, 'dayofyear'));

cd(strcat("RINEX\",folder_name(1),"\Daily\",doy));
file_list_2 = dir; file_list_2 = file_list_2(~[file_list_2.isdir]);

for nFile = 1:length(file_list_2)
    filename = file_list_2(nFile).name;
    if(contains(filename,'zip'))
        %% unzip
        unzip(filename);
        fprintf(strcat(filename,'\n'));
    end
end

%% observation
file_list_3 = dir; file_list_3 = file_list_3(~[file_list_3.isdir]);
names = {file_list_3.name};
obs_file_list = names(endsWith(names, 'o'))';

for nFile = 1:length(obs_file_list)

    input_rinex = string(obs_file_list(nFile));

    MP = extractBetween(input_rinex, 1, 4);
    idx = find(cors_network.Mountpoint == MP);
    cors_network.RINEX(idx) = 1;

    %% check version
    fid = fopen(input_rinex, 'r');

    while ~feof(fid)
        line = fgetl(fid);

        if(contains(line,"RINEX VERSION / TYPE"))
            cors_network.Version(idx) = string(extractBetween(line, 6, 9));
        elseif(contains(line,"APPROX POSITION XYZ"))
            cors_network.HeaderX(idx) = string(extractBetween(line, 3, 14));
            cors_network.HeaderY(idx) = string(extractBetween(line, 17, 28));
            cors_network.HeaderZ(idx) = string(extractBetween(line, 31, 42));            
        elseif(contains(line,"END OF HEADER"))
            fclose(fid);
            break;
        end
    end

idx = find(cors_network.ECEFX == 0);
cors_network.ECEFX(idx) = nan;
cors_network.ECEFY(idx) = nan;
cors_network.ECEFZ(idx) = nan;

idx = find(cors_network.HeaderX == 0);
cors_network.HeaderX(idx) = nan;
cors_network.HeaderY(idx) = nan;
cors_network.HeaderZ(idx) = nan;

end

cd("..\..\..\..\..\..\..\results");
writetable(cors_network,strcat("results_",sprintf('%04d%02d%02d',str2double(folder_name(1)), str2double(folder_name(2)), str2double(folder_name(3))),".csv"));

