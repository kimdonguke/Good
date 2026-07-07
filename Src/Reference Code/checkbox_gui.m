function checkbox_gui(ntrip_mp,rts_1,rts_2,rts_3)

%% Format
Format_1 = find(contains(ntrip_mp.Format,"BINEX"));                                 % 1: BINEX
Format_2 = find(contains(ntrip_mp.Format,"RTCM 2"));                                % 2: RTCM 2.3
Format_3 = find(contains(ntrip_mp.Format,"RTCM 3"));                                % 3: RTCM 3.0 이상
Format_4 = find(contains(ntrip_mp.Format,"RTK"));                                   % 4: RTK

%% Nav-System
Navsys_1 = find(ntrip_mp.("Nav-System") == "GPS+GLONASS");                          % 1: GPS+GLONASS
Navsys_2 = find(ntrip_mp.("Nav-System") == "GPS+GLONASS+BEIDOU+GALILEO+QZSS" | ...
                ntrip_mp.("Nav-System") == "GPS+GLO+GAL+BDS+QZS" | ...
                ntrip_mp.("Nav-System") == "GPS+GLONASS+Galileo+Beidou+QZSS");      % 2: GPS+GLO+GAL+BDS+QZS
Navsys_3 = find(ntrip_mp.("Nav-System") == "DGPS");                                 % 3: DGPS
Navsys_4 = find(ntrip_mp.("Nav-System") == "DGPS+RTK");                             % 4: DGPS+RTK
Navsys_5 = find(ntrip_mp.("Nav-System") == "RTK");                                  % 5: RTK
Navsys_6 = find(ntrip_mp.("Nav-System") == "S+GLONASS");                            % 6: S+GLONASS

%% GUI settings
fig = figure('Position', [100,100,1600,800], 'Name', 'Select Options', 'NumberTitle', 'off');

% RTS 체크박스 (rts_1 ~ rts_3)
uicontrol('Style', 'checkbox', 'String', 'RTS1', 'Position', [50, 700, 50, 30], 'Tag', 'rts_1', 'Callback', @checkbox_callback);
uicontrol('Style', 'checkbox', 'String', 'RTS2', 'Position', [50, 660, 50, 30], 'Tag', 'rts_2', 'Callback', @checkbox_callback);
uicontrol('Style', 'checkbox', 'String', 'RTS3', 'Position', [50, 620, 50, 30], 'Tag', 'rts_3', 'Callback', @checkbox_callback);

annotation(fig,'textbox',...
    [0.015, 0.75 0.125 0.2],'String','RTS Network',...
    'FontWeight','bold',...
    'FontSize',14,...
    'FitBoxToText','off');

% Format 체크박스 (Format_1 ~ Format_4)
uicontrol('Style', 'checkbox', 'String', 'BINEX', 'Position', [50, 520, 70, 30], 'Tag', 'Format_1', 'Callback', @checkbox_callback);
uicontrol('Style', 'checkbox', 'String', 'RTCM v2', 'Position', [50, 480, 70, 30], 'Tag', 'Format_2', 'Callback', @checkbox_callback);
uicontrol('Style', 'checkbox', 'String', 'RTCM v3', 'Position', [50, 440, 70, 30], 'Tag', 'Format_3', 'Callback', @checkbox_callback);
uicontrol('Style', 'checkbox', 'String', 'RTK', 'Position', [50, 400, 70, 30], 'Tag', 'Format_4', 'Callback', @checkbox_callback);

annotation(fig,'textbox',...
    [0.015, 0.47625 0.125 0.25],'String','Format',...
    'FontWeight','bold',...
    'FontSize',14,...
    'FitBoxToText','off');

% Navsys 체크박스 (Navsys_1 ~ Navsys_6)
uicontrol('Style', 'checkbox', 'String', 'GPS+GLO', 'Position', [50, 300, 160, 30], 'Tag', 'Navsys_1', 'Callback', @checkbox_callback);
uicontrol('Style', 'checkbox', 'String', 'GPS+GLO+GAL+BDS+QZS', 'Position', [50, 260, 160, 30], 'Tag', 'Navsys_2', 'Callback', @checkbox_callback);
uicontrol('Style', 'checkbox', 'String', 'DGPS', 'Position', [50, 220, 160, 30], 'Tag', 'Navsys_3', 'Callback', @checkbox_callback);
uicontrol('Style', 'checkbox', 'String', 'DGPS+RTK', 'Position', [50, 180, 160, 30], 'Tag', 'Navsys_4', 'Callback', @checkbox_callback);
uicontrol('Style', 'checkbox', 'String', 'RTK', 'Position', [50, 140, 160, 30], 'Tag', 'Navsys_5', 'Callback', @checkbox_callback);
uicontrol('Style', 'checkbox', 'String', 'S+GLONASS', 'Position', [50, 100, 160, 30], 'Tag', 'Navsys_6', 'Callback', @checkbox_callback);

