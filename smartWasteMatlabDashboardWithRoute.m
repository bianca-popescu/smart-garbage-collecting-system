function smartWasteMatlabDashboardWithRoute

% configuration
port = "COM4";           
baud = 9600;              
numBins = 4;              
binHeight = 8;            
pollPeriod = 1.0; % seconds between UI updates       
saveData = false;         
maxHistory = 200;         
collectThreshold = 70;    

% depot coordinates
depot = [0.5, -0.3];

% bin coordinates
binCoords = [ 
    2 4;  % bin 1
    1 2;  % bin 2
    2 1;  % bin 3
    1 1   % Bin 4
];

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

%% -------------------- CREATE UI --------------------
fig = uifigure('Name','Smart Waste Dashboard (TSP)','AutoResizeChildren','on');
fig.WindowState = 'maximized';  % full screen
fig.CloseRequestFcn = @onClose;

% Main grid: left visualization, right controls
mainGrid = uigridlayout(fig,[1 2]);
mainGrid.ColumnWidth = {'2.5x','1x'};
mainGrid.RowHeight   = {'1x'};

%% -------- LEFT PANEL (Visualization) --------
leftPanel = uipanel(mainGrid,'Title','Visualization');
leftGrid = uigridlayout(leftPanel,[2 1]);
leftGrid.RowHeight = {'2x','1x'};

% Map axes
mapAx = uiaxes(leftGrid);
mapAx.Title.String = 'Smart Waste City Map + Shortest Route';
mapAx.XLabel.String = 'X';
mapAx.YLabel.String = 'Y';
hold(mapAx,'on');

% Bar chart
barAx = uiaxes(leftGrid);
barAx.YLim = [0 100];
barPlot = bar(barAx, zeros(1,numBins),'FaceColor','flat');
barAx.XTick = 1:numBins;
barAx.Title.String = 'Bin Fill Levels (%)';

% Map markers
binMarkers = gobjects(1,numBins);
binLabels = gobjects(1,numBins);
for k=1:numBins
    binMarkers(k) = plot(mapAx, binCoords(k,1), binCoords(k,2), 'o', ...
        'MarkerSize', 18, 'MarkerFaceColor', [0.6 0.9 0.6], 'MarkerEdgeColor','k');
    binLabels(k) = text(mapAx, binCoords(k,1)+0.03, binCoords(k,2)+0.03, sprintf('Bin%d',k), 'FontWeight','bold');
end
depotMarker = plot(mapAx, depot(1), depot(2), 's', 'MarkerSize', 16, 'MarkerFaceColor', [0.2 0.6 1], 'MarkerEdgeColor','k');
text(mapAx, depot(1)+0.03, depot(2)+0.03, 'Depot','FontWeight','bold');

% Route line
routeLine = plot(mapAx, nan, nan, '-','LineWidth',2,'Color',[0.85 0.33 0.1]);

%% -------- RIGHT PANEL (Controls + Table + History) --------
rightPanel = uipanel(mainGrid,'Title','Controls & Table');
rightGrid = uigridlayout(rightPanel,[5 1]);
rightGrid.RowHeight = {80, 50, 100, 200, '1x'}; % port+status, buttons, threshold, table, log/history

% --- Port & Status info ---
infoGrid = uigridlayout(rightGrid,[1 3]);
lblPort = uilabel(infoGrid,'Text',['Port: ' char(port)]);
lblBaud = uilabel(infoGrid,'Text',['Baud: ' num2str(baud)]);
lblStatus = uilabel(infoGrid,'Text','Status: Stopped','FontColor',[0.5 0 0]);

% --- Start/Stop buttons ---
btnGrid = uigridlayout(rightGrid,[1 2]);
btnStart = uibutton(btnGrid,'push','Text','Start','ButtonPushedFcn',@(btn,event) startPolling());
btnStop  = uibutton(btnGrid,'push','Text','Stop','ButtonPushedFcn',@(btn,event) stopPolling());
btnStop.Enable = 'off';

% --- Threshold slider ---
threshGrid = uigridlayout(rightGrid,[1 3]);
lblThresh = uilabel(threshGrid,'Text','Collect Threshold (%)');
sldThresh = uislider(threshGrid,'Limits',[0 100],'Value',collectThreshold,'ValueChangedFcn',@(s,event) setThreshold(s.Value));
lblThreshVal = uilabel(threshGrid,'Text',sprintf('%d %%',collectThreshold));

