% Set your Arduino serial port:
port = "COM7";  % Windows example
baud = 9600;

s = serialport(port, baud);
configureTerminator(s, "LF");

disp("Receiving bin distances from Arduino...");

binHeight = 10;   % cm (CHANGE THIS to actual bin model height)

while true
    try
        raw = readline(s);
        raw = strtrim(raw);
        disp(raw);

        % Split CSV "d1,d2,d3,d4"
        parts = split(raw, ",");

        if numel(parts) ~= 4
            warning("Invalid data: %s", raw);
            continue;
        end

        % Convert to numbers
        d1 = str2double(parts{1});
        d2 = str2double(parts{2});
        d3 = str2double(parts{3});
        d4 = str2double(parts{4});

        distances = [d1; d2; d3; d4];

        % Convert distances to fill %
        % Fill = more garbage = lower distance
        fillLevels = max(0, min(100, 100 * (1 - distances / binHeight)));

        % Simple prediction model (adjust later)
        timeToFull = (100 - fillLevels) / 5;

        % Build table-compatible structure
        appData.bins = [
            (1:4)', fillLevels, timeToFull
        ];

        save('appData.mat', 'appData');

    catch ME
        fprintf("ERROR: %s\n", ME.message);
    end

    pause(0.05);
end
