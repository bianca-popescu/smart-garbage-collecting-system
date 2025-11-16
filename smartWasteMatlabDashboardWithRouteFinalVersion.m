function smartWasteMatlabDashboardWithRouteFinalVersion

% configuration
port = "COM4";           
baud = 9600;              
numBins = 4;              
binHeight = 8;            
pollPeriod = 1.0; % seconds between UI updates       
saveData = false;         
maxHistory = 200;         
collectThreshold = "HIGH"; %default   
 
% depot coordinates
depot = [0.5, 4];

% bin coordinates
binCoords = [ 
    2 4;  % bin 1
    1 2;  % bin 2
    2 1;  % bin 3
    1 1   % Bin 4
];

% city coordinates (range)
cityX = [0 5];   
cityY = [0 7.5];   

LOW_LEVEL = 5;
MID_LEVEL = 4;
HIGH_LEVEL = 3;
% FULL_LEVEL = 2.5;

% converting distance read to level
function level = distanceToLevel(distance)

    if distance > LOW_LEVEL
        level = "LOW";

    elseif distance > MID_LEVEL
        level = "MID";

    elseif distance > HIGH_LEVEL
        level = "HIGH";

    else
        level = "FULL";
    end

end

% state
state = struct();
state.port = port;
state.baud = baud;
state.numBins = numBins;
state.binHeight = binHeight;
state.pollPeriod = pollPeriod;
state.saveData = saveData;
state.maxHistory = maxHistory;
state.running = false;
state.startTime = datetime('now');
state.history = cell(1,numBins);

for i=1:numBins, state.history{i} = []; end

sp = []; % serial handle

% UI
fig = uifigure('Name','Smart Garbage Collecting System Dashboard','AutoResizeChildren','on');
fig.WindowState = 'maximized';  % full screen
fig.CloseRequestFcn = @onClose;

% main grid: left visualization, right controls
mainGrid = uigridlayout(fig,[1 2]);
mainGrid.ColumnWidth = {'2x','1x'};
mainGrid.RowHeight   = {'1x'};

% left panel
leftPanel = uipanel(mainGrid,'Title','Visualization');
leftGrid = uigridlayout(leftPanel,[2 1]);
leftGrid.RowHeight = {'2x','1x'};

% map axes
mapAx = uiaxes(leftGrid);
mapAx.Title.String = 'City Map';
mapAx.XLabel.String = 'X';
mapAx.YLabel.String = 'Y';
hold(mapAx,'on');

mapAx.XLim = cityX;
mapAx.YLim = cityY;
mapAx.XTick = linspace(cityX(1),cityX(2),5); 
mapAx.YTick = linspace(cityY(1),cityY(2),5);
axis(mapAx,'equal'); 

% bar chart
barAx = uiaxes(leftGrid);
barAx.YLim = [0 100];
barPlot = bar(barAx, zeros(1,numBins),'FaceColor','flat');
barAx.XTick = 1:numBins;
barAx.Title.String = 'Bin Fill Levels (level)';

colors = [
    1 0 0;    
    0 1 0;  
    0 0 1;    
    1 1 0   
];

barPlot.CData = colors;

% map markers
binMarkers = gobjects(1,numBins);
binLabels = gobjects(1,numBins);

binMarkers(1) = plot(mapAx, binCoords(1,1), binCoords(1,2), 'o', 'MarkerSize', 14, 'MarkerFaceColor', [1, 0, 0], 'MarkerEdgeColor','k');
binLabels(1) = text(mapAx, binCoords(1,1)-0.25, binCoords(1,2)-0.35, sprintf('Bin %d',1), 'FontWeight','bold');

binMarkers(2) = plot(mapAx, binCoords(2,1), binCoords(2,2), 'o', 'MarkerSize', 14, 'MarkerFaceColor', [0, 1, 0], 'MarkerEdgeColor','k');
binLabels(2) = text(mapAx, binCoords(2,1)-0.25, binCoords(2,2)-0.35, sprintf('Bin %d',2), 'FontWeight','bold');

binMarkers(3) = plot(mapAx, binCoords(3,1), binCoords(3,2), 'o', 'MarkerSize', 14, 'MarkerFaceColor', [0, 0, 1], 'MarkerEdgeColor','k');
binLabels(3) = text(mapAx, binCoords(3,1)-0.25, binCoords(3,2)-0.35, sprintf('Bin %d',3), 'FontWeight','bold');