% --- Table of current fill / predicted times ---
tbl = uitable(rightGrid);
tbl.ColumnName = {'Bin','Fill %','TimeToFull (h)'};
tbl.Data = table((1:numBins)', zeros(numBins,1), repmat({'n/a'},numBins,1));

% --- History axes ---
histAx = uiaxes(rightGrid);
histAx.Title.String = 'Last Fill History (per bin)';
histAx.YLim = [0 100];
histAx.XLabel.String = 'Samples (old → new)';

% --- Log area ---
logArea = uitextarea(rightGrid,'Editable','off');

%% -------------------- UI STRUCT --------------------
ui = struct('fig',fig,'barPlot',barPlot,'mapAx',mapAx,'mapMarkers',binMarkers,'mapLabels',binLabels, ...
            'depot',depotMarker,'routeLine',routeLine,'tbl',tbl,'histAx',histAx,'logArea',logArea, ...
            'lblStatus',lblStatus,'lblThreshVal',lblThreshVal);

writeLog('UI ready. Click Start to begin reading!');

%% -------------------- TIMER --------------------
t = timer('ExecutionMode','fixedRate','Period',pollPeriod,'TimerFcn',@onTimer,'BusyMode','drop');

%% -------------------- NESTED FUNCTIONS --------------------
function setThreshold(val)
    collectThreshold = round(val);
    ui.lblThreshVal.Text = sprintf('%d %%', collectThreshold);
    writeLog(sprintf('Collect threshold set to %d%%', collectThreshold));
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
        fill = min(max(100*(1 - distances/state.binHeight),0),100);
        ts = datetime('now');

        % Push to history
        for k=1:state.numBins
            hist = state.history{k};
            hist = [hist; struct('t',ts,'fill',fill(k))];
            if length(hist) > state.maxHistory, hist = hist(end-state.maxHistory+1:end); end
            state.history{k} = hist;
        end

        % Predict time to full
        timeToFull = nan(state.numBins,1);
        for k=1:state.numBins
            H = state.history{k};
            if numel(H) < 3, continue; end
            times = seconds([H.t]-H(1).t)/3600;
            levels = [H.fill]';
            p = polyfit(times, levels,1);
            slope = p(1); intercept = p(2);
            if slope <=0, timeToFull(k)=Inf; else
                t_full_from_start=(100-intercept)/slope;
                now_h=seconds(H(end).t-H(1).t)/3600;
                timeToFull(k)=t_full_from_start-now_h;
            end
        end

        updateUI(fill,timeToFull,distances);
        if state.saveData
            appData = struct();
            appData.bins = table((1:state.numBins)',fill',timeToFull,'VariableNames',{'Bin','Fill','TimeToFull_hr'});
            appData.timestamp=ts;
            save('appData.mat','appData');
        end

    catch ME
        writeLog(['ERROR (onTimer): ' ME.message]);
    end
end

function updateUI(fill,timeToFull,~)
    % Bar chart
    ui.barPlot.YData = fill;
    for k=1:state.numBins, ui.barPlot.CData(k,:) = fillColor(fill(k)); end
    barAx.Title.String = sprintf('Bin Fill Levels (last update %s)', datestr(datetime('now'),'HH:MM:SS'));

    % History
    cla(ui.histAx); hold(ui.histAx,'on');
    for k=1:state.numBins
        H=state.history{k};
        if isempty(H), continue; end
        plot(ui.histAx,1:numel([H.fill]),[H.fill],'-o','DisplayName',sprintf('Bin %d',k));
    end
    hold(ui.histAx,'off'); legend(ui.histAx,'Location','northeastoutside');

    % Table
    T = table((1:state.numBins)',fill', repmat({''},state.numBins,1),'VariableNames',{'Bin','Fill','TimeToFull'});
    for k=1:state.numBins
        if isfinite(timeToFull(k))
            if timeToFull(k)<0, T.TimeToFull{k}='<0h';
            else T.TimeToFull{k}=sprintf('%.2f h',timeToFull(k)); end
        else T.TimeToFull{k}='n/a';
        end
    end
    ui.tbl.Data=T;

    % Map markers
    for k=1:state.numBins
        c=fillColor(fill(k));
        set(ui.mapMarkers(k),'MarkerFaceColor',c,'MarkerEdgeColor','k','MarkerSize', max(8,6+round(fill(k)/10)));
        set(ui.mapLabels(k),'String',sprintf('Bin%d (%.0f%%)',k,fill(k)));
    end

    % Compute route
    toCollectIdx=find(fill>=collectThreshold);
    if isempty(toCollectIdx)
        set(ui.routeLine,'XData',nan,'YData',nan);
        writeLog('No bins exceed collect threshold; no route computed.');
    else
        selectedCoords=binCoords(toCollectIdx,:);
        bestRouteIdx=tsp_bruteforce(depot,selectedCoords);
        routePts=[depot; selectedCoords(bestRouteIdx,:); depot];
        set(ui.routeLine,'XData',routePts(:,1),'YData',routePts(:,2));

        % Annotate order
        delete(findall(ui.mapAx,'Tag','orderText'));
        for idx=1:length(bestRouteIdx)
            binGlobalIdx = toCollectIdx(bestRouteIdx(idx));
            pos = binCoords(binGlobalIdx,:);
            text(ui.mapAx,pos(1)-0.05,pos(2)-0.07,sprintf('%d',idx),'FontWeight','bold','Color','k','BackgroundColor','w','Tag','orderText');
        end
        writeLog(sprintf('Route computed visiting bins: %s', mat2str(toCollectIdx(bestRouteIdx))));
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
