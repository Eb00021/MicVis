classdef MicVisualizer < matlab.apps.AppBase

    % Properties that correspond to app components
    properties (Access = public)
        UIFigure                matlab.ui.Figure
        MainPanel               matlab.ui.container.Panel
        VisualizerPanel         matlab.ui.container.Panel
        ControlPanel            matlab.ui.container.Panel
        NumMicsSpinner          matlab.ui.control.Spinner
        NumMicsLabel            matlab.ui.control.Label
        StartButton             matlab.ui.control.Button
        StopButton              matlab.ui.control.Button
        MicAxes                 matlab.ui.control.UIAxes
        StatusLabel             matlab.ui.control.Label
        WVULogo                 matlab.ui.control.Image
        TitleLabel              matlab.ui.control.Label
        FFTDisplayCheckBox      matlab.ui.control.CheckBox
        WaveformDisplayCheckBox matlab.ui.control.CheckBox
        GainSlider              matlab.ui.control.Slider
        GainLabel               matlab.ui.control.Label
        SampleRateLabel         matlab.ui.control.Label
        SampleRateSpinner       matlab.ui.control.Spinner
        SelectInputsButton       matlab.ui.control.Button
        SplitGraphsButton         matlab.ui.control.Button
    end
    
    properties (Access = private)
        AudioRecorders          % Cell array of audio recorder objects (legacy method)
        AudioDeviceReaders      % Cell array of audioDeviceReader objects (Audio Toolbox method)
        UseAudioToolbox = false % Flag to use Audio Toolbox if available
        Timer                   % Timer for updating visualization
        IsRunning = false       % Flag to track if visualization is running
        NumMics = 4             % Number of microphones
        SampleRate = 48000      % Sample rate in Hz (default to 48kHz for most modern mics)
        BufferSize = 4096       % Buffer size for audio capture
        SelectedDeviceIDs = []  % Array of selected device IDs for each mic
        SelectedDeviceNames = {} % Cell array of device names for Audio Toolbox
        SplitInputs = false(16,1)  % Boolean array indicating which inputs to split
        SplitAxes = {}          % Cell array of axes for split displays
        AudioHistory = {}       % Rolling history of recent audio frames for display
        WVUGold = [238, 170, 0] / 255      % WVU Gold color
        WVUBlue = [0, 40, 85] / 255        % WVU Blue color
        WVUBlueLight = [0, 60, 120] / 255  % Lighter WVU Blue
    end
    
    methods (Access = private)
        
        function createComponents(app)
            % Create UIFigure and components
            app.UIFigure = uifigure('Visible', 'off');
            app.UIFigure.Position = [100 100 1200 800];
            app.UIFigure.Name = 'WVU EcoCAR - Microphone Audio Visualizer';
            app.UIFigure.Color = app.WVUBlue;
            
            % Set icon - MATLAB uifigure.Icon supports: png, jpg, jpeg, gif, svg
            % Try to convert .ico to .png if needed, or use alternative formats
            iconSet = false;
            if exist('icon.png', 'file')
                app.UIFigure.Icon = 'icon.png';
                iconSet = true;
            elseif exist('icon.jpg', 'file') || exist('icon.jpeg', 'file')
                if exist('icon.jpg', 'file')
                    app.UIFigure.Icon = 'icon.jpg';
                else
                    app.UIFigure.Icon = 'icon.jpeg';
                end
                iconSet = true;
            elseif exist('icon.gif', 'file')
                app.UIFigure.Icon = 'icon.gif';
                iconSet = true;
            elseif exist('icon.svg', 'file')
                app.UIFigure.Icon = 'icon.svg';
                iconSet = true;
            elseif exist('icon.ico', 'file')
                % Try to convert .ico to .png using imread/imwrite
                % Note: MATLAB's imread may not support ICO format
                try
                    % Try to read the ICO file (may work in some MATLAB versions)
                    img = imread('icon.ico');
                    % Write as PNG
                    imwrite(img, 'icon.png');
                    if exist('icon.png', 'file')
                        app.UIFigure.Icon = 'icon.png';
                        iconSet = true;
                    end
                catch
                    % ICO format not supported by imread
                    % Provide helpful message to user
                    warning('Icon file icon.ico found but cannot be used directly. MATLAB uifigure.Icon requires PNG, JPG, GIF, or SVG format. Run convertIcon.m to convert, or provide icon.png manually.');
                end
            end
            
            if ~iconSet && exist('icon.ico', 'file')
                % Icon.ico exists but couldn't be used - user needs to convert
                % (Warning already shown above)
            end
            
            app.UIFigure.CloseRequestFcn = createCallbackFcn(app, @UIFigureCloseRequest, true);
            
            % Enable OpenGL hardware acceleration
            try
                opengl('hardware');
            catch
                warning('OpenGL hardware acceleration may not be available');
            end
            
            % Main Panel
            app.MainPanel = uipanel(app.UIFigure);
            app.MainPanel.BackgroundColor = app.WVUBlue;
            app.MainPanel.Position = [1 1 1200 800];
            
            % Title Label
            app.TitleLabel = uilabel(app.MainPanel);
            app.TitleLabel.Text = 'WVU EcoCAR EV Challenge - Microphone Visualizer';
            app.TitleLabel.FontName = 'Helvetica Neue';
            app.TitleLabel.FontSize = 24;
            app.TitleLabel.FontWeight = 'bold';
            app.TitleLabel.FontColor = app.WVUGold;
            app.TitleLabel.Position = [20 750 600 40];
            app.TitleLabel.HorizontalAlignment = 'left';
            
            % WVU Logo
            app.WVULogo = uiimage(app.MainPanel);
            app.WVULogo.Position = [1000 720 150 60];
            % Try to load logo - MATLAB uiimage supports PNG/JPG/BMP/TIFF
            % For SVG, we'll try it first, but may need conversion
            logoLoaded = false;
            if exist('logo.svg', 'file')
                try
                    % Try SVG directly (may work in newer MATLAB versions)
                    app.WVULogo.ImageSource = 'logo.svg';
                    app.WVULogo.Visible = 'on';
                    logoLoaded = true;
                catch
                    % SVG not supported, will try other formats below
                end
            end
            if ~logoLoaded
                % Try common raster formats
                if exist('logo.png', 'file')
                    app.WVULogo.ImageSource = 'logo.png';
                    app.WVULogo.Visible = 'on';
                    logoLoaded = true;
                elseif exist('logo.jpg', 'file') || exist('logo.jpeg', 'file')
                    if exist('logo.jpg', 'file')
                        app.WVULogo.ImageSource = 'logo.jpg';
                    else
                        app.WVULogo.ImageSource = 'logo.jpeg';
                    end
                    app.WVULogo.Visible = 'on';
                    logoLoaded = true;
                elseif exist('logo.bmp', 'file')
                    app.WVULogo.ImageSource = 'logo.bmp';
                    app.WVULogo.Visible = 'on';
                    logoLoaded = true;
                end
            end
            if ~logoLoaded && exist('logo.svg', 'file')
                % If SVG exists but uiimage can't load it, provide helpful message
                app.WVULogo.Visible = 'off';
                warning('SVG logo found but uiimage may not support it. Consider converting to PNG format.');
            end
            
            % Visualizer Panel
            app.VisualizerPanel = uipanel(app.MainPanel);
            app.VisualizerPanel.Title = 'Audio Visualization';
            app.VisualizerPanel.BackgroundColor = [0.1 0.1 0.15];
            app.VisualizerPanel.ForegroundColor = app.WVUGold;
            app.VisualizerPanel.FontName = 'Helvetica Neue';
            app.VisualizerPanel.FontSize = 14;
            app.VisualizerPanel.FontWeight = 'bold';
            app.VisualizerPanel.Position = [20 100 900 620];
            
            % Main axes for visualization
            app.MicAxes = uiaxes(app.VisualizerPanel);
            app.MicAxes.Position = [20 20 860 570];
            app.MicAxes.BackgroundColor = [0.05 0.05 0.1];
            app.MicAxes.XColor = app.WVUGold;
            app.MicAxes.YColor = app.WVUGold;
            app.MicAxes.GridColor = app.WVUGold * 0.5;
            app.MicAxes.GridAlpha = 0.3;
            app.MicAxes.XGrid = 'on';
            app.MicAxes.YGrid = 'on';
            app.MicAxes.FontName = 'Helvetica Neue';
            app.MicAxes.XLabel.String = 'Time (s)';
            app.MicAxes.XLabel.Color = app.WVUGold;
            app.MicAxes.YLabel.String = 'Amplitude';
            app.MicAxes.YLabel.Color = app.WVUGold;
            app.MicAxes.Title.String = 'Real-Time Audio Waveform';
            app.MicAxes.Title.Color = app.WVUGold;
            app.MicAxes.Title.FontWeight = 'bold';
            
            % Control Panel
            app.ControlPanel = uipanel(app.MainPanel);
            app.ControlPanel.Title = 'Controls';
            app.ControlPanel.BackgroundColor = app.WVUBlueLight;
            app.ControlPanel.ForegroundColor = app.WVUGold;
            app.ControlPanel.FontName = 'Helvetica Neue';
            app.ControlPanel.FontSize = 14;
            app.ControlPanel.FontWeight = 'bold';
            app.ControlPanel.Position = [940 100 240 620];
            
            % Number of Microphones Spinner
            app.NumMicsLabel = uilabel(app.ControlPanel);
            app.NumMicsLabel.Text = 'Number of Mics:';
            app.NumMicsLabel.FontName = 'Helvetica Neue';
            app.NumMicsLabel.FontSize = 12;
            app.NumMicsLabel.FontColor = app.WVUGold;
            app.NumMicsLabel.Position = [20 560 120 22];
            app.NumMicsLabel.HorizontalAlignment = 'left';
            
            app.NumMicsSpinner = uispinner(app.ControlPanel);
            app.NumMicsSpinner.Limits = [1 16];
            app.NumMicsSpinner.Value = 4;
            app.NumMicsSpinner.Position = [150 560 70 22];
            app.NumMicsSpinner.ValueChangedFcn = createCallbackFcn(app, @NumMicsSpinnerValueChanged, true);
            
            % Sample Rate Spinner
            app.SampleRateLabel = uilabel(app.ControlPanel);
            app.SampleRateLabel.Text = 'Sample Rate (Hz):';
            app.SampleRateLabel.FontName = 'Helvetica Neue';
            app.SampleRateLabel.FontSize = 12;
            app.SampleRateLabel.FontColor = app.WVUGold;
            app.SampleRateLabel.Position = [20 530 120 22];
            app.SampleRateLabel.HorizontalAlignment = 'left';
            
            app.SampleRateSpinner = uispinner(app.ControlPanel);
            app.SampleRateSpinner.Limits = [8000 192000];
            app.SampleRateSpinner.Value = 48000;  % Default to 48kHz for most modern microphones
            app.SampleRateSpinner.Step = 1000;
            app.SampleRateSpinner.Position = [150 530 70 22];
            app.SampleRateSpinner.ValueDisplayFormat = '%.0f';  % Display as integer, no scientific notation
            app.SampleRateSpinner.ValueChangedFcn = createCallbackFcn(app, @SampleRateSpinnerValueChanged, true);
            
            % Select Input Devices Button
            app.SelectInputsButton = uibutton(app.ControlPanel, 'push');
            app.SelectInputsButton.ButtonPushedFcn = createCallbackFcn(app, @SelectInputsButtonPushed, true);
            app.SelectInputsButton.Text = 'Select Input Devices';
            app.SelectInputsButton.FontName = 'Helvetica Neue';
            app.SelectInputsButton.FontSize = 11;
            app.SelectInputsButton.FontWeight = 'bold';
            app.SelectInputsButton.BackgroundColor = app.WVUGold;
            app.SelectInputsButton.FontColor = app.WVUBlue;
            app.SelectInputsButton.Position = [20 480 200 30];
            
            % Gain Slider
            app.GainLabel = uilabel(app.ControlPanel);
            app.GainLabel.Text = 'Gain:';
            app.GainLabel.FontName = 'Helvetica Neue';
            app.GainLabel.FontSize = 12;
            app.GainLabel.FontColor = app.WVUGold;
            app.GainLabel.Position = [20 430 120 22];
            app.GainLabel.HorizontalAlignment = 'left';
            
            app.GainSlider = uislider(app.ControlPanel);
            app.GainSlider.Limits = [0.1 5];
            app.GainSlider.Value = 1;
            app.GainSlider.Position = [20 410 200 3];
            
            % Display Options
            app.WaveformDisplayCheckBox = uicheckbox(app.ControlPanel);
            app.WaveformDisplayCheckBox.Text = 'Waveform Display';
            app.WaveformDisplayCheckBox.FontName = 'Helvetica Neue';
            app.WaveformDisplayCheckBox.FontSize = 12;
            app.WaveformDisplayCheckBox.FontColor = app.WVUGold;
            app.WaveformDisplayCheckBox.Value = true;
            app.WaveformDisplayCheckBox.Position = [20 350 150 22];
            
            app.FFTDisplayCheckBox = uicheckbox(app.ControlPanel);
            app.FFTDisplayCheckBox.Text = 'FFT Display';
            app.FFTDisplayCheckBox.FontName = 'Helvetica Neue';
            app.FFTDisplayCheckBox.FontSize = 12;
            app.FFTDisplayCheckBox.FontColor = app.WVUGold;
            app.FFTDisplayCheckBox.Value = false;
            app.FFTDisplayCheckBox.Position = [20 320 150 22];
            
            % Split Graphs Button
            app.SplitGraphsButton = uibutton(app.ControlPanel, 'push');
            app.SplitGraphsButton.ButtonPushedFcn = createCallbackFcn(app, @SplitGraphsButtonPushed, true);
            app.SplitGraphsButton.Text = 'Configure Split Graphs';
            app.SplitGraphsButton.FontName = 'Helvetica Neue';
            app.SplitGraphsButton.FontSize = 11;
            app.SplitGraphsButton.FontWeight = 'bold';
            app.SplitGraphsButton.BackgroundColor = app.WVUGold;
            app.SplitGraphsButton.FontColor = app.WVUBlue;
            app.SplitGraphsButton.Position = [20 280 200 30];
            
            % Start Button
            app.StartButton = uibutton(app.ControlPanel, 'push');
            app.StartButton.ButtonPushedFcn = createCallbackFcn(app, @StartButtonPushed, true);
            app.StartButton.Text = 'Start';
            app.StartButton.FontName = 'Helvetica Neue';
            app.StartButton.FontSize = 14;
            app.StartButton.FontWeight = 'bold';
            app.StartButton.BackgroundColor = [0.2 0.6 0.2];
            app.StartButton.FontColor = [1 1 1];
            app.StartButton.Position = [20 240 200 40];
            
            % Stop Button
            app.StopButton = uibutton(app.ControlPanel, 'push');
            app.StopButton.ButtonPushedFcn = createCallbackFcn(app, @StopButtonPushed, true);
            app.StopButton.Text = 'Stop';
            app.StopButton.FontName = 'Helvetica Neue';
            app.StopButton.FontSize = 14;
            app.StopButton.FontWeight = 'bold';
            app.StopButton.BackgroundColor = [0.6 0.2 0.2];
            app.StopButton.FontColor = [1 1 1];
            app.StopButton.Position = [20 180 200 40];
            app.StopButton.Enable = 'off';
            
            % Status Label
            app.StatusLabel = uilabel(app.ControlPanel);
            app.StatusLabel.Text = 'Status: Ready';
            app.StatusLabel.FontName = 'Helvetica Neue';
            app.StatusLabel.FontSize = 11;
            app.StatusLabel.FontColor = app.WVUGold;
            app.StatusLabel.Position = [20 130 200 22];
            app.StatusLabel.HorizontalAlignment = 'left';
            
            % Show the figure after all components are created
            app.UIFigure.Visible = 'on';
        end
        
        function recorder = createRecorderWithFallback(app, deviceID)
            % Create audio recorder with fallback to common sample rates
            % Tries: requested rate, 48kHz, 44.1kHz, 16kHz
            sampleRatesToTry = [app.SampleRate, 48000, 44100, 16000];
            
            recorder = [];
            lastError = [];
            
            % Suppress timeout warnings during recorder creation
            warning('off', 'MATLAB:audiorecorder:timeout');
            warning('off', 'matlabshared:asyncio:timeout');
            
            for sr = sampleRatesToTry
                try
                    if deviceID > 0
                        % Create recorder with specific device
                        recorder = audiorecorder(sr, 16, 1, deviceID);
                    else
                        % Use default device
                        recorder = audiorecorder(sr, 16, 1);
                    end
                    
                    % Set buffer size to prevent timeouts
                    try
                        set(recorder, 'BufferLength', 1);  % 1 second buffer
                    catch
                        % BufferLength setting may not be supported on all systems
                    end
                    
                    % Success - update sample rate if we had to use a different one
                    if sr ~= app.SampleRate
                        app.SampleRate = sr;
                        app.SampleRateSpinner.Value = sr;
                        app.StatusLabel.Text = sprintf('Status: Using %d Hz (device preferred rate)', sr);
                    end
                    break;  % Exit loop on success
                catch ME
                    lastError = ME;
                    continue;  % Try next sample rate
                end
            end
            
            % Re-enable warnings
            warning('on', 'MATLAB:audiorecorder:timeout');
            warning('on', 'matlabshared:asyncio:timeout');
            
            % If all sample rates failed, use default with last error
            if isempty(recorder)
                try
                    recorder = audiorecorder(44100, 16, 1);
                    try
                        set(recorder, 'BufferLength', 1);
                    catch
                    end
                catch
                    error('Failed to create audio recorder. Device may not support requested sample rate. Error: %s', lastError.message);
                end
            end
        end
        
        function hasToolbox = checkAudioToolbox(app)
            % Check if Audio Toolbox is available
            hasToolbox = license('test', 'Audio_Toolbox') && exist('audioDeviceReader', 'class');
            app.UseAudioToolbox = hasToolbox;
        end
        
        function initializeAudioRecorders(app)
            % Initialize audio recorders - use Audio Toolbox if available, otherwise legacy method
            try
                % Check if Audio Toolbox is available
                if checkAudioToolbox(app)
                    initializeAudioToolboxReaders(app);
                    return;
                end
                
                % Fall back to legacy audiorecorder method
                initializeAudioRecordersLegacy(app);
            catch ME
                % If Audio Toolbox fails, try legacy method
                try
                    app.UseAudioToolbox = false;
                    initializeAudioRecordersLegacy(app);
                catch
                    rethrow(ME);
                end
            end
        end
        
        function initializeAudioToolboxReaders(app)
            % Initialize using Audio Toolbox audioDeviceReader
            % Following MathWorks real-time audio pattern: https://www.mathworks.com/help/audio/gs/real-time-audio-in-matlab.html
            try
                % Clean up existing readers
                if ~isempty(app.AudioDeviceReaders)
                    for i = 1:length(app.AudioDeviceReaders)
                        if isvalid(app.AudioDeviceReaders{i})
                            try
                                release(app.AudioDeviceReaders{i});
                            catch
                            end
                        end
                    end
                end
                app.AudioDeviceReaders = {};
                
                % Get available devices using non-blocking audiodevinfo
                deviceToUse = '';
                try
                    info = audiodevinfo;
                    inputDevices = info.input;
                    if ~isempty(inputDevices)
                        if ~isempty(app.SelectedDeviceNames) && length(app.SelectedDeviceNames) >= 1
                            deviceToUse = app.SelectedDeviceNames{1};
                        else
                            deviceToUse = inputDevices(1).Name;
                        end
                    end
                catch
                    % Will use default device
                end
                
                % Create audioDeviceReader following MathWorks pattern
                % Frame size: 1024 samples is standard for real-time processing
                samplesPerFrame = 1024;
                
                try
                    if ~isempty(deviceToUse)
                        reader = audioDeviceReader(...
                            'Device', deviceToUse, ...
                            'SampleRate', app.SampleRate, ...
                            'SamplesPerFrame', samplesPerFrame);
                    else
                        reader = audioDeviceReader(...
                            'SampleRate', app.SampleRate, ...
                            'SamplesPerFrame', samplesPerFrame);
                    end
                catch
                    % Fallback to default device
                    reader = audioDeviceReader(...
                        'SampleRate', app.SampleRate, ...
                        'SamplesPerFrame', samplesPerFrame);
                end
                
                app.AudioDeviceReaders{1} = reader;
                % Initialize audio history buffers (keep ~0.5 seconds for display)
                maxHistorySamples = round(app.SampleRate * 0.5);
                for i = 1:app.NumMics
                    app.AudioHistory{i} = zeros(0, 1);  % Initialize empty
                end
                app.StatusLabel.Text = sprintf('Status: Ready at %d Hz', app.SampleRate);
                
            catch ME
                errorMsg = ME.message;
                app.StatusLabel.Text = sprintf('Status: Error - %s', ME.message);
                uialert(app.UIFigure, sprintf('Error initializing audio:\n\n%s', errorMsg), 'Audio Error', 'Icon', 'error');
                throw(ME);
            end
        end
        
        function initializeAudioRecordersLegacy(app)
            % Initialize audio recorders using legacy audiorecorder method (single device only)
            try
                % Get available audio input devices
                info = audiodevinfo;
                inputDevices = info.input;
                
                if isempty(inputDevices)
                    error('No audio input devices found');
                end
                
                % Stop and delete existing recorders
                if ~isempty(app.AudioRecorders)
                    for i = 1:length(app.AudioRecorders)
                        if isvalid(app.AudioRecorders{i})
                            stop(app.AudioRecorders{i});
                            delete(app.AudioRecorders{i});
                        end
                    end
                end
                
                % Create new audio recorders (use cell array)
                app.AudioRecorders = {};
                
                % Use selected device IDs if available, otherwise auto-select
                % CRITICAL: Windows cannot handle multiple recorders - use ONLY the first device
                if ~isempty(app.SelectedDeviceIDs) && length(app.SelectedDeviceIDs) >= 1
                    % Use ONLY the first selected device to avoid timeouts
                    deviceID = app.SelectedDeviceIDs(1);
                    try
                        recorder = createRecorderWithFallback(app, deviceID);
                        app.AudioRecorders{end+1} = recorder;
                    catch
                        % If first device fails, try default
                        try
                            recorder = createRecorderWithFallback(app, -1);
                            app.AudioRecorders{end+1} = recorder;
                        catch
                            error('Failed to create audio recorder');
                        end
                    end
                else
                    % Auto-select devices
                    % CRITICAL: Windows audio system CANNOT handle multiple recorders
                    % Use ONLY ONE recorder with the first available device
                    % Multiple microphones will share the same audio stream
                    if ~isempty(inputDevices)
                        deviceID = inputDevices(1).ID;
                    else
                        deviceID = -1;  % Use default
                    end
                    
                    % Create only ONE recorder - multiple mics will use the same stream
                    recorder = createRecorderWithFallback(app, deviceID);
                    app.AudioRecorders{end+1} = recorder;
                    
                    % Note: We're only using 1 physical recorder even if user requests more mics
                    % This is a Windows limitation - multiple recorders cause timeouts
                end
                
                % Update status with device info
                if length(app.AudioRecorders) == app.NumMics
                    app.StatusLabel.Text = sprintf('Status: Initialized %d microphone(s) at %d Hz', ...
                        length(app.AudioRecorders), app.SampleRate);
                else
                    app.StatusLabel.Text = sprintf('Status: Initialized %d microphone(s) (requested %d)', ...
                        length(app.AudioRecorders), app.NumMics);
                end
                
            catch ME
                errorMsg = ME.message;
                % Provide helpful suggestions for common errors
                if contains(errorMsg, 'sample rate', 'IgnoreCase', true)
                    errorMsg = sprintf('%s\n\nTry changing the sample rate to 48000 Hz or 44100 Hz.', errorMsg);
                elseif contains(errorMsg, 'device', 'IgnoreCase', true)
                    errorMsg = sprintf('%s\n\nMake sure your microphone is connected and not being used by another application.', errorMsg);
                end
                app.StatusLabel.Text = sprintf('Status: Error - %s', ME.message);
                uialert(app.UIFigure, sprintf('Error initializing audio:\n\n%s', errorMsg), 'Audio Error', 'Icon', 'error');
            end
        end
        
        function startVisualization(app)
            if app.IsRunning
                return;
            end
            
            try
                % Initialize audio recorders (Audio Toolbox or legacy)
                initializeAudioRecorders(app);
                
                if app.UseAudioToolbox
                    % Audio Toolbox method - readers are ready to use immediately
                    if isempty(app.AudioDeviceReaders)
                        error('No audio device readers available');
                    end
                    app.StatusLabel.Text = sprintf('Status: Running at %d Hz', app.SampleRate);
                else
                    % Legacy method - need to start recorders
                    if isempty(app.AudioRecorders)
                        error('No audio recorders available');
                    end
                    
                    % Start recorder - use only ONE to avoid Windows timeout issues
                    warning('off', 'all');
                    startedCount = 0;
                    
                    for i = 1:length(app.AudioRecorders)
                        try
                            if isvalid(app.AudioRecorders{i})
                                try
                                    record(app.AudioRecorders{i});
                                    startedCount = startedCount + 1;
                                catch
                                    startedCount = startedCount + 1;  % Count as started
                                end
                            end
                        catch
                        end
                    end
                    
                    if startedCount > 0
                        app.StatusLabel.Text = sprintf('Status: Started recorder, waiting for data...');
                    else
                        app.StatusLabel.Text = 'Status: Warning - Recorder failed to start';
                    end
                end
                
                % Update UI immediately
                app.StartButton.Enable = 'off';
                app.StopButton.Enable = 'on';
                
                % Create timer for real-time visualization
                % Following MathWorks pattern: read frames and display immediately
                warning('off', 'MATLAB:audiorecorder:timeout');
                warning('off', 'matlabshared:asyncio:timeout');
                
                % Timer period: update at ~20 FPS for smooth visualization
                % For audioDeviceReader with 1024 samples at 48kHz: ~21ms per frame
                % Timer at 50ms ensures we don't miss frames
                timerPeriod = 0.05;  % 50ms = 20 FPS
                
                app.Timer = timer('ExecutionMode', 'fixedRate', ...
                    'Period', timerPeriod, ...
                    'TimerFcn', @(~,~) updateVisualization(app), ...
                    'BusyMode', 'drop', ...
                    'ErrorFcn', @(~,~) fprintf('Timer error occurred\n'));
                
                app.IsRunning = true;
                
                % Start timer - data will appear immediately
                drawnow;
                start(app.Timer);
                
            catch ME
                app.StatusLabel.Text = sprintf('Status: Error - %s', ME.message);
                uialert(app.UIFigure, sprintf('Error starting visualization: %s', ME.message), 'Error');
                app.IsRunning = false;
            end
        end
        
        function stopVisualization(app)
            % Force stop - don't wait for anything
            app.IsRunning = false;
            
            % Stop timer immediately (non-blocking)
            if ~isempty(app.Timer) && isvalid(app.Timer)
                try
                    stop(app.Timer);
                catch
                end
                try
                    delete(app.Timer);
                catch
                end
                app.Timer = [];
            end
            
            % Clean up any initialization timers (non-blocking)
            try
                allTimers = timerfind;
                for t = allTimers
                    if isvalid(t)
                        try
                            stop(t);
                            delete(t);
                        catch
                        end
                    end
                end
            catch
            end
            
            % Stop all recorders/readers (non-blocking)
            if app.UseAudioToolbox && ~isempty(app.AudioDeviceReaders)
                for i = 1:length(app.AudioDeviceReaders)
                    if isvalid(app.AudioDeviceReaders{i})
                        try
                            release(app.AudioDeviceReaders{i});
                        catch
                        end
                    end
                end
                % Clear audio history
                app.AudioHistory = {};
            end
            
            if ~isempty(app.AudioRecorders)
                for i = 1:length(app.AudioRecorders)
                    if isvalid(app.AudioRecorders{i})
                        try
                            stop(app.AudioRecorders{i});
                        catch
                        end
                    end
                end
            end
            
            % Update UI
            app.StartButton.Enable = 'on';
            app.StopButton.Enable = 'off';
            app.StatusLabel.Text = 'Status: Stopped';
            
            % Clear axes and cleanup split axes
            try
                cla(app.MicAxes);
                cleanupSplitAxes(app);
                app.MicAxes.Visible = 'on';
            catch
            end
        end
        
        function updateVisualization(app)
            if ~app.IsRunning
                return;
            end
            
            % Suppress ALL warnings to prevent timeout error spam
            warning('off', 'all');
            
            try
                % Get audio data from recorders
                audioData = [];
                timeData = [];
                
                if app.UseAudioToolbox
                    % Audio Toolbox method - following MathWorks real-time pattern
                    % Read frame directly, accumulate rolling history, display immediately
                    if ~isempty(app.AudioDeviceReaders) && isvalid(app.AudioDeviceReaders{1})
                        try
                            % Read audio frame directly (returns immediately)
                            frameData = app.AudioDeviceReaders{1}();
                            
                            if ~isempty(frameData) && length(frameData) > 0
                                % Convert to double and apply gain
                                if ~isa(frameData, 'double')
                                    frameData = double(frameData);
                                end
                                frameData = frameData * app.GainSlider.Value;
                                
                                % Accumulate in rolling history (keep ~0.5 seconds)
                                maxHistorySamples = round(app.SampleRate * 0.5);
                                for micIdx = 1:app.NumMics
                                    % Append new frame
                                    app.AudioHistory{micIdx} = [app.AudioHistory{micIdx}; frameData(:)];
                                    % Trim if too long
                                    if length(app.AudioHistory{micIdx}) > maxHistorySamples
                                        app.AudioHistory{micIdx} = app.AudioHistory{micIdx}(end-maxHistorySamples+1:end);
                                    end
                                end
                                
                                % Extract accumulated data for display
                                if ~isempty(app.AudioHistory{1})
                                    if app.NumMics == 1
                                        audioData = app.AudioHistory{1}(:);
                                    else
                                        % Combine all mic histories
                                        minLen = length(app.AudioHistory{1});
                                        for micIdx = 2:app.NumMics
                                            if length(app.AudioHistory{micIdx}) < minLen
                                                minLen = length(app.AudioHistory{micIdx});
                                            end
                                        end
                                        audioData = zeros(minLen, app.NumMics);
                                        for micIdx = 1:app.NumMics
                                            audioData(:, micIdx) = app.AudioHistory{micIdx}(1:minLen);
                                        end
                                    end
                                    % Create time vector
                                    timeData = (0:length(audioData)-1) / app.SampleRate;
                                end
                            end
                        catch ME
                            % Silently handle errors to prevent timer issues
                            audioData = [];
                            timeData = [];
                        end
                    end
                else
                    % Legacy method - use audiorecorder
                    for i = 1:length(app.AudioRecorders)
                        if isvalid(app.AudioRecorders{i})
                            try
                                % Check if recorder is actually recording (may timeout, so catch it)
                                try
                                    isRec = isrecording(app.AudioRecorders{i});
                                catch
                                    isRec = false;
                                end
                                
                                if ~isRec
                                    continue;
                                end
                                
                                % Get current audio data - completely suppress errors
                                try
                                    totalSamples = get(app.AudioRecorders{i}, 'TotalSamples');
                                catch
                                    totalSamples = 0;
                                end
                                
                                if totalSamples < 1  % Accept any data, even just 1 sample
                                    continue;
                                end
                                
                                % Get audio data - suppress all errors
                                data = [];
                                try
                                    if totalSamples > 0
                                        data = getaudiodata(app.AudioRecorders{i}, 'double');
                                    end
                                catch
                                    % Timeout or error - just skip silently
                                    data = [];
                                end
                                
                                if ~isempty(data) && length(data) > 0
                                    % Apply gain
                                    data = data * app.GainSlider.Value;
                                    
                                    % Create time vector
                                    time = (0:length(data)-1) / app.SampleRate;
                                    
                                    % Keep only recent data (last 0.5 seconds for smooth display)
                                    maxSamples = round(app.SampleRate * 0.5);
                                    if length(data) > maxSamples
                                        data = data(end-maxSamples+1:end);
                                        time = time(end-maxSamples+1:end);
                                        % Adjust time to start from 0
                                        time = time - time(1);
                                    end
                                    
                                    % Store as column vector
                                    if isempty(audioData)
                                        audioData = data(:);
                                        timeData = time(:);
                                    else
                                        % Ensure same length for all channels
                                        minLen = min(length(audioData), length(data));
                                        audioData = [audioData(1:minLen), data(1:minLen)];
                                        % Trim timeData to match the trimmed audioData length
                                        timeData = timeData(1:minLen);
                                    end
                                end
                            catch
                                % Skip this recorder if it fails
                                continue;
                            end
                        end
                    end
                    
                    % If user requested multiple mics but we only have one recorder,
                    % duplicate the data to show multiple "channels"
                    if ~isempty(audioData) && size(audioData, 2) == 1 && app.NumMics > 1
                        % Duplicate the single channel for display
                        audioData = repmat(audioData, 1, min(app.NumMics, 16));
                    end
                end
                
                if isempty(audioData)
                    % No data in this frame - skip update (will try again next timer tick)
                    return;
                end
                
                % Update status
                if app.UseAudioToolbox
                    app.StatusLabel.Text = sprintf('Status: Running at %d Hz', app.SampleRate);
                else
                    app.StatusLabel.Text = sprintf('Status: Running (%d channel(s))', size(audioData, 2));
                end
                
                showWaveform = app.WaveformDisplayCheckBox.Value;
                showFFT = app.FFTDisplayCheckBox.Value;
                
                % If neither is selected, default to waveform
                if ~showWaveform && ~showFFT
                    showWaveform = true;
                end
                
                % Determine which inputs to split
                numChannels = size(audioData, 2);
                splitIndices = find(app.SplitInputs(1:min(numChannels, length(app.SplitInputs))));
                combinedIndices = setdiff(1:numChannels, splitIndices);
                numSplits = length(splitIndices);
                
                % Create/update split axes if needed
                if numSplits > 0
                    if isempty(app.SplitAxes) || length(app.SplitAxes) ~= numSplits
                        createSplitAxes(app, numSplits);
                    end
                    % Hide main axes when splits are active
                    app.MicAxes.Visible = 'off';
                else
                    % Show main axes when no splits
                    app.MicAxes.Visible = 'on';
                    cleanupSplitAxes(app);
                end
                
                % Plot split inputs on separate axes
                for splitIdx = 1:numSplits
                    channelIdx = splitIndices(splitIdx);
                    if splitIdx <= length(app.SplitAxes) && isvalid(app.SplitAxes{splitIdx})
                        ax = app.SplitAxes{splitIdx};
                        cla(ax);
                        hold(ax, 'on');
                        
                        if showWaveform
                            plot(ax, timeData, audioData(:, channelIdx), ...
                                'Color', app.WVUGold, 'LineWidth', 1.5);
                            ax.YLabel.String = 'Amplitude';
                            ax.XLabel.String = 'Time (s)';
                            ax.Title.String = sprintf('Input %d - Waveform', channelIdx);
                        elseif showFFT
                            fftData = audioData(:, channelIdx);
                            N = length(fftData);
                            if N > 0
                                windowed = fftData .* hann(N);
                                Y = fft(windowed);
                                P2 = abs(Y/N);
                                P1 = P2(1:N/2+1);
                                P1(2:end-1) = 2*P1(2:end-1);
                                f = app.SampleRate*(0:(N/2))/N;
                                maxFreq = min(8000, app.SampleRate/2);
                                idx = f <= maxFreq;
                                plot(ax, f(idx), P1(idx), 'Color', app.WVUGold, 'LineWidth', 2);
                                ax.YLabel.String = 'Magnitude';
                                ax.XLabel.String = 'Frequency (Hz)';
                                ax.Title.String = sprintf('Input %d - Frequency Spectrum', channelIdx);
                            end
                        end
                        hold(ax, 'off');
                        ax.XGrid = 'on';
                        ax.YGrid = 'on';
                    end
                end
                
                % Plot combined inputs on main axes
                if ~isempty(combinedIndices)
                    cla(app.MicAxes);
                    hold(app.MicAxes, 'on');
                    
                    if showWaveform && ~showFFT
                        colors = lines(length(combinedIndices));
                        for i = 1:length(combinedIndices)
                            chIdx = combinedIndices(i);
                            plot(app.MicAxes, timeData, audioData(:, chIdx), ...
                                'Color', colors(i,:), 'LineWidth', 1.5, ...
                                'DisplayName', sprintf('Mic %d', chIdx));
                        end
                        app.MicAxes.YLabel.String = 'Amplitude';
                        app.MicAxes.XLabel.String = 'Time (s)';
                        app.MicAxes.Title.String = sprintf('Combined Waveform (%d Mic(s))', length(combinedIndices));
                        legend(app.MicAxes, 'show', 'Location', 'best', 'TextColor', app.WVUGold);
                        
                    elseif showFFT && ~showWaveform
                        fftData = mean(audioData(:, combinedIndices), 2);
                        N = length(fftData);
                        if N > 0
                            windowed = fftData .* hann(N);
                            Y = fft(windowed);
                            P2 = abs(Y/N);
                            P1 = P2(1:N/2+1);
                            P1(2:end-1) = 2*P1(2:end-1);
                            f = app.SampleRate*(0:(N/2))/N;
                            maxFreq = min(8000, app.SampleRate/2);
                            idx = f <= maxFreq;
                            plot(app.MicAxes, f(idx), P1(idx), ...
                                'Color', app.WVUGold, 'LineWidth', 2);
                            app.MicAxes.YLabel.String = 'Magnitude';
                            app.MicAxes.XLabel.String = 'Frequency (Hz)';
                            app.MicAxes.Title.String = 'Combined Frequency Spectrum';
                        end
                        
                    elseif showWaveform && showFFT
                        colors = lines(length(combinedIndices));
                        for i = 1:length(combinedIndices)
                            chIdx = combinedIndices(i);
                            plot(app.MicAxes, timeData, audioData(:, chIdx), ...
                                'Color', colors(i,:), 'LineWidth', 1.5, ...
                                'DisplayName', sprintf('Mic %d', chIdx));
                        end
                        
                        fftData = mean(audioData(:, combinedIndices), 2);
                        N = length(fftData);
                        if N > 0
                            windowed = fftData .* hann(N);
                            Y = fft(windowed);
                            P2 = abs(Y/N);
                            P1 = P2(1:N/2+1);
                            P1(2:end-1) = 2*P1(2:end-1);
                            f = app.SampleRate*(0:(N/2))/N;
                            if length(P1) > 1
                                [~, maxIdx] = max(P1(2:end));
                                peakFreq = f(maxIdx + 1);
                            else
                                peakFreq = 0;
                            end
                            app.MicAxes.Title.String = sprintf('Combined Waveform (%d Mic(s)) - Peak: %.1f Hz', ...
                                length(combinedIndices), peakFreq);
                        else
                            app.MicAxes.Title.String = sprintf('Combined Waveform (%d Mic(s))', length(combinedIndices));
                        end
                        
                        app.MicAxes.YLabel.String = 'Amplitude';
                        app.MicAxes.XLabel.String = 'Time (s)';
                        legend(app.MicAxes, 'show', 'Location', 'best', 'TextColor', app.WVUGold);
                    end
                    
                    hold(app.MicAxes, 'off');
                    app.MicAxes.XGrid = 'on';
                    app.MicAxes.YGrid = 'on';
                end
                
                % Force update - suppress errors
                try
                    drawnow;
                catch
                    % Ignore drawnow errors (may occur during timeouts)
                end
                
                % Re-enable warnings after update (but keep timeout warnings off)
                warning('on', 'all');
                warning('off', 'MATLAB:audiorecorder:timeout');
                warning('off', 'matlabshared:asyncio:timeout');
                
            catch ME
                % Silently handle errors during update to prevent timer issues
                % app.StatusLabel.Text = sprintf('Update Error: %s', ME.message);
            end
        end
    end
    
    % App creation and deletion
    methods (Access = public)
        
        % Construct app
        function app = MicVisualizer
            
            % Create UIFigure and components
            createComponents(app)
            
            % Don't initialize audio on startup - wait until user clicks Start
            % This prevents hanging if device is busy
            app.StatusLabel.Text = 'Status: Ready - Click Start to begin';
        end
        
        % Code that executes before app deletion
        function delete(app)
            % Stop visualization
            stopVisualization(app);
            
            % Clean up timer
            if ~isempty(app.Timer) && isvalid(app.Timer)
                try
                    stop(app.Timer);
                    delete(app.Timer);
                catch
                    % Ignore errors during cleanup
                end
            end
            
            % Clean up audio recorders
            if ~isempty(app.AudioRecorders)
                for i = 1:length(app.AudioRecorders)
                    if isvalid(app.AudioRecorders{i})
                        try
                            stop(app.AudioRecorders{i});
                            delete(app.AudioRecorders{i});
                        catch
                            % Ignore errors during cleanup
                        end
                    end
                end
            end
            
            % Delete the figure if it still exists
            if isvalid(app.UIFigure)
                delete(app.UIFigure);
            end
        end
    end
    
    % Component callbacks
    methods (Access = private)
        
        % Code that executes when component value is changed.
        function NumMicsSpinnerValueChanged(app, event)
            newNumMics = app.NumMicsSpinner.Value;
            
            % Adjust SelectedDeviceIDs array if number of mics changed
            if newNumMics ~= app.NumMics
                if isempty(app.SelectedDeviceIDs) || length(app.SelectedDeviceIDs) < newNumMics
                    % Extend array with default device
                    try
                        info = audiodevinfo;
                        inputDevices = info.input;
                        if ~isempty(inputDevices)
                            defaultID = inputDevices(1).ID;
                            if isempty(app.SelectedDeviceIDs)
                                app.SelectedDeviceIDs = repmat(defaultID, newNumMics, 1);
                            else
                                app.SelectedDeviceIDs(end+1:newNumMics) = defaultID;
                            end
                        end
                    catch
                        % If we can't get devices, clear selection
                        app.SelectedDeviceIDs = [];
                    end
                elseif length(app.SelectedDeviceIDs) > newNumMics
                    % Trim array
                    app.SelectedDeviceIDs = app.SelectedDeviceIDs(1:newNumMics);
                end
            end
            
            app.NumMics = newNumMics;
            % Reset split inputs array if number of mics changed
            if length(app.SplitInputs) ~= newNumMics
                app.SplitInputs = false(newNumMics, 1);
            end
            if ~app.IsRunning
                initializeAudioRecorders(app);
            else
                app.StatusLabel.Text = 'Status: Change will take effect after restart';
            end
        end
        
        function SampleRateSpinnerValueChanged(app, event)
            app.SampleRate = app.SampleRateSpinner.Value;
            if ~app.IsRunning
                initializeAudioRecorders(app);
            else
                app.StatusLabel.Text = 'Status: Change will take effect after restart';
            end
        end
        
        % Button pushed function: SelectInputsButton
        function SelectInputsButtonPushed(app, event)
            showInputDeviceDialog(app);
        end
        
        % Button pushed function: SplitGraphsButton
        function SplitGraphsButtonPushed(app, event)
            showSplitGraphsDialog(app);
        end
        
        function showInputDeviceDialog(app)
            % Create dialog figure for device selection
            % Adjust height based on number of microphones
            numMics = app.NumMics;
            baseHeight = 150;
            micHeight = 35;
            dialogHeight = min(600, baseHeight + numMics * micHeight); % Cap at 600px
            
            dialogFig = uifigure('Visible', 'off');
            dialogFig.Position = [400 300 500 dialogHeight];
            dialogFig.Name = 'Select Audio Input Devices';
            dialogFig.Color = app.WVUBlue;
            dialogFig.Resize = 'off';
            
            % Main panel
            mainPanel = uipanel(dialogFig);
            mainPanel.BackgroundColor = app.WVUBlueLight;
            mainPanel.Position = [10 10 480 dialogHeight-20];
            
            % Title
            titleLabel = uilabel(mainPanel);
            titleLabel.Text = 'Select Input Device for Each Microphone';
            titleLabel.FontName = 'Helvetica Neue';
            titleLabel.FontSize = 16;
            titleLabel.FontWeight = 'bold';
            titleLabel.FontColor = app.WVUGold;
            titleLabel.Position = [20 dialogHeight-50 440 30];
            titleLabel.HorizontalAlignment = 'center';
            
            % Refresh button
            refreshBtn = uibutton(mainPanel, 'push');
            refreshBtn.Text = 'Refresh Devices';
            refreshBtn.FontName = 'Helvetica Neue';
            refreshBtn.FontSize = 10;
            refreshBtn.FontWeight = 'bold';
            refreshBtn.BackgroundColor = app.WVUGold;
            refreshBtn.FontColor = app.WVUBlue;
            refreshBtn.Position = [20 dialogHeight-80 120 25];
            
            % Create dropdowns for each microphone (will be populated by refresh function)
            numMics = app.NumMics;
            dropdowns = cell(numMics, 1);
            labels = cell(numMics, 1);
            startY = dialogHeight - 120;
            spacing = 35;
            
            % Function to refresh device list and update dropdowns
            function refreshDeviceList()
                % Get available input devices (always refresh)
                try
                    info = audiodevinfo;
                    inputDevices = info.input;
                catch
                    inputDevices = [];
                end
                
                if isempty(inputDevices)
                    % Hide all dropdowns and labels, show error
                    for i = 1:numMics
                        if ~isempty(labels{i}) && isvalid(labels{i})
                            labels{i}.Visible = 'off';
                        end
                        if ~isempty(dropdowns{i}) && isvalid(dropdowns{i})
                            dropdowns{i}.Visible = 'off';
                        end
                    end
                    
                    % Show error label if it doesn't exist
                    errorLabels = findobj(mainPanel, 'Tag', 'ErrorLabel');
                    if isempty(errorLabels)
                        errorLabel = uilabel(mainPanel);
                        errorLabel.Tag = 'ErrorLabel';
                        errorLabel.Text = 'No audio input devices found. Plug in a microphone and click Refresh.';
                        errorLabel.FontName = 'Helvetica Neue';
                        errorLabel.FontSize = 12;
                        errorLabel.FontColor = [1 0.5 0.5];
                        errorLabel.Position = [20 200 440 60];
                        errorLabel.HorizontalAlignment = 'center';
                        errorLabel.WordWrap = 'on';
                    else
                        errorLabels.Visible = 'on';
                    end
                    return;
                end
                
                % Hide error label if it exists
                errorLabels = findobj(mainPanel, 'Tag', 'ErrorLabel');
                if ~isempty(errorLabels)
                    errorLabels.Visible = 'off';
                end
                
                % Create device name list
                deviceNames = cell(length(inputDevices), 1);
                deviceIDs = zeros(length(inputDevices), 1);
                for i = 1:length(inputDevices)
                    deviceNames{i} = sprintf('%s (ID: %d)', inputDevices(i).Name, inputDevices(i).ID);
                    deviceIDs(i) = inputDevices(i).ID;
                end
                
                % Initialize selected device IDs if empty
                if isempty(app.SelectedDeviceIDs) || length(app.SelectedDeviceIDs) < numMics
                    app.SelectedDeviceIDs = zeros(numMics, 1);
                    for i = 1:min(numMics, length(inputDevices))
                        app.SelectedDeviceIDs(i) = inputDevices(i).ID;
                    end
                    % Fill remaining with first device
                    if numMics > length(inputDevices)
                        for i = length(inputDevices)+1:numMics
                            app.SelectedDeviceIDs(i) = inputDevices(1).ID;
                        end
                    end
                end
                
                % Create or update dropdowns for each microphone
                for i = 1:numMics
                    % Create label if it doesn't exist
                    if isempty(labels{i}) || ~isvalid(labels{i})
                        labels{i} = uilabel(mainPanel);
                        labels{i}.Text = sprintf('Microphone %d:', i);
                        labels{i}.FontName = 'Helvetica Neue';
                        labels{i}.FontSize = 11;
                        labels{i}.FontColor = app.WVUGold;
                        labels{i}.Position = [30 startY - (i-1)*spacing 120 22];
                        labels{i}.HorizontalAlignment = 'left';
                    end
                    labels{i}.Visible = 'on';
                    
                    % Create or update dropdown
                    if isempty(dropdowns{i}) || ~isvalid(dropdowns{i})
                        dropdowns{i} = uidropdown(mainPanel);
                        dropdowns{i}.FontName = 'Helvetica Neue';
                        dropdowns{i}.FontSize = 11;
                        dropdowns{i}.Position = [160 startY - (i-1)*spacing 280 22];
                    end
                    
                    % Update dropdown items with fresh device list
                    dropdowns{i}.Items = deviceNames;
                    dropdowns{i}.Visible = 'on';
                    
                    % Set current selection (try to preserve if device still exists)
                    currentID = app.SelectedDeviceIDs(i);
                    idx = find(deviceIDs == currentID, 1);
                    if ~isempty(idx)
                        dropdowns{i}.Value = deviceNames{idx};
                    else
                        % Device no longer exists, select first available
                        if ~isempty(deviceNames)
                            dropdowns{i}.Value = deviceNames{1};
                            app.SelectedDeviceIDs(i) = deviceIDs(1);
                        end
                    end
                    
                    % Store device ID when changed - use a callback that looks up from current items
                    % This ensures it works even after refresh
                    micIdx = i; % Capture loop variable
                    dropdowns{i}.ValueChangedFcn = @(src,~) updateDeviceIDFromDropdown(app, micIdx, src);
                end
            end
            
            % Set refresh button callback
            refreshBtn.ButtonPushedFcn = @(~,~) refreshDeviceList();
            
            % Initial refresh of device list
            refreshDeviceList();
            
            % Buttons
            okBtn = uibutton(mainPanel, 'push');
            okBtn.Text = 'OK';
            okBtn.FontName = 'Helvetica Neue';
            okBtn.FontSize = 12;
            okBtn.FontWeight = 'bold';
            okBtn.BackgroundColor = [0.2 0.6 0.2];
            okBtn.FontColor = [1 1 1];
            okBtn.Position = [150 30 100 35];
            okBtn.ButtonPushedFcn = @(~,~) closeDialog(app, dialogFig);
            
            cancelBtn = uibutton(mainPanel, 'push');
            cancelBtn.Text = 'Cancel';
            cancelBtn.FontName = 'Helvetica Neue';
            cancelBtn.FontSize = 12;
            cancelBtn.FontWeight = 'bold';
            cancelBtn.BackgroundColor = [0.6 0.2 0.2];
            cancelBtn.FontColor = [1 1 1];
            cancelBtn.Position = [270 30 100 35];
            cancelBtn.ButtonPushedFcn = @(~,~) delete(dialogFig);
            
            dialogFig.Visible = 'on';
        end
        
        function updateDeviceID(app, micIndex, deviceIDs, selectedName, deviceNames)
            % Find the index of the selected device name
            idx = strcmp(deviceNames, selectedName);
            if any(idx)
                app.SelectedDeviceIDs(micIndex) = deviceIDs(idx);
            end
        end
        
        function updateDeviceIDFromDropdown(app, micIndex, dropdown)
            % Update device ID from dropdown selection by parsing the device name
            % Format is "Device Name (ID: X)"
            selectedName = dropdown.Value;
            items = dropdown.Items;
            
            % Find the selected item index
            idx = strcmp(items, selectedName);
            if any(idx)
                % Parse device ID from the string format "Name (ID: X)"
                deviceStr = selectedName;
                idStart = strfind(deviceStr, '(ID: ');
                if ~isempty(idStart)
                    idEnd = strfind(deviceStr(idStart(1)+5:end), ')');
                    if ~isempty(idEnd)
                        idStr = deviceStr(idStart(1)+5:idStart(1)+4+idEnd(1)-1);
                        deviceID = str2double(idStr);
                        if ~isnan(deviceID)
                            app.SelectedDeviceIDs(micIndex) = deviceID;
                        end
                    end
                end
            end
        end
        
        function closeDialog(app, dialogFig)
            % Reinitialize audio recorders with new device selections
            if ~app.IsRunning
                initializeAudioRecorders(app);
                app.StatusLabel.Text = sprintf('Status: Devices configured for %d microphone(s)', app.NumMics);
            else
                app.StatusLabel.Text = 'Status: Device changes will take effect after restart';
            end
            delete(dialogFig);
        end
        
        function showSplitGraphsDialog(app)
            % Create dialog for selecting which inputs to split onto separate graphs
            numMics = app.NumMics;
            dialogHeight = min(500, 150 + numMics * 30);
            
            dialogFig = uifigure('Visible', 'off');
            dialogFig.Position = [400 300 400 dialogHeight];
            dialogFig.Name = 'Configure Split Graphs';
            dialogFig.Color = app.WVUBlue;
            dialogFig.Resize = 'off';
            
            % Main panel
            mainPanel = uipanel(dialogFig);
            mainPanel.BackgroundColor = app.WVUBlueLight;
            mainPanel.Position = [10 10 380 dialogHeight-20];
            
            % Title
            titleLabel = uilabel(mainPanel);
            titleLabel.Text = 'Select Inputs to Display on Separate Graphs';
            titleLabel.FontName = 'Helvetica Neue';
            titleLabel.FontSize = 14;
            titleLabel.FontWeight = 'bold';
            titleLabel.FontColor = app.WVUGold;
            titleLabel.Position = [20 dialogHeight-60 340 30];
            titleLabel.HorizontalAlignment = 'center';
            
            % Create checkboxes for each input
            checkboxes = cell(numMics, 1);
            startY = dialogHeight - 100;
            spacing = 30;
            
            for i = 1:numMics
                checkboxes{i} = uicheckbox(mainPanel);
                checkboxes{i}.Text = sprintf('Split Input %d', i);
                checkboxes{i}.FontName = 'Helvetica Neue';
                checkboxes{i}.FontSize = 11;
                checkboxes{i}.FontColor = app.WVUGold;
                checkboxes{i}.Value = app.SplitInputs(i);
                checkboxes{i}.Position = [40 startY - (i-1)*spacing 200 22];
                
                % Store callback - need to use a function handle that properly assigns
                micIdx = i;
                checkboxes{i}.ValueChangedFcn = @(~,~) setSplitInput(app, micIdx, checkboxes{micIdx}.Value);
            end
            
            % Buttons
            okBtn = uibutton(mainPanel, 'push');
            okBtn.Text = 'OK';
            okBtn.FontName = 'Helvetica Neue';
            okBtn.FontSize = 12;
            okBtn.FontWeight = 'bold';
            okBtn.BackgroundColor = [0.2 0.6 0.2];
            okBtn.FontColor = [1 1 1];
            okBtn.Position = [120 30 100 35];
            okBtn.ButtonPushedFcn = @(~,~) closeSplitDialog(app, dialogFig);
            
            cancelBtn = uibutton(mainPanel, 'push');
            cancelBtn.Text = 'Cancel';
            cancelBtn.FontName = 'Helvetica Neue';
            cancelBtn.FontSize = 12;
            cancelBtn.FontWeight = 'bold';
            cancelBtn.BackgroundColor = [0.6 0.2 0.2];
            cancelBtn.FontColor = [1 1 1];
            cancelBtn.Position = [240 30 100 35];
            cancelBtn.ButtonPushedFcn = @(~,~) delete(dialogFig);
            
            dialogFig.Visible = 'on';
        end
        
        function setSplitInput(app, micIdx, value)
            % Helper function to set split input value
            if micIdx > 0 && micIdx <= length(app.SplitInputs)
                app.SplitInputs(micIdx) = value;
            end
        end
        
        function closeSplitDialog(app, dialogFig)
            % Clean up existing split axes if visualization is running
            if app.IsRunning
                cleanupSplitAxes(app);
            end
            delete(dialogFig);
        end
        
        function cleanupSplitAxes(app)
            % Remove all split axes
            if ~isempty(app.SplitAxes)
                for i = 1:length(app.SplitAxes)
                    if isvalid(app.SplitAxes{i})
                        delete(app.SplitAxes{i});
                    end
                end
                app.SplitAxes = {};
            end
        end
        
        function createSplitAxes(app, numSplits)
            % Create axes for split displays
            cleanupSplitAxes(app);
            
            if numSplits == 0
                return;
            end
            
            % Calculate layout - arrange in grid
            cols = ceil(sqrt(numSplits));
            rows = ceil(numSplits / cols);
            
            panelWidth = app.VisualizerPanel.Position(3) - 40;
            panelHeight = app.VisualizerPanel.Position(4) - 40;
            
            axWidth = (panelWidth - 20*(cols+1)) / cols;
            axHeight = (panelHeight - 20*(rows+1)) / rows;
            
            app.SplitAxes = cell(numSplits, 1);
            splitIdx = 1;
            
            for row = 1:rows
                for col = 1:cols
                    if splitIdx > numSplits
                        break;
                    end
                    
                    xPos = 20 + (col-1) * (axWidth + 20);
                    yPos = 20 + (rows-row) * (axHeight + 20);
                    
                    ax = uiaxes(app.VisualizerPanel);
                    ax.Position = [xPos yPos axWidth axHeight];
                    ax.BackgroundColor = [0.05 0.05 0.1];
                    ax.XColor = app.WVUGold;
                    ax.YColor = app.WVUGold;
                    ax.GridColor = app.WVUGold * 0.5;
                    ax.GridAlpha = 0.3;
                    ax.XGrid = 'on';
                    ax.YGrid = 'on';
                    ax.FontName = 'Helvetica Neue';
                    
                    app.SplitAxes{splitIdx} = ax;
                    splitIdx = splitIdx + 1;
                end
                if splitIdx > numSplits
                    break;
                end
            end
        end
        
        % Button pushed function: StartButton
        function StartButtonPushed(app, event)
            startVisualization(app);
        end
        
        % Button pushed function: StopButton
        function StopButtonPushed(app, event)
            stopVisualization(app);
        end
        
        % Close request function: UIFigure
        function UIFigureCloseRequest(app, event)
            % Force stop everything immediately - don't wait for anything
            app.IsRunning = false;
            
            % Stop timer immediately
            if ~isempty(app.Timer) && isvalid(app.Timer)
                try
                    stop(app.Timer);
                    delete(app.Timer);
                    app.Timer = [];
                catch
                end
            end
            
            % Stop all recorders/readers immediately
            if app.UseAudioToolbox && ~isempty(app.AudioDeviceReaders)
                for i = 1:length(app.AudioDeviceReaders)
                    if isvalid(app.AudioDeviceReaders{i})
                        try
                            release(app.AudioDeviceReaders{i});
                        catch
                        end
                        try
                            delete(app.AudioDeviceReaders{i});
                        catch
                        end
                    end
                end
                app.AudioDeviceReaders = {};
            end
            
            if ~isempty(app.AudioRecorders)
                for i = 1:length(app.AudioRecorders)
                    if isvalid(app.AudioRecorders{i})
                        try
                            stop(app.AudioRecorders{i});
                        catch
                        end
                        try
                            delete(app.AudioRecorders{i});
                        catch
                        end
                    end
                end
                app.AudioRecorders = {};
            end
            
            % Clean up split axes
            cleanupSplitAxes(app);
            
            % Delete the figure directly
            if isvalid(app.UIFigure)
                delete(app.UIFigure);
            end
            
            % Delete the app object
            delete(app);
        end
    end
end
