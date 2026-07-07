function NMEA = read_NMEA(filename_nmea, date)

f_nmea = fopen(filename_nmea, 'r');

isGGA = 0;
isGSA = 0;
isGSV = 0;
isRMC = 0;

index_GGA = 0;
index_GSA = 0;
index_GSV = 0;
index_RMC = 0;

numline = 0;

% while(~feof(f_nmea))
%     buffer = fgetl(f_nmea);
%     pos_GGA = strfind(buffer, '$GPGGA');
%     if (~isempty(pos_GGA))
%         index_GGA = index_GGA + 1
%     end
% end

% GGA.hour = nan(index_GGA, 1);
% GGA.minute = nan(index_GGA, 1);
% GGA.second = nan(index_GGA, 1)
% GGA.UTC = nan(index_GGA, 3);
% GGA.calsats(index_GGA)    = str2double(cal_sats);
% GGA.hdop(index_GGA)       = str2double(HDOP);
% GGA.updatetime(index_GGA) = str2double(update_time);
% GGA.fixtype(index_GGA)    = str2double(fix_type);
% GGA.lat(index_GGA) = str2double(latitude(1:2)) + str2double(latitude(3:length(latitude)))/60;
% GGA.lat(index_GGA) = -str2double(latitude(1:2)) + str2double(latitude(3:length(latitude)))/60;
% GGA.lon(index_GGA) = str2double(longitude(1:3)) + str2double(longitude(4:length(longitude)))/60;
% GGA.lon(index_GGA) = -str2double(longitude(1:3)) + str2double(longitude(4:length(longitude)))/60;
% GGA.height(index_GGA)    = str2double(height_sea) + str2double(height_wgs);
% GGA.pos_llh(index_GGA,1) = GGA.lat(index_GGA)*pi/180;
% GGA.pos_llh(index_GGA,2) = GGA.lon(index_GGA)*pi/180;
% GGA.pos_llh(index_GGA,3) = GGA.height(index_GGA);

while(~feof(f_nmea))
    buffer = fgetl(f_nmea);
    
    numline = numline + 1
    
    if (length(buffer) > 6)
        %%
        pos_GGA = strfind(buffer, 'GGA');
        if (~isempty(pos_GGA))
            
            count           = 0;
            UTC             = [];
            latitude        = [];
            latitude_polar  = [];
            longitude       = [];
            longitude_polar = [];
            fix_type        = [];
            cal_sats        = [];
            HDOP            = [];
            height_sea      = [];
            height_wgs      = [];
            update_time     = [];
            checksum        = [];
            
            for i = pos_GGA:length(buffer)
                if(buffer(i) == ',')
                    count = count + 1;
                elseif(count == 1)
                    UTC = strcat(UTC,buffer(i));
                elseif (count == 2)
                    latitude = strcat(latitude,buffer(i));
                elseif (count == 3)
                    latitude_polar = buffer(i);
                elseif (count == 4)
                    longitude = strcat(longitude,buffer(i));
                elseif (count == 5)
                    longitude_polar = buffer(i);
                elseif (count == 6)
                    fix_type = buffer(i);
                elseif (count == 7)
                    cal_sats = strcat(cal_sats, buffer(i));
                elseif (count == 8)
                    HDOP = strcat(HDOP, buffer(i));
                elseif (count == 9)
                    height_sea = strcat(height_sea, buffer(i));
                elseif (count == 11)
                    height_wgs = strcat(height_wgs, buffer(i));
                elseif (count == 13)
                    update_time = strcat(update_time, buffer(i));
                elseif (count == 14)
                    checksum = strcat(checksum, buffer(i));
                    
                    isGGA = 1;
                end
            end
            
            if (isGGA)
                index_GGA = index_GGA + 1;
                
                GGA.hour(index_GGA)       = str2double(UTC(1:2));
                GGA.minute(index_GGA)     = str2double(UTC(3:4));
                GGA.second(index_GGA)     = str2double(UTC(5:end));
                GGA.UTC(index_GGA,1)      = GGA.hour(index_GGA);
                GGA.UTC(index_GGA,2)      = GGA.minute(index_GGA);
                GGA.UTC(index_GGA,3)      = GGA.second(index_GGA);
                GGA.calsats(index_GGA)    = str2double(cal_sats);
                GGA.hdop(index_GGA)       = str2double(HDOP);
                GGA.updatetime(index_GGA) = str2double(update_time);
                GGA.fixtype(index_GGA)    = str2double(fix_type);
                
                if (GGA.fixtype(index_GGA))
                    if (strcmp(latitude_polar, 'N'))
                        GGA.lat(index_GGA) = str2double(latitude(1:2)) + str2double(latitude(3:length(latitude)))/60;
                    else
                        GGA.lat(index_GGA) = -str2double(latitude(1:2)) - str2double(latitude(3:length(latitude)))/60;
                    end
                    
                    if (strcmp(longitude_polar, 'E'))
                        GGA.lon(index_GGA) = str2double(longitude(1:3)) + str2double(longitude(4:length(longitude)))/60;
                    else
                        GGA.lon(index_GGA) = -str2double(longitude(1:3)) - str2double(longitude(4:length(longitude)))/60;
                    end
                    
                    GGA.height(index_GGA)    = str2double(height_sea) + str2double(height_wgs);
                    GGA.pos_llh(index_GGA,1) = GGA.lat(index_GGA)*pi/180;
                    GGA.pos_llh(index_GGA,2) = GGA.lon(index_GGA)*pi/180;
                    GGA.pos_llh(index_GGA,3) = GGA.height(index_GGA);
                end
                
                isGGA = 0;
            end
        end
        %%
        pos_RMC = strfind(buffer, 'RMC');
        if (~isempty(pos_RMC))
            
            count           = 0;
            SOG        = [];
            TADT       = [];
            
            for i = pos_RMC:length(buffer)
                if(buffer(i) == ',')
                    count = count + 1;
                elseif (count == 7)
                    SOG = strcat(SOG, buffer(i));
                elseif (count == 8)
                    TADT = strcat(TADT, buffer(i));
                    
                    isRMC = 1;
                end
            end
            
            if (isRMC)
                index_RMC = index_RMC + 1;
                RMC.SOG(index_RMC)    = str2double(SOG);
                RMC.TADT(index_RMC)    = str2double(TADT);
                
                isRMC = 0;
            end
        end
        %%
    end
end

NMEA.GGA = GGA;
NMEA.RMC = RMC;

fclose(f_nmea);