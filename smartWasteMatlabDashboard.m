% smartWasteMatlabDashboard.m
% Single-file MATLAB dashboard: reads CSV distances from Arduino over serial,
% computes fill levels, simple prediction, and displays a live UI (bars + table).
%
% Usage:
%  - Edit 'port' and 'baud' variables below
%  - Run: smartWasteMatlabDashboard
%
% Notes:
%  - Arduino must output lines like: "6.95,6.43,2.21,4.21" terminated by newline.
%  - This app uses a single serial connection in this MATLAB session (no conflicts).
%  - Press Stop or close the window to clean up resources.

function smartWasteMatlabDashboard

% ----------------------- USER CONFIG -----------------------
port = "COM4";            % <-- change to your Arduino serial port
baud = 9600;              % must match Arduino
numBins = 4;              % number of sensors/bins in CSV
binHeight = 8;           % cm - change to actual bin height (for fill% calc)
pollPeriod = 1.0;         % seconds between serial polls / UI updates
saveData = true;          % set to true to save 'appData.mat' periodically
maxHistory = 200;         % how many recent samples to keep (per bin)
% -----------------------------------------------------------

% Internal state
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

% storage: cell array per bin of (timestamp, fill)
state.history = cell(1, numBins);
for i=1:numBins, state.history{i} = []; end

% Create UI
fig = uifigure('Name','Smart Waste Dashboard','Position',[200 200 900 560]);
fig.CloseRequestFcn = @onClose;

% Layout panels
leftPanel  = uipanel(fig,'Position',[10 10 540 540],'Title','Visualization');
rightPanel = uipanel(fig,'Position',[560 10 330 540],'Title','Controls & Table');

% Axes for bar chartss
ax = uiaxes(leftPanel,'Position',[20 180 500 330]);
ax.YLim = [0 100];
barPlot = bar(ax, zeros(1,numBins),'FaceColor','flat');
ax.Title.String = 'Bin Fill Levels (%)';
ax.XTick = 1:numBins;
ax.XLabel.String = 'Bin ID';
ax.YLabel.String = 'Fill (%)';
colormap(ax, summer);

% Small axes for prediction curves (optional)
ax2 = uiaxes(leftPanel,'Position',[20 20 500 140]);
ax2.Title.String = 'Last Fill History (per bin)';
ax2.YLim = [0 100];
ax2.XLabel.String = 'Samples (old → new)';

% Table
tbl = uitable(rightPanel,'Position',[10 160 310 360]);
tbl.ColumnName = {'Bin','Fill %','TimeToFull (h)'};
tbl.Data = table((1:numBins)', zeros(numBins,1), repmat({'n/a'},numBins,1));

% Controls
lblPort = uilabel(rightPanel,'Position',[10 120 140 22],'Text',['Port: ' char(port)]);
lblBaud = uilabel(rightPanel,'Position',[10 100 140 22],'Text',['Baud: ' num2str(baud)]);
lblInfo = uilabel(rightPanel,'Position',[10 75 310 20],'Text','Status: Stopped','FontColor',[0.5 0 0]);

btnStart = uibutton(rightPanel,'push','Text','Start','Position',[10 40 150 30],'ButtonPushedFcn',@(btn,event) startPolling());
btnStop  = uibutton(rightPanel,'push','Text','Stop','Position',[170 40 150 30],'ButtonPushedFcn',@(btn,event) stopPolling());
btnStop.Enable = 'off';

% Log area
logArea = uitextarea(rightPanel,'Position',[10 10 310 20],'Editable','off');

% Timer for polling
t = timer('ExecutionMode','fixedRate','Period',pollPeriod,'TimerFcn',@onTimer,'BusyMode','drop');

% Serial object handle (will be created on Start)
sp = []; 

% Make variables accessible in nested functions
ui = struct('fig',fig,'ax',ax,'ax2',ax2,'barPlot',barPlot,'tbl',tbl,'lblInfo',lblInfo,'logArea',logArea);

% -------------------- Nested functions --------------------

function startPolling()
    if state.running
        return;
    end
    % Open serial
    try
        if isempty(port)
            errordlg('Serial port not specified.');
            return;
        end
        % If an old sp exists, clear it first
        if ~isempty(sp) && isvalid(sp)
            clearSerial(sp);
        end
        sp = serialport(state.port, state.baud, 'Timeout', 1);
        configureTerminator(sp, "LF");
        flush(sp);
    catch ME
        errordlg(sprintf('Failed to open serial port %s: %s', char(state.port), ME.message));
        return;
    end

    state.running = true;
    ui.lblInfo.Text = sprintf('Status: Running (port %s)', char(state.port));
    btnStart.Enable = 'off';
    btnStop.Enable = 'on';
    start(t);
    writeLog(sprintf('Started polling %s @ %d baud', char(state.port), state.baud));
end

function stopPolling()
    if ~state.running
        return;
    end
    state.running = false;
    try
        stop(t);
    catch
    end
    if ~isempty(sp) && isvalid(sp)
        clearSerial(sp);
    end
    ui.lblInfo.Text = 'Status: Stopped';
    btnStart.Enable = 'on';
    btnStop.Enable = 'off';
    writeLog('Stopped polling.');
end

function onTimer(~,~)
    % Called by timer. Non-blocking. Read one line if available.
    if isempty(sp) || ~isvalid(sp)
        writeLog('Serial port not open.');
        return;
    end
    try
        if sp.NumBytesAvailable == 0
            return;
        end
        raw = readline(sp);
        raw = strtrim(raw);
        if isempty(raw)
            return;
        end
        writeLog(['RX: ' raw]);
        parts = split(raw, ',');
        if numel(parts) < state.numBins
            writeLog(['Malformed line (wrong number of fields): ' raw]);
            return;
        end

        % Parse up to numBins values
        distances = zeros(1, state.numBins);
        for k=1:state.numBins
            distances(k) = str2double(parts{k});
        end

        % convert distances (cm) to fill %
        fill = 100 * (1 - distances / state.binHeight);
        fill = min(max(fill,0),100);  % clamp

        % timestamp
        ts = datetime('now');

        % push to history
        for k=1:state.numBins
            hist = state.history{k};
            hist = [hist; struct('t',ts,'fill',fill(k))];
            % trim
            if length(hist) > state.maxHistory
                hist = hist(end-state.maxHistory+1:end);
            end
            state.history{k} = hist;
        end

        % prediction: simple linear fit on last N samples per bin
        timeToFull = nan(state.numBins,1);
        for k=1:state.numBins
            H = state.history{k};
            if numel(H) < 3
                timeToFull(k) = NaN;
                continue;
            end
            times = seconds([H.t] - H(1).t) / 3600; % hours from first sample
            levels = [H.fill]';
            p = polyfit(times, levels, 1); % slope (%%/hour), intercept
            slope = p(1);
            intercept = p(2);
            if slope <= 0
                timeToFull(k) = Inf; % not filling
            else
                % Solve intercept + slope * t_full = 100 -> t_full (hours from start)
                t_full_from_start = (100 - intercept) / slope;
                % Current time since start
                now_h = seconds(H(end).t - H(1).t) / 3600;
                timeToFull(k) = t_full_from_start - now_h; % hours from now
            end
        end

        % Update UI visuals (must run on main thread; timer runs in MATLAB thread already)
        updateUI(fill, timeToFull);

        % Save appData optionally
        if state.saveData
            appData = struct();
            appData.bins = table((1:state.numBins)', fill', timeToFull, 'VariableNames', {'Bin','Fill','TimeToFull_hr'});
            appData.timestamp = ts;
            save('appData.mat','appData');
        end

    catch ME
        writeLog(['ERROR (onTimer): ' ME.message]);
    end
end

function updateUI(fill, timeToFull)
    % update bar chart
    ui.barPlot.YData = fill;
    % color mapping according to fill
    for k=1:state.numBins
        c = fillColor(fill(k));
        ui.barPlot.CData(k,:) = c;
    end
    ax.Title.String = sprintf('Bin Fill Levels (last update %s)', datestr(datetime('now'),'HH:MM:SS'));

    % update history plot (ax2) - plot the last N samples for each bin as lines
    cla(ui.ax2);
    hold(ui.ax2,'on');
    for k=1:state.numBins
        H = state.history{k};
        if isempty(H), continue; end
        vals = [H.fill];
        x = 1:numel(vals);
        plot(ui.ax2, x, vals, '-o', 'DisplayName', sprintf('Bin %d',k));
    end
    hold(ui.ax2,'off');
    legend(ui.ax2,'Location','northeastoutside');

    % update table
    T = table((1:state.numBins)', fill', cell(state.numBins,1), 'VariableNames', {'Bin','Fill','TimeToFull'});
    for k=1:state.numBins
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
end

function c = fillColor(fillVal)
    % return RGB color for fill value (green=low, red=high)
    % Normalize 0..100 -> 0..1
    v = min(max(fillVal,0),100)/100;
    % gradient: green -> yellow -> red
    if v < 0.5
        % green -> yellow
        c = [ (2*v), 1, 0 ];
    else
        % yellow -> red
        c = [ 1, (1 - 2*(v-0.5)), 0 ];
    end
    c = max(min(c,1),0);
end

function writeLog(msg)
    tstr = datestr(datetime('now'),'HH:MM:SS');
    prev = ui.logArea.Value;
    if iscell(prev)
        new = [{sprintf('[%s] %s', tstr, msg)}; prev];
    else
        new = {sprintf('[%s] %s', tstr, msg); prev};
    end
    % keep max 20 lines
    if numel(new) > 20, new = new(1:20); end
    ui.logArea.Value = new;
end

function clearSerial(s)
    try
        flush(s);
    catch
    end
    try
        clear s;  % releases the serialport object
    catch
        % if it's a variable in workspace, try delete
        try delete(s); end
    end
end

function onClose(src, ~)
    % Clean up timer & serial
    try
        stop(t);
    catch
    end
    try
        delete(t);
    catch
    end
    if ~isempty(sp) && isvalid(sp)
        try clearSerial(sp); end
    end
    delete(src);
end

% At this point, we only create UI. Start button triggers serial open & timer.
writeLog('UI ready. Click Start to begin reading Arduino.');
end