binMarkers(4) = plot(mapAx, binCoords(4,1), binCoords(4,2), 'o', 'MarkerSize', 14, 'MarkerFaceColor', [1, 1, 0], 'MarkerEdgeColor','k');
binLabels(4) = text(mapAx, binCoords(4,1)-0.25, binCoords(4,2)-0.35, sprintf('Bin %d',4), 'FontWeight','bold');

depotMarker = plot(mapAx, depot(1), depot(2), 's', 'MarkerSize', 16, 'MarkerFaceColor', [1 1 1], 'MarkerEdgeColor','k');
text(mapAx, depot(1)-0.35, depot(2)-0.3, 'Depot','FontWeight','bold');

% route line
routeLine = plot(mapAx, nan, nan, '-','LineWidth',3,'Color',[1 1 1]);
% RIGHT PANEL
rightPanel = uipanel(mainGrid,'Title','Controls & Table');
rightGrid = uigridlayout(rightPanel,[5 1]);
rightGrid.RowHeight = {80, 50, 80, 200, '1x'}; 
% rows: 1) port/status, 2) start/stop buttons, 3) threshold dropdown, 4) table, 5) log/history

% 1) Port & Status Info
infoGrid = uigridlayout(rightGrid,[1 3]);
lblPort = uilabel(infoGrid,'Text',['Port: ' char(port)]);
lblBaud = uilabel(infoGrid,'Text',['Baud: ' num2str(baud)]);
lblStatus = uilabel(infoGrid,'Text','Status: Stopped','FontColor',[0.5 0 0]);

% 2) Start/Stop Buttons
btnGrid = uigridlayout(rightGrid,[1 2]);
btnStart = uibutton(btnGrid,'push','Text','Start','ButtonPushedFcn',@(btn,event) startPolling());
btnStop  = uibutton(btnGrid,'push','Text','Stop','ButtonPushedFcn',@(btn,event) stopPolling());
btnStop.Enable = 'off';

% 3) Threshold Dropdown
threshPanel = uigridlayout(rightGrid,[1 2]);
threshPanel.ColumnWidth = {'1x','1x'};
lblThresh = uilabel(threshPanel,'Text','Collect Threshold (level)');
ddlThresh = uidropdown(threshPanel, ...
    'Items', ["LOW","MID","HIGH","FULL"], ...
    'Value', "HIGH", ...
    'ValueChangedFcn', @(ddl,event) setThreshold(ddl.Value));
lblThreshVal = uilabel(threshPanel,'Text',ddlThresh.Value);

% 4) Table of Current Fill / Predicted Time

tbl = uitable(rightGrid);
tbl.ColumnName = {'Bin','Fill Level','Predicted Time to Full'};
tbl.Data = table((1:numBins)', repmat({''},numBins,1), repmat({'n/a'},numBins,1),'VariableNames', {'Bin','FillLevel','TimeToFull'});

% 5) History Axes
histAx = uiaxes(rightGrid);
histAx.Title.String = 'Last fill history (per bin)';
histAx.YLim = [0 100];
histAx.XLabel.String = 'Samples (old -> new)';

% 6) Log Area
logArea = uitextarea(rightGrid,'Editable','off'); 

% UI structure
ui = struct('fig',fig,'barPlot',barPlot,'mapAx',mapAx,'mapMarkers',binMarkers,'mapLabels',binLabels, ...
            'depot',depotMarker,'routeLine',routeLine,'tbl',tbl,'histAx',histAx,'logArea',logArea, ...
            'lblStatus',lblStatus,'lblThreshVal',lblThreshVal);

writeLog('UI ready. Click Start to begin reading! :)');

% timer
t = timer('ExecutionMode','fixedRate','Period',pollPeriod,'TimerFcn',@onTimer,'BusyMode','drop');

% nested functions
function setThreshold(val)
    collectThreshold = val;  % store as string
    ui.lblThreshVal.Text = val;
    writeLog(sprintf('Collect threshold set to %s', val));
end