annotation(fig,'textbox',...
    [0.015 0.1 0.125 0.35],'String','Nav-System',...
    'FontWeight','bold',...
    'FontSize',14,...
    'FitBoxToText','off');

%% textbox
annotation(fig,'textbox',[0.696875 0.09875 0.271875 0.85125],...
    'FitBoxToText','off',...
    'BackgroundColor',[1 1 1]);

%% fig
ax = axes('Parent', fig, 'Position', [0.1, 0.1, 0.65, 0.85]);
plotHandles = struct();
grid(ax, 'on');
hold(ax, 'on');
box(ax, 'on');
set(ax,'Color','none');
axis(ax,'square');
limit_axis = [124,132,33,39];

    function checkbox_callback(~, ~)

        % select RTS 1 ~ 3
        for i = 1:3
            checkbox = findobj(fig, 'Tag', sprintf('rts_%d', i));
            if checkbox.Value
                if ~isfield(plotHandles, sprintf('rts_%d', i))

                    if(i == 1)
                        plotHandles.(sprintf('rts_%d', i)) = mapshow(ax,eval(sprintf('rts_%d', i)),'FaceColor','red','FaceAlpha',0.2);
                        axis(ax,limit_axis);

                    elseif(i == 2)
                        plotHandles.(sprintf('rts_%d', i)) = mapshow(ax,eval(sprintf('rts_%d', i)),'FaceColor','green','FaceAlpha',0.2);
                        axis(ax,limit_axis);

                    elseif(i == 3)
                        plotHandles.(sprintf('rts_%d', i)) = mapshow(ax,eval(sprintf('rts_%d', i)),'FaceColor','blue','FaceAlpha',0.2);
                        axis(ax,limit_axis);

                    end

                end
            else
                if isfield(plotHandles, sprintf('rts_%d', i)) && ishandle(plotHandles.(sprintf('rts_%d', i)))
                    delete(plotHandles.(sprintf('rts_%d', i)));
                    plotHandles = rmfield(plotHandles, sprintf('rts_%d', i));
                end
            end
        end

        % select format 1 ~ 4
        for i = 1:4
            checkbox = findobj(fig, 'Tag', sprintf('Format_%d', i));
            if checkbox.Value
                if ~isfield(plotHandles, sprintf('Format_%d', i))
                    plotHandles.(sprintf('Format_%d', i)) = plot(ax, ntrip_mp.Longitude(eval(sprintf('Format_%d',i))),ntrip_mp.Latitude(eval(sprintf('Format_%d',i))),'s','LineWidth',2,'Color','k','MarkerFaceColor','y','MarkerSize',10);
                    axis(ax,limit_axis);
                end
            else
                if isfield(plotHandles, sprintf('Format_%d', i)) && ishandle(plotHandles.(sprintf('Format_%d', i)))
                    delete(plotHandles.(sprintf('Format_%d', i)));
                    plotHandles = rmfield(plotHandles, sprintf('Format_%d', i));
                end
            end
        end

        %% select Navsys 1 ~ 6
        for i = 1:6
            checkbox = findobj(fig, 'Tag', sprintf('Navsys_%d', i));
            if checkbox.Value
                if ~isfield(plotHandles, sprintf('Navsys_%d', i))
                    plotHandles.(sprintf('Navsys_%d', i)) = plot(ax, ntrip_mp.Longitude(eval(sprintf('Navsys_%d',i))),ntrip_mp.Latitude(eval(sprintf('Navsys_%d',i))),'s','LineWidth',2,'Color','k','MarkerFaceColor','y','MarkerSize',10);
                    axis(ax,limit_axis);
                end
            else
                if isfield(plotHandles, sprintf('Navsys_%d', i)) && ishandle(plotHandles.(sprintf('Navsys_%d', i)))
                    delete(plotHandles.(sprintf('Navsys_%d', i)));
                    plotHandles = rmfield(plotHandles, sprintf('Navsys_%d', i));
                end
            end
        end


    end
end