function startPolling()
    if state.running, return; end
    try
        if isempty(port), errordlg('Serial port not specified.'); return; end
        if ~isempty(sp) && isvalid(sp), clearSerial(sp); end
        sp = serialport(state.port, state.baud, 'Timeout',1);
        configureTerminator(sp,"LF");
        flush(sp);
    catch ME
        errordlg(sprintf('Failed to open serial port %s: %s', char(state.port), ME.message));
        return;
    end
    state.running = true;
    ui.lblStatus.Text = sprintf('Status: Running (port %s)', char(state.port));
    btnStart.Enable = 'off';
    btnStop.Enable = 'on';
    start(t);
    writeLog(sprintf('Started polling %s @ %d baud', char(state.port), state.baud));
end

function stopPolling()
    if ~state.running, return; end
    state.running = false;
    try stop(t); catch end
    if ~isempty(sp) && isvalid(sp), clearSerial(sp); end
    ui.lblStatus.Text = 'Status: Stopped';
    btnStart.Enable = 'on';
    btnStop.Enable = 'off';
    writeLog('Stopped polling.');
end

function onTimer(~,~)
    if isempty(sp) || ~isvalid(sp), writeLog('Serial port not open.'); return; end
    try
        if sp.NumBytesAvailable == 0, return; end
        raw = strtrim(readline(sp));
        if isempty(raw), return; end
        writeLog(['RX: ' raw]);
        parts = split(raw,',');
        if numel(parts) < state.numBins
            writeLog(['Malformed line: ' raw]);
            return;
        end
        distances = zeros(1,state.numBins);
        for k=1:state.numBins, distances(k) = str2double(parts{k}); end

        levels = strings(1, state.numBins);
    
        % update distance levels based on readings
        for k = 1:state.numBins
             levels(k) = distanceToLevel(distances(k));
        end

        ts = datetime('now');

        % push to history
        for k=1:state.numBins
            hist = state.history{k};
            switch levels(k)
                case "LOW",  lvlVal = 25;
                case "MID",  lvlVal = 50;
                case "HIGH", lvlVal = 75;
                case "FULL", lvlVal = 100;
            end

        hist = [hist; struct('t',ts,'level',levels(k),'val',lvlVal)];
            if length(hist) > state.maxHistory, hist = hist(end-state.maxHistory+1:end); end
            state.history{k} = hist;
        end

        % predict time to full
        timeToFull = nan(state.numBins,1);
        for k=1:state.numBins
            H = state.history{k};
            if numel(H) < 3, continue; end
            times = seconds([H.t]-H(1).t)/3600;

            histLevels = {H.level}';
            vals = [H.val]';

            p = polyfit(times, vals, 1);  % numeric now

            slope = p(1);
            intercept = p(2);
            
            if slope <=0, timeToFull(k)=Inf; else
                t_full_from_start=(100-intercept)/slope;
                now_h=seconds(H(end).t-H(1).t)/3600;
                timeToFull(k)=t_full_from_start-now_h;
            end
        end

        updateUI(levels,timeToFull);

    catch ME
        writeLog(['ERROR (onTimer): ' ME.message]);
    end
end

function updateUI(levels, timeToFull)

   % Convert current LEVELS → numeric (for bar chart)
    barValues = zeros(1, state.numBins);
    for k = 1:state.numBins
        switch levels(k)
            case "LOW",  barValues(k) = 25;
            case "MID",  barValues(k) = 50;
            case "HIGH", barValues(k) = 75;
            case "FULL", barValues(k) = 100;
        end
    end


    % =======================
    % 1) BAR CHART UPDATE
    % =======================

    ui.barPlot.YData = barValues;
    for k=1:state.numBins
        ui.barPlot.CData(k,:) = fillColor(barValues(k));
    end
    ui.barPlot.Parent.Title.String = sprintf('Bin Fill Levels (last update %s)', ...
                        datestr(datetime('now'),'HH:MM:SS'));


    % =======================
    % 2) HISTORY GRAPH UPDATE
    % =======================
    cla(ui.histAx);
    hold(ui.histAx,'on');

    spacing = 2;
    colors = [1 0 0; 0 1 0; 0 0 1; 1 1 0];  % red, green, blue, yellow

    for k = 1:state.numBins
        H = state.history{k};
        if isempty(H), continue; end

        % convert stored history levels → numeric values
        vals = zeros(1,length(H));
        for i = 1:length(H)
           vals(i) = H(i).val;
        end

        x = (1:numel(vals)) * spacing;

        plot(ui.histAx, x, vals, 'o', ...
            'Color', colors(k,:), ...
            'MarkerFaceColor', colors(k,:), ...
            'LineWidth', 2, ...
            'DisplayName', sprintf('Bin %d', k));
    end


    hold(ui.histAx,'off');
    legend(ui.histAx,'Location','northeastoutside');


    % =======================
    % 3) TABLE UPDATE
    % =======================
    T = table((1:state.numBins)', cellstr(levels'), repmat({''},state.numBins,1), ...
              'VariableNames', {'Bin','FillLevel','TimeToFull'});

    for k = 1:state.numBins
        if isfinite(timeToFull(k))
            if timeToFull(k) < 0
                T.TimeToFull{k} = '<0h';
            else
                T.TimeToFull{k} = sprintf('%.2f h', timeToFull(k));
            end
        else
            T.TimeToFull{k} = 'n/a';
        end
    end

    ui.tbl.Data = T;


    % =======================
    % 4) MAP MARKER COLORS
    % =======================
    colorMap = containers.Map(["LOW","MID","HIGH","FULL"], ...
                              {[0 1 0], [1 1 0], [1 0.5 0], [1 0 0]}); % green→red

    for k=1:state.numBins
        c = colorMap(levels(k));
        set(ui.mapMarkers(k), 'MarkerFaceColor', c, 'MarkerEdgeColor', 'k');
        set(ui.mapLabels(k), 'String', sprintf('Bin %d (%s)', k, levels(k)));
    end


    % =======================
    % 5) ROUTE COMPUTATION
    % =======================
    levelOrder = ["LOW","MID","HIGH","FULL"];
    thresholdIdx = find(levelOrder == collectThreshold);

    toCollectIdx = [];

    for k = 1:state.numBins
        binIdx = find(levelOrder == levels(k));
        if binIdx >= thresholdIdx
            toCollectIdx(end+1) = k;
        end
    end

    if isempty(toCollectIdx)
        set(ui.routeLine, 'XData', nan, 'YData', nan);
        writeLog('No bins exceed collect threshold; no route computed.');
    else
        selectedCoords = binCoords(toCollectIdx,:);
        bestRouteIdx = tsp_bruteforce(depot, selectedCoords);
        routePts = [depot; selectedCoords(bestRouteIdx,:); depot];

        set(ui.routeLine, 'XData', routePts(:,1), 'YData', routePts(:,2));

        % annotate order
        delete(findall(ui.mapAx,'Tag','orderText'));
        for idx = 1:length(bestRouteIdx)
            binGlobalIdx = toCollectIdx(bestRouteIdx(idx));
            pos = binCoords(binGlobalIdx,:);
            text(ui.mapAx, pos(1)-0.05, pos(2)-0.07, sprintf('%d',idx), ...
                'FontWeight','bold', 'Color','k','BackgroundColor','w','Tag','orderText');
        end

        writeLog(sprintf('Route computed visiting: %s', mat2str(toCollectIdx(bestRouteIdx))));
    end

    drawnow;
end

function idxOrder = tsp_bruteforce(depotPoint, coords)
    M=size(coords,1);
    if M==0, idxOrder=[]; return; elseif M==1, idxOrder=1; return; end
    permMat=perms(1:M);
    bestCost=inf; bestIdx=[];
    for r=1:size(permMat,1)
        perm=permMat(r,:);
        total=0; prev=depotPoint;
        for j=1:M, cur=coords(perm(j),:); total=total+norm(cur-prev); prev=cur; end
        total=total+norm(depotPoint-prev);
        if total<bestCost, bestCost=total; bestIdx=perm; end
    end
    idxOrder=bestIdx;
end

function c = fillColor(fillVal)
    v=min(max(fillVal,0),100)/100;
    if v<0.5, c=[2*v,1,0]; else c=[1,1-2*(v-0.5),0]; end
    c=max(min(c,1),0);
end

function writeLog(msg)
    tstr=datestr(datetime('now'),'HH:MM:SS');
    prev=ui.logArea.Value;
    entry=sprintf('[%s] %s',tstr,msg);
    if iscell(prev), new=[{entry};prev]; else new={entry;prev}; end
    if numel(new)>40, new=new(1:40); end
    ui.logArea.Value=new;
end

function clearSerial(s)
    try flush(s); catch end
    try clear s; catch end
end

function onClose(src,~)
    try stop(t); catch end
    try delete(t); catch end
    if ~isempty(sp) && isvalid(sp), clearSerial(sp); end
    delete(src);
end
end