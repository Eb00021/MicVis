classdef MicVisualizer < matlab.apps.AppBase
    properties (Access = public)
        UIFigure                matlab.ui.Figure
        MainPanel               matlab.ui.container.Panel
        VisualizerPanel         matlab.ui.container.Panel
        ControlPanel            matlab.ui.container.Panel
        StartButton             matlab.ui.control.Button
        PauseButton             matlab.ui.control.Button
        StopButton              matlab.ui.control.Button
        FullscreenButton        matlab.ui.control.Button
        MicAxes                 matlab.ui.control.UIAxes
        StatusLabel             matlab.ui.control.Label
        DarkModeLabel           matlab.ui.control.Label
        DarkModeSwitch          matlab.ui.control.Switch
        WVULogo                 matlab.ui.control.Image
        WVULogoHtml             matlab.ui.control.HTML
        TitleLabel              matlab.ui.control.Label
        FFTDisplayCheckBox      matlab.ui.control.CheckBox
        WaveformDisplayCheckBox matlab.ui.control.CheckBox
        GainSlider              matlab.ui.control.Slider
        GainLabel               matlab.ui.control.Label
        GainValueLabel          matlab.ui.control.Label
        YAxisRangeSlider        matlab.ui.control.Slider
        YAxisRangeLabel         matlab.ui.control.Label
        YAxisRangeValueLabel    matlab.ui.control.Label
        AutoRangeButton         matlab.ui.control.Button
        SampleRateLabel         matlab.ui.control.Label
        SampleRateSpinner       matlab.ui.control.Spinner
        SelectInputsButton       matlab.ui.control.Button
        LineColorsButton          matlab.ui.control.Button
        ColorPickerPanel          matlab.ui.container.Panel
        ColorPreviewBox           matlab.ui.control.Label
        ChannelDropdown           matlab.ui.control.DropDown
        ColorRedSlider            matlab.ui.control.Slider
        ColorGreenSlider          matlab.ui.control.Slider
        ColorBlueSlider           matlab.ui.control.Slider
        ColorRedLabel             matlab.ui.control.Label
        ColorGreenLabel           matlab.ui.control.Label
        ColorBlueLabel            matlab.ui.control.Label
        ApplyColorButton          matlab.ui.control.Button
    end
    
    properties (Access = private)
        AudioRecorders
        AudioDeviceReaders
        UseAudioToolbox = false
        UseDataAcq = false
        DataAcqSession
        DataAcqListener
        Timer
        IsRunning = false
        IsPaused = false
        NumMics = 1
        NumChannels = 1
        SampleRate = 44100
        BufferSize = 4096
        SelectedDeviceIDs = []
        SelectedDeviceNames = {}
        SelectedAudioDeviceName = ''
        SelectedAudioDriver = ''
        ChannelColors = []  % Nx3 matrix of RGB colors for each channel
        PlotLines = {}  % Cell array of line handles for efficient updates
        AudioHistory = {}
        LegacyLastTotalSamples = 0
        LegacyNoDataCount = 0
        LegacyMaxNoDataFrames = 20
        LegacyRestartCooldownSeconds = 2
        LegacyRestartCooldownUntil = 0
        LegacyErrorShown = false
        DataAcqNoDataCount = 0
        DataAcqMaxNoDataFrames = 20
        AppRootDir = ''
        AppIconPath = ''
        AppFontName = 'Segoe UI'
        PrefsFilePath = ''
        IsApplyingPrefs = false
        SelectedDataAcqVendor = ''
        SelectedDataAcqDeviceId = ''
        ApplyInitialFftRange = false
        LastWaveformData = []
        LastFftMagnitude = []
        LogoImageOriginal = []
        LogoImageInverted = []
        LogoImageSupportsInvert = false
        LogoImageOriginalPath = ''
        LogoImageInvertedPath = ''
        WVUGold = [238, 170, 0] / 255
        WVUBlue = [0, 40, 85] / 255
        WVUBlueLight = [0, 60, 120] / 255
        UseDarkMode = true
        ThemeLight = struct( ...
            'Window', [0.94 0.96 0.98], ...
            'Panel', [0.96 0.97 0.99], ...
            'PanelAlt', [0.92 0.94 0.97], ...
            'Border', [0.80 0.85 0.90], ...
            'Text', [0.12 0.16 0.22], ...
            'TextMuted', [0.35 0.40 0.46], ...
            'Title', [0.10 0.14 0.20], ...
            'Accent', [238, 170, 0] / 255, ...
            'AccentText', [0.08 0.14 0.28], ...
            'AxisBg', [1.00 1.00 1.00], ...
            'AxisText', [0.12 0.16 0.22], ...
            'AxisGrid', [0.85 0.88 0.92], ...
            'SliderTrack', [0.25 0.30 0.38], ...
            'SliderThumb', [0.94 0.94 0.98], ...
            'ButtonSecondary', [238, 170, 0] / 255, ...
            'ButtonSecondaryText', [0.08 0.14 0.28], ...
            'Success', [0.20 0.60 0.20], ...
            'Danger', [0.60 0.20 0.20]);
        ThemeDark = struct( ...
            'Window', [0.00 0.00 0.00], ...
            'Panel', [0.05 0.05 0.07], ...
            'PanelAlt', [0.08 0.08 0.10], ...
            'Border', [0.20 0.20 0.20], ...
            'Text', [0.90 0.92 0.96], ...
            'TextMuted', [0.65 0.70 0.78], ...
            'Title', [0.95 0.88 0.60], ...
            'Accent', [238, 170, 0] / 255, ...
            'AccentText', [0.08 0.10 0.14], ...
            'AxisBg', [0.00 0.00 0.00], ...
            'AxisText', [0.92 0.92 0.96], ...
            'AxisGrid', [0.30 0.30 0.30], ...
            'SliderTrack', [0.85 0.86 0.92], ...
            'SliderThumb', [0.12 0.14 0.18], ...
            'ButtonSecondary', [238, 170, 0] / 255, ...
            'ButtonSecondaryText', [0.08 0.10 0.14], ...
            'Success', [0.20 0.60 0.20], ...
            'Danger', [0.60 0.20 0.20]);
        CurrentYLim = [-1, 1]
        CurrentXLim = [0, 0.5]
        SmoothingFactor = 0.1
    end
    
    methods (Access = private)
        
        function createComponents(app)
            initializeAppContext(app);
            createUIFigure(app);
            createMainPanel(app);
            createHeaderSection(app);
            createVisualizerSection(app);
            createControlSection(app);
            finalizeUI(app);
        end

        function initializeAppContext(app)
            app.AppRootDir = fileparts(mfilename('fullpath'));
            if isempty(app.AppRootDir)
                app.AppRootDir = pwd;
            end
            app.AppFontName = resolveAppFont(app);
        end

        function createUIFigure(app)
            app.UIFigure = uifigure('Visible', 'off');
            app.UIFigure.Position = [100 100 1200 800];
            if isprop(app.UIFigure, 'WindowState')
                app.UIFigure.WindowState = 'normal';
            end
            if isprop(app.UIFigure, 'Resize')
                app.UIFigure.Resize = 'on';
            end
            app.UIFigure.Name = 'WVU EcoCAR - Microphone Audio Visualizer';
            app.UIFigure.Color = app.WVUBlue;

            iconSet = false;
            iconCandidates = {'icon.png', 'icon.jpg', 'icon.jpeg', 'icon.gif', 'icon.svg'};
            for k = 1:numel(iconCandidates)
                iconPath = resolveAppFile(app, iconCandidates{k});
                if ~isempty(iconPath)
                    app.UIFigure.Icon = iconPath;
                    app.AppIconPath = iconPath;
                    iconSet = true;
                    break;
                end
            end
            if ~iconSet
                iconIco = resolveAppFile(app, 'icon.ico');
                if ~isempty(iconIco)
                    try
                        img = imread(iconIco);
                        iconPng = fullfile(app.AppRootDir, 'icon.png');
                        imwrite(img, iconPng);
                        if exist(iconPng, 'file')
                            app.UIFigure.Icon = iconPng;
                            app.AppIconPath = iconPng;
                            iconSet = true;
                        end
                    catch
                        warning('Icon file icon.ico found but cannot be used directly. MATLAB uifigure.Icon requires PNG, JPG, GIF, or SVG format. Provide icon.png manually.');
                    end
                end
            end

            app.UIFigure.CloseRequestFcn = createCallbackFcn(app, @UIFigureCloseRequest, true);
            app.UIFigure.WindowKeyPressFcn = createCallbackFcn(app, @UIFigureKeyPress, true);

            % Enable OpenGL hardware acceleration for maximum performance
            try
                opengl('hardware');
                % Set OpenGL software flag to false for hardware rendering
                opengl software false;
            catch
                % Try basic hardware mode
                try
                    opengl hardware;
                catch
                    warning('OpenGL hardware acceleration may not be available');
                end
            end
            
            % Set graphics smoothing for better quality
            try
                set(0, 'DefaultFigureGraphicsSmoothing', 'on');
            catch
            end
        end

        function createMainPanel(app)
            app.MainPanel = uipanel(app.UIFigure);
            app.MainPanel.BackgroundColor = app.WVUBlue;
            app.MainPanel.Units = 'normalized';
            app.MainPanel.Position = [0 0 1 1];
        end

        function createHeaderSection(app)
            app.TitleLabel = uilabel(app.MainPanel);
            app.TitleLabel.Text = 'WVU EcoCAR EV Challenge - Microphone Visualizer';
            app.TitleLabel.FontName = app.AppFontName;
            app.TitleLabel.FontSize = 24;
            app.TitleLabel.FontWeight = 'bold';
            app.TitleLabel.FontColor = app.WVUGold;
            app.TitleLabel.BackgroundColor = app.WVUBlue;
            app.TitleLabel.Position = [20 750 760 40];
            app.TitleLabel.HorizontalAlignment = 'left';

            app.WVULogo = uiimage(app.MainPanel);
            app.WVULogo.Position = [800 746 120 44];
            app.WVULogo.Visible = 'off';
            app.WVULogoHtml = uihtml(app.MainPanel);
            app.WVULogoHtml.Position = app.WVULogo.Position;
            app.WVULogoHtml.Visible = 'off';

            % Try to load logo - MATLAB uiimage supports PNG/JPG/BMP/TIFF
            logoLoaded = false;
            logoPath = '';
            invertedLogoPath = '';
            logoCandidates = {'logo.png', 'logo.jpg', 'logo.jpeg', 'logo.bmp', 'logo.tif', 'logo.tiff', 'logo.svg'};
            invertedCandidates = {'logoINV.png', 'logoINV.jpg', 'logoINV.jpeg', 'logoINV.bmp', 'logoINV.tif', 'logoINV.tiff', 'logoINV.svg'};
            invertedLogoPath = findFirstExistingFile(app, invertedCandidates);
            logoPath = findFirstExistingFile(app, logoCandidates);

            if ~isempty(logoPath)
                logoLoaded = setLogoSource(app, logoPath);
            end
            if ~logoLoaded && ~isempty(invertedLogoPath)
                logoLoaded = setLogoSource(app, invertedLogoPath);
                if logoLoaded
                    logoPath = invertedLogoPath;
                end
            end

            if logoLoaded
                app.LogoImageOriginalPath = logoPath;
                app.LogoImageInvertedPath = invertedLogoPath;
                [logoImg, canInvert] = tryLoadLogoImage(app, logoPath);
                app.LogoImageOriginal = logoImg;
                if canInvert
                    app.LogoImageInverted = invertLogoImage(app, logoImg);
                    app.LogoImageSupportsInvert = true;
                else
                    app.LogoImageSupportsInvert = false;
                end
            else
                if ~isempty(invertedLogoPath) || ~isempty(logoPath)
                    if endsWith(lower(string(invertedLogoPath)), ".svg") || endsWith(lower(string(logoPath)), ".svg")
                        warning('SVG logo found but uiimage may not support it. Consider converting to PNG format.');
                    end
                end
            end
        end

        function createVisualizerSection(app)
            % Main visualization panel and axes.
            app.VisualizerPanel = uipanel(app.MainPanel);
            app.VisualizerPanel.Title = 'Audio Visualization';
            app.VisualizerPanel.BackgroundColor = [0.1 0.1 0.15];
            app.VisualizerPanel.ForegroundColor = app.WVUGold;
            app.VisualizerPanel.FontName = app.AppFontName;
            app.VisualizerPanel.FontSize = 14;
            app.VisualizerPanel.FontWeight = 'bold';
            app.VisualizerPanel.Position = [20 100 900 620];

            app.MicAxes = uiaxes(app.VisualizerPanel);
            app.MicAxes.Position = [20 20 860 570];
            app.MicAxes.BackgroundColor = [0.05 0.05 0.1];
            app.MicAxes.XColor = app.WVUGold;
            app.MicAxes.YColor = app.WVUGold;
            app.MicAxes.GridColor = app.WVUGold * 0.5;
            app.MicAxes.GridAlpha = 0.3;
            app.MicAxes.XGrid = 'on';
            app.MicAxes.YGrid = 'on';
            app.MicAxes.FontName = app.AppFontName;
            app.MicAxes.XLabel.String = 'Time (s)';
            app.MicAxes.XLabel.Color = app.WVUGold;
            app.MicAxes.YLabel.String = 'Amplitude';
            app.MicAxes.YLabel.Color = app.WVUGold;
            app.MicAxes.Title.String = 'Real-Time Audio Waveform';
            app.MicAxes.Title.Color = app.WVUGold;
            app.MicAxes.Title.FontWeight = 'bold';
            
            % Enable smooth line rendering
            try
                app.MicAxes.LineSmoothing = 'on';
            catch
                % LineSmoothing may not be available on all systems
            end
        end

        function createControlSection(app)
            % Right-side controls for audio configuration and runtime actions.
            app.ControlPanel = uipanel(app.MainPanel);
            app.ControlPanel.Title = 'Controls';
            app.ControlPanel.BackgroundColor = app.WVUBlueLight;
            app.ControlPanel.ForegroundColor = app.WVUGold;
            app.ControlPanel.FontName = app.AppFontName;
            app.ControlPanel.FontSize = 14;
            app.ControlPanel.FontWeight = 'bold';
            app.ControlPanel.Position = [940 20 240 760];

            % Select Input Device Button (shows device name when selected)
            app.SelectInputsButton = uibutton(app.ControlPanel, 'push');
            app.SelectInputsButton.ButtonPushedFcn = createCallbackFcn(app, @SelectInputsButtonPushed, true);
            app.SelectInputsButton.Text = 'Select Input Device';
            app.SelectInputsButton.FontName = app.AppFontName;
            app.SelectInputsButton.FontSize = 10;
            app.SelectInputsButton.FontWeight = 'bold';
            app.SelectInputsButton.BackgroundColor = app.WVUGold;
            app.SelectInputsButton.FontColor = app.WVUBlue;
            app.SelectInputsButton.Position = [20 700 200 32];
            app.SelectInputsButton.Tooltip = 'Click to select audio input device';

            % Sample Rate Spinner
            app.SampleRateLabel = uilabel(app.ControlPanel);
            app.SampleRateLabel.Text = 'Sample Rate (Hz):';
            app.SampleRateLabel.FontName = app.AppFontName;
            app.SampleRateLabel.FontSize = 12;
            app.SampleRateLabel.FontColor = app.WVUGold;
            app.SampleRateLabel.Position = [20 660 140 22];
            app.SampleRateLabel.HorizontalAlignment = 'left';

            app.SampleRateSpinner = uispinner(app.ControlPanel);
            app.SampleRateSpinner.Limits = [8000 192000];
            app.SampleRateSpinner.Value = 44100;
            app.SampleRateSpinner.Step = 1000;
            app.SampleRateSpinner.Position = [150 660 70 22];
            app.SampleRateSpinner.ValueDisplayFormat = '%.0f';
            app.SampleRateSpinner.ValueChangedFcn = createCallbackFcn(app, @SampleRateSpinnerValueChanged, true);

            % Gain Slider
            app.GainLabel = uilabel(app.ControlPanel);
            app.GainLabel.Text = 'Gain:';
            app.GainLabel.FontName = app.AppFontName;
            app.GainLabel.FontSize = 12;
            app.GainLabel.FontColor = app.WVUGold;
            app.GainLabel.Position = [20 610 120 22];
            app.GainLabel.HorizontalAlignment = 'left';

            app.GainValueLabel = uilabel(app.ControlPanel);
            app.GainValueLabel.Text = sprintf('%.2f', 1);
            app.GainValueLabel.FontName = app.AppFontName;
            app.GainValueLabel.FontSize = 11;
            app.GainValueLabel.FontColor = app.WVUGold;
            app.GainValueLabel.Position = [160 610 60 22];
            app.GainValueLabel.HorizontalAlignment = 'right';

            app.GainSlider = uislider(app.ControlPanel);
            app.GainSlider.Limits = [0.1 100];
            app.GainSlider.Value = 1;
            app.GainSlider.Position = [20 590 200 3];
            app.GainSlider.MajorTicks = [];  % Remove tick labels for cleaner look
            app.GainSlider.MinorTicks = [];
            app.GainSlider.ValueChangedFcn = createCallbackFcn(app, @GainSliderValueChanged, true);
            app.GainSlider.ValueChangingFcn = createCallbackFcn(app, @GainSliderValueChanging, true);

            % Y-Axis Range Slider
            app.YAxisRangeLabel = uilabel(app.ControlPanel);
            app.YAxisRangeLabel.Text = 'Y Range (+/-):';
            app.YAxisRangeLabel.FontName = app.AppFontName;
            app.YAxisRangeLabel.FontSize = 12;
            app.YAxisRangeLabel.FontColor = app.WVUGold;
            app.YAxisRangeLabel.Position = [20 555 120 22];
            app.YAxisRangeLabel.HorizontalAlignment = 'left';

            app.YAxisRangeValueLabel = uilabel(app.ControlPanel);
            app.YAxisRangeValueLabel.Text = '1.00';
            app.YAxisRangeValueLabel.FontName = app.AppFontName;
            app.YAxisRangeValueLabel.FontSize = 11;
            app.YAxisRangeValueLabel.FontColor = app.WVUGold;
            app.YAxisRangeValueLabel.Position = [160 555 60 22];
            app.YAxisRangeValueLabel.HorizontalAlignment = 'right';

            app.YAxisRangeSlider = uislider(app.ControlPanel);
            app.YAxisRangeSlider.Limits = [0.1 5];
            app.YAxisRangeSlider.Value = 1;
            app.YAxisRangeSlider.Position = [20 535 200 3];
            app.YAxisRangeSlider.MajorTicks = [];  % Remove tick labels for cleaner look
            app.YAxisRangeSlider.MinorTicks = [];
            app.YAxisRangeSlider.ValueChangedFcn = createCallbackFcn(app, @YAxisRangeSliderValueChanged, true);
            app.YAxisRangeSlider.ValueChangingFcn = createCallbackFcn(app, @YAxisRangeSliderValueChanging, true);

            % Auto Range Button
            app.AutoRangeButton = uibutton(app.ControlPanel, 'push');
            app.AutoRangeButton.ButtonPushedFcn = createCallbackFcn(app, @AutoRangeButtonPushed, true);
            app.AutoRangeButton.Text = 'Auto Range';
            app.AutoRangeButton.FontName = app.AppFontName;
            app.AutoRangeButton.FontSize = 10;
            app.AutoRangeButton.FontWeight = 'bold';
            app.AutoRangeButton.BackgroundColor = app.WVUGold;
            app.AutoRangeButton.FontColor = app.WVUBlue;
            app.AutoRangeButton.Position = [20 495 200 24];

            % Display Options
            app.WaveformDisplayCheckBox = uicheckbox(app.ControlPanel);
            app.WaveformDisplayCheckBox.Text = 'Waveform Display';
            app.WaveformDisplayCheckBox.FontName = app.AppFontName;
            app.WaveformDisplayCheckBox.FontSize = 12;
            app.WaveformDisplayCheckBox.FontColor = app.WVUGold;
            app.WaveformDisplayCheckBox.Value = true;
            app.WaveformDisplayCheckBox.Position = [20 460 150 22];
            app.WaveformDisplayCheckBox.ValueChangedFcn = createCallbackFcn(app, @DisplayOptionValueChanged, true);

            app.FFTDisplayCheckBox = uicheckbox(app.ControlPanel);
            app.FFTDisplayCheckBox.Text = 'FFT Display';
            app.FFTDisplayCheckBox.FontName = app.AppFontName;
            app.FFTDisplayCheckBox.FontSize = 12;
            app.FFTDisplayCheckBox.FontColor = app.WVUGold;
            app.FFTDisplayCheckBox.Value = false;
            app.FFTDisplayCheckBox.Position = [20 435 150 22];
            app.FFTDisplayCheckBox.ValueChangedFcn = createCallbackFcn(app, @DisplayOptionValueChanged, true);

            % Fullscreen Button
            app.FullscreenButton = uibutton(app.ControlPanel, 'push');
            app.FullscreenButton.ButtonPushedFcn = createCallbackFcn(app, @FullscreenButtonPushed, true);
            app.FullscreenButton.Text = 'Fullscreen';
            app.FullscreenButton.FontName = app.AppFontName;
            app.FullscreenButton.FontSize = 11;
            app.FullscreenButton.FontWeight = 'bold';
            app.FullscreenButton.BackgroundColor = app.WVUGold;
            app.FullscreenButton.FontColor = app.WVUBlue;
            app.FullscreenButton.Position = [20 398 200 26];

            % Line Colors Button
            app.LineColorsButton = uibutton(app.ControlPanel, 'push');
            app.LineColorsButton.ButtonPushedFcn = createCallbackFcn(app, @LineColorsButtonPushed, true);
            app.LineColorsButton.Text = 'Line Colors';
            app.LineColorsButton.FontName = app.AppFontName;
            app.LineColorsButton.FontSize = 11;
            app.LineColorsButton.FontWeight = 'bold';
            app.LineColorsButton.BackgroundColor = app.WVUGold;
            app.LineColorsButton.FontColor = app.WVUBlue;
            app.LineColorsButton.Position = [20 366 200 26];
            app.LineColorsButton.Tooltip = 'Change line colors for each channel';
            
            % Color Picker Panel (initially hidden)
            createColorPickerPanel(app);

            % Start Button
            app.StartButton = uibutton(app.ControlPanel, 'push');
            app.StartButton.ButtonPushedFcn = createCallbackFcn(app, @StartButtonPushed, true);
            app.StartButton.Text = 'Start';
            app.StartButton.FontName = app.AppFontName;
            app.StartButton.FontSize = 14;
            app.StartButton.FontWeight = 'bold';
            app.StartButton.BackgroundColor = [0.2 0.6 0.2];
            app.StartButton.FontColor = [1 1 1];
            app.StartButton.Position = [20 315 200 40];

            % Pause Button (gray when not started)
            app.PauseButton = uibutton(app.ControlPanel, 'push');
            app.PauseButton.ButtonPushedFcn = createCallbackFcn(app, @PauseButtonPushed, true);
            app.PauseButton.Text = 'Pause';
            app.PauseButton.FontName = app.AppFontName;
            app.PauseButton.FontSize = 14;
            app.PauseButton.FontWeight = 'bold';
            app.PauseButton.BackgroundColor = [0.5 0.5 0.5];
            app.PauseButton.FontColor = [1 1 1];
            app.PauseButton.Position = [20 270 200 40];
            app.PauseButton.Enable = 'off';

            % Stop Button
            app.StopButton = uibutton(app.ControlPanel, 'push');
            app.StopButton.ButtonPushedFcn = createCallbackFcn(app, @StopButtonPushed, true);
            app.StopButton.Text = 'Stop';
            app.StopButton.FontName = app.AppFontName;
            app.StopButton.FontSize = 14;
            app.StopButton.FontWeight = 'bold';
            app.StopButton.BackgroundColor = [0.6 0.2 0.2];
            app.StopButton.FontColor = [1 1 1];
            app.StopButton.Position = [20 225 200 40];
            app.StopButton.Enable = 'off';

            % Status Label
            app.StatusLabel = uilabel(app.ControlPanel);
            app.StatusLabel.Text = 'Status: Ready';
            app.StatusLabel.FontName = app.AppFontName;
            app.StatusLabel.FontSize = 11;
            app.StatusLabel.FontColor = app.WVUGold;
            app.StatusLabel.Position = [20 195 200 22];
            app.StatusLabel.HorizontalAlignment = 'left';

            % Dark Mode Toggle
            app.DarkModeLabel = uilabel(app.ControlPanel);
            app.DarkModeLabel.Text = 'Dark Mode';
            app.DarkModeLabel.FontName = app.AppFontName;
            app.DarkModeLabel.FontSize = 11;
            app.DarkModeLabel.FontColor = app.WVUGold;
            app.DarkModeLabel.Position = [20 160 80 22];
            app.DarkModeLabel.HorizontalAlignment = 'left';

            app.DarkModeSwitch = uiswitch(app.ControlPanel, 'slider');
            app.DarkModeSwitch.Items = {'Light', 'Dark'};
            app.DarkModeSwitch.Value = 'Dark';
            app.DarkModeSwitch.Position = [110 160 70 22];
            app.DarkModeSwitch.ValueChangedFcn = createCallbackFcn(app, @DarkModeSwitchValueChanged, true);
        end

        function finalizeUI(app)
            % Apply theme and show window after all components exist.
            applyTheme(app);
            updateDisplayOptionState(app, []);
            app.UIFigure.Visible = 'on';
        end

        function colors = getThemeColors(app)
            if app.UseDarkMode
                colors = app.ThemeDark;
            else
                colors = app.ThemeLight;
            end
        end

        function applyAxesTheme(app, ax)
            if isempty(ax) || ~isvalid(ax)
                return;
            end
            colors = getThemeColors(app);
            if isprop(ax, 'BackgroundColor')
                ax.BackgroundColor = colors.AxisBg;
            end
            if isprop(ax, 'Color')
                ax.Color = colors.AxisBg;
            end
            ax.XColor = colors.AxisText;
            ax.YColor = colors.AxisText;
            ax.GridColor = colors.AxisGrid;
            ax.GridAlpha = 0.3;
            ax.XGrid = 'on';
            ax.YGrid = 'on';
            ax.XLabel.Color = colors.AxisText;
            ax.YLabel.Color = colors.AxisText;
            ax.Title.Color = colors.AxisText;
        end

        function applyTheme(app)
            if isempty(app.UIFigure) || ~isvalid(app.UIFigure)
                return;
            end
            colors = getThemeColors(app);

            app.UIFigure.Color = colors.Window;
            app.MainPanel.BackgroundColor = colors.Window;
            app.MainPanel.BorderType = 'none';

            app.TitleLabel.FontColor = colors.Title;
            if isprop(app.TitleLabel, 'BackgroundColor')
                app.TitleLabel.BackgroundColor = colors.Window;
            end

            app.VisualizerPanel.BackgroundColor = colors.Panel;
            app.VisualizerPanel.ForegroundColor = colors.Text;
            app.VisualizerPanel.BorderType = 'line';
            if isprop(app.VisualizerPanel, 'BorderColor')
                app.VisualizerPanel.BorderColor = colors.Border;
            end

            app.ControlPanel.BackgroundColor = colors.PanelAlt;
            app.ControlPanel.ForegroundColor = colors.Text;
            app.ControlPanel.BorderType = 'line';
            if isprop(app.ControlPanel, 'BorderColor')
                app.ControlPanel.BorderColor = colors.Border;
            end

            % Labels and toggles
            labelHandles = {app.SampleRateLabel, app.GainLabel, ...
                app.GainValueLabel, app.YAxisRangeLabel, app.YAxisRangeValueLabel, ...
                app.WaveformDisplayCheckBox, app.FFTDisplayCheckBox, app.StatusLabel, ...
                app.DarkModeLabel};
            for i = 1:numel(labelHandles)
                if ~isempty(labelHandles{i}) && isvalid(labelHandles{i})
                    labelHandles{i}.FontColor = colors.Text;
                end
            end

            if ~isempty(app.SampleRateSpinner) && isvalid(app.SampleRateSpinner)
                if isprop(app.SampleRateSpinner, 'FontColor')
                    app.SampleRateSpinner.FontColor = colors.Text;
                end
                if isprop(app.SampleRateSpinner, 'BackgroundColor')
                    app.SampleRateSpinner.BackgroundColor = colors.Panel;
                end
            end

            if ~isempty(app.DarkModeSwitch) && isvalid(app.DarkModeSwitch)
                if isprop(app.DarkModeSwitch, 'FontColor')
                    app.DarkModeSwitch.FontColor = colors.Text;
                end
            end

            sliderHandles = {app.GainSlider, app.YAxisRangeSlider};
            for i = 1:numel(sliderHandles)
                slider = sliderHandles{i};
                if ~isempty(slider) && isvalid(slider)
                    if isprop(slider, 'FontColor')
                        slider.FontColor = colors.Text;
                    end
                    if isprop(slider, 'BackgroundColor')
                        slider.BackgroundColor = colors.Panel;
                    end
                    if isprop(slider, 'TrackColor')
                        slider.TrackColor = colors.SliderTrack;
                    end
                    if isprop(slider, 'ThumbColor')
                        slider.ThumbColor = colors.SliderThumb;
                    end
                end
            end

            % Buttons
            app.SelectInputsButton.BackgroundColor = colors.ButtonSecondary;
            app.SelectInputsButton.FontColor = colors.ButtonSecondaryText;
            app.LineColorsButton.BackgroundColor = colors.ButtonSecondary;
            app.LineColorsButton.FontColor = colors.ButtonSecondaryText;
            app.FullscreenButton.BackgroundColor = colors.ButtonSecondary;
            app.FullscreenButton.FontColor = colors.ButtonSecondaryText;
            if ~isempty(app.AutoRangeButton) && isvalid(app.AutoRangeButton)
                app.AutoRangeButton.BackgroundColor = colors.ButtonSecondary;
                app.AutoRangeButton.FontColor = colors.ButtonSecondaryText;
            end
            app.StartButton.BackgroundColor = colors.Success;
            app.StartButton.FontColor = [1 1 1];
            app.StopButton.BackgroundColor = colors.Danger;
            app.StopButton.FontColor = [1 1 1];

            if ~isempty(app.WVULogo) && isvalid(app.WVULogo)
                if app.UseDarkMode
                    if ~isempty(app.LogoImageInvertedPath)
                        setLogoSource(app, app.LogoImageInvertedPath);
                    elseif app.LogoImageSupportsInvert
                        if ~isempty(app.WVULogoHtml) && isvalid(app.WVULogoHtml)
                            app.WVULogoHtml.Visible = 'off';
                        end
                        app.WVULogo.ImageSource = app.LogoImageInverted;
                        app.WVULogo.Visible = 'on';
                    end
                else
                    if ~isempty(app.LogoImageOriginalPath)
                        setLogoSource(app, app.LogoImageOriginalPath);
                    elseif ~isempty(app.LogoImageOriginal)
                        if ~isempty(app.WVULogoHtml) && isvalid(app.WVULogoHtml)
                            app.WVULogoHtml.Visible = 'off';
                        end
                        app.WVULogo.ImageSource = app.LogoImageOriginal;
                        app.WVULogo.Visible = 'on';
                    end
                end
            end

            % Axes theme
            applyAxesTheme(app, app.MicAxes);
            applyLegendTheme(app, app.MicAxes, colors);
            
            % Color picker panel theme
            if ~isempty(app.ColorPickerPanel) && isvalid(app.ColorPickerPanel)
                app.ColorPickerPanel.BackgroundColor = colors.PanelAlt;
                if isprop(app.ColorPickerPanel, 'BorderColor')
                    app.ColorPickerPanel.BorderColor = colors.Border;
                end
            end
        end

        function updateDisplayOptionState(app, sourceControl)
            if nargin < 2
                sourceControl = [];
            end
            if isempty(app.WaveformDisplayCheckBox) || isempty(app.FFTDisplayCheckBox)
                return;
            end
            showWaveform = app.WaveformDisplayCheckBox.Value;
            showFFT = app.FFTDisplayCheckBox.Value;

            if showWaveform && showFFT
                if ~isempty(sourceControl) && isvalid(sourceControl)
                    if sourceControl == app.WaveformDisplayCheckBox
                        app.FFTDisplayCheckBox.Value = false;
                        showFFT = false;
                    elseif sourceControl == app.FFTDisplayCheckBox
                        app.WaveformDisplayCheckBox.Value = false;
                        showWaveform = false;
                    else
                        app.FFTDisplayCheckBox.Value = false;
                        showFFT = false;
                    end
                else
                    app.FFTDisplayCheckBox.Value = false;
                    showFFT = false;
                end
            end

            if showWaveform
                app.WaveformDisplayCheckBox.Enable = 'on';
                app.FFTDisplayCheckBox.Enable = 'off';
            elseif showFFT
                app.WaveformDisplayCheckBox.Enable = 'off';
                app.FFTDisplayCheckBox.Enable = 'on';
            else
                app.WaveformDisplayCheckBox.Enable = 'on';
                app.FFTDisplayCheckBox.Enable = 'on';
            end
        end

        function filePath = resolveAppFile(app, fileName)
            filePath = '';
            if isempty(fileName)
                return;
            end
            baseDir = app.AppRootDir;
            if isempty(baseDir)
                baseDir = pwd;
            end
            candidate = fullfile(baseDir, fileName);
            if exist(candidate, 'file')
                filePath = candidate;
            end
        end

        function filePath = findFirstExistingFile(app, fileNames)
            filePath = '';
            if isempty(fileNames)
                return;
            end
            for k = 1:numel(fileNames)
                candidate = resolveAppFile(app, fileNames{k});
                if ~isempty(candidate)
                    filePath = candidate;
                    return;
                end
            end
        end

        function wasSet = setLogoSource(app, imagePath)
            wasSet = false;
            if isempty(imagePath)
                return;
            end
            [~, ~, ext] = fileparts(imagePath);
            if strcmpi(ext, '.svg')
                wasSet = setSvgLogo(app, imagePath);
                return;
            end
            if isempty(app.WVULogo) || ~isvalid(app.WVULogo)
                return;
            end
            try
                app.WVULogo.ImageSource = imagePath;
                app.WVULogo.Visible = 'on';
                if ~isempty(app.WVULogoHtml) && isvalid(app.WVULogoHtml)
                    app.WVULogoHtml.Visible = 'off';
                end
                wasSet = true;
            catch
                wasSet = false;
            end
        end

        function wasSet = setSvgLogo(app, svgPath)
            wasSet = false;
            if isempty(app.WVULogoHtml) || ~isvalid(app.WVULogoHtml)
                return;
            end
            htmlPath = ensureSvgHtml(app, svgPath);
            if isempty(htmlPath)
                return;
            end
            try
                app.WVULogoHtml.HTMLSource = htmlPath;
                app.WVULogoHtml.Visible = 'on';
                if ~isempty(app.WVULogo) && isvalid(app.WVULogo)
                    app.WVULogo.Visible = 'off';
                end
                wasSet = true;
            catch
                wasSet = false;
            end
        end

        function htmlPath = ensureSvgHtml(app, svgPath)
            htmlPath = '';
            if isempty(svgPath)
                return;
            end
            try
                svgText = fileread(svgPath);
            catch
                return;
            end
            [~, name, ~] = fileparts(svgPath);
            htmlPath = fullfile(app.AppRootDir, sprintf('%s_svg.html', name));
            html = [
                "<html><head><meta charset=""utf-8"">" ...
                "<style>html,body{margin:0;padding:0;width:100%;height:100%;background:transparent;overflow:hidden;}" ...
                "svg{width:100%;height:100%;}</style></head><body>" ...
                svgText ...
                "</body></html>"
            ];
            try
                fid = fopen(htmlPath, 'w');
                if fid < 0
                    htmlPath = '';
                    return;
                end
                fwrite(fid, html);
                fclose(fid);
            catch
                htmlPath = '';
            end
        end

        function iconVal = getDialogIcon(app, fallback)
            iconVal = fallback;
            iconPath = '';
            if ~isempty(app.UIFigure) && isvalid(app.UIFigure)
                iconPath = app.UIFigure.Icon;
            end
            if isempty(iconPath) && ~isempty(app.AppIconPath)
                iconPath = app.AppIconPath;
            end
            if ~isempty(iconPath)
                iconVal = iconPath;
            end
        end

        function applyDialogIcon(app, dialogFig)
            if isempty(dialogFig) || ~isvalid(dialogFig)
                return;
            end
            iconPath = getDialogIcon(app, '');
            if ~isempty(iconPath)
                try
                    dialogFig.Icon = iconPath;
                catch
                end
            end
        end

        function plotColors = getChannelColors(app, numChannels)
            if numChannels < 1
                plotColors = zeros(0, 3);
                return;
            end
            if app.UseDarkMode
                plotColors = parula(numChannels);
                plotColors = 0.15 + 0.85 * plotColors;
            else
                plotColors = lines(numChannels);
            end
        end

        function applyLegendTheme(app, ax, colors)
            if isempty(ax) || ~isvalid(ax)
                return;
            end
            lgd = [];
            if isprop(ax, 'Legend')
                lgd = ax.Legend;
            end
            if ~isempty(lgd) && isvalid(lgd)
                if isprop(lgd, 'TextColor')
                    lgd.TextColor = colors.AxisText;
                end
                if isprop(lgd, 'Color')
                    lgd.Color = colors.AxisBg;
                end
                if isprop(lgd, 'EdgeColor')
                    lgd.EdgeColor = colors.Border;
                end
            end
        end

        function [img, canInvert] = tryLoadLogoImage(app, logoPath)
            %#ok<INUSD>
            img = [];
            canInvert = false;
            if isempty(logoPath)
                return;
            end
            [~, ~, ext] = fileparts(logoPath);
            if strcmpi(ext, '.svg')
                return;
            end
            try
                [raw, ~, alpha] = imread(logoPath);
                if isempty(raw)
                    return;
                end
                if size(raw, 3) == 1
                    raw = repmat(raw, 1, 1, 3);
                end
                if ~isempty(alpha)
                    raw = cat(3, raw, alpha);
                end
                img = raw;
                canInvert = true;
            catch
                img = [];
                canInvert = false;
            end
        end

        function imgInv = invertLogoImage(app, img)
            %#ok<INUSD>
            imgInv = img;
            if isempty(img)
                return;
            end
            if size(img, 3) < 3
                return;
            end
            rgb = img(:, :, 1:3);
            if isa(rgb, 'uint8')
                rgbInv = 255 - rgb;
            elseif isa(rgb, 'uint16')
                rgbInv = 65535 - rgb;
            elseif isfloat(rgb)
                rgbInv = 1 - rgb;
            else
                rgbInv = 1 - double(rgb);
                rgbInv = cast(rgbInv, class(rgb));
            end
            imgInv(:, :, 1:3) = rgbInv;
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
            hasToolbox = false;
            try
                hasToolbox = license('test', 'Audio_Toolbox');
            catch
            end
            if ~hasToolbox
                try
                    hasToolbox = ~isempty(ver('audio'));
                catch
                end
            end
            if ~hasToolbox
                hasToolbox = exist('audioDeviceReader', 'class') == 8 || exist('audioDeviceReader', 'file') == 2;
            end
            app.UseAudioToolbox = hasToolbox;
        end

        function hasToolbox = checkDataAcqToolbox(app)
            % Check if Data Acquisition Toolbox is available
            hasToolbox = false;
            try
                hasToolbox = license('test', 'Data_Acq_Toolbox');
            catch
            end
            if ~hasToolbox
                try
                    hasToolbox = ~isempty(ver('daq'));
                catch
                end
            end
            if ~hasToolbox
                hasToolbox = exist('daq', 'file') == 2 || exist('daq', 'class') == 8;
            end
            if hasToolbox && exist('daqvendorlist', 'file') == 2
                try
                    if isempty(getOperationalDaqVendor(app))
                        hasToolbox = false;
                    end
                catch
                end
            end
            app.UseDataAcq = hasToolbox;
        end

        function vendorName = getOperationalDaqVendor(app)
            %#ok<INUSD>
            vendorName = '';
            try
                if exist('daqvendorlist', 'file') == 2
                    v = daqvendorlist;
                    if istable(v)
                        ops = v.Operational;
                        if islogical(ops)
                            idx = find(ops, 1);
                        else
                            idx = find(strcmpi(string(ops), "true"), 1);
                        end
                        if ~isempty(idx)
                            vendorName = char(v.ID(idx));
                            return;
                        end
                    end
                end
            catch
            end
        end

        function tf = isOperationalDaqVendor(app, vendorName)
            %#ok<INUSD>
            tf = false;
            if isempty(vendorName)
                return;
            end
            try
                if exist('daqvendorlist', 'file') == 2
                    v = daqvendorlist;
                    if istable(v)
                        idx = find(strcmpi(string(v.ID), string(vendorName)), 1);
                        if ~isempty(idx)
                            ops = v.Operational(idx);
                            if islogical(ops)
                                tf = ops;
                            else
                                tf = strcmpi(string(ops), "true");
                            end
                        end
                    end
                end
            catch
            end
        end

        function fontName = resolveAppFont(app)
            fontName = app.AppFontName;
            fontsDir = fullfile(app.AppRootDir, 'fonts');
            if exist(fontsDir, 'dir') ~= 7
                return;
            end

            preferred = {'HelveticaNeueHeavy.otf', 'HelveticaNeueHeavy.ttf'};
            fontPath = '';
            for i = 1:numel(preferred)
                candidate = fullfile(fontsDir, preferred{i});
                if exist(candidate, 'file') == 2
                    fontPath = candidate;
                    break;
                end
            end

            if isempty(fontPath)
                files = dir(fullfile(fontsDir, '*.otf'));
                if isempty(files)
                    files = dir(fullfile(fontsDir, '*.ttf'));
                end
                if ~isempty(files)
                    fontPath = fullfile(fontsDir, files(1).name);
                end
            end

            if isempty(fontPath)
                return;
            end

            [loadedName, loadedOk] = tryRegisterFont(app, fontPath);
            if loadedOk && ~isempty(loadedName)
                fontName = loadedName;
            end
        end

        function [fontName, loadedOk] = tryRegisterFont(app, fontPath)
            %#ok<INUSD>
            fontName = '';
            loadedOk = false;
            fontList = {};
            try
                fontList = listfonts;
            catch
            end

            if exist('matlab.internal.fonts.addFont', 'file') == 2
                try
                    added = matlab.internal.fonts.addFont(fontPath);
                    if ~isempty(added)
                        fontName = char(added);
                    end
                catch
                end
            end

            if isempty(fontName) && exist('matlab.graphics.internal.fonts.addFont', 'file') == 2
                try
                    added = matlab.graphics.internal.fonts.addFont(fontPath);
                    if ~isempty(added)
                        fontName = char(added);
                    end
                catch
                end
            end

            if isempty(fontName)
                try
                    jFont = java.awt.Font.createFont(java.awt.Font.TRUETYPE_FONT, java.io.File(fontPath));
                    ge = java.awt.GraphicsEnvironment.getLocalGraphicsEnvironment();
                    ge.registerFont(jFont);
                    fontName = char(jFont.getFamily());
                catch
                end
            end

            try
                fontList = listfonts;
            catch
            end

            if ~isempty(fontName) && ~isempty(fontList)
                loadedOk = any(strcmpi(fontList, fontName));
                if ~loadedOk
                    matches = find(contains(lower(string(fontList)), lower(string(fontName))), 1);
                    if ~isempty(matches)
                        fontName = fontList{matches};
                        loadedOk = true;
                    end
                end
            end
        end

        function prefsPath = getPrefsFilePath(app)
            %#ok<INUSD>
            prefsPath = fullfile(tempdir, 'MicVisualizerPrefs.mat');
        end
        
        function updateDeviceButtonText(app)
            % Update the Select Input Device button to show current device name
            if isempty(app.SelectInputsButton) || ~isvalid(app.SelectInputsButton)
                return;
            end
            
            if ~isempty(app.SelectedAudioDeviceName)
                % Truncate long device names to fit button
                deviceName = app.SelectedAudioDeviceName;
                maxLen = 22;
                if length(deviceName) > maxLen
                    deviceName = [deviceName(1:maxLen-2) '...'];
                end
                app.SelectInputsButton.Text = deviceName;
                app.SelectInputsButton.Tooltip = sprintf('Current: %s\nClick to change', app.SelectedAudioDeviceName);
            else
                app.SelectInputsButton.Text = 'Select Input Device';
                app.SelectInputsButton.Tooltip = 'Click to select audio input device';
            end
        end

        function loadPreferences(app)
            prefsPath = app.getPrefsFilePath();
            if exist(prefsPath, 'file') ~= 2
                return;
            end
            try
                data = load(prefsPath, 'prefs');
                if ~isfield(data, 'prefs')
                    return;
                end
                prefs = data.prefs;
                app.IsApplyingPrefs = true;

                if isfield(prefs, 'SampleRate')
                    app.SampleRate = max(8000, min(192000, prefs.SampleRate));
                    app.SampleRateSpinner.Value = app.SampleRate;
                end
                if isfield(prefs, 'Gain')
                    app.GainSlider.Value = prefs.Gain;
                    updateGainLabel(app, prefs.Gain);
                end
                if isfield(prefs, 'YAxisRange')
                    yRange = max(app.YAxisRangeSlider.Limits(1), min(app.YAxisRangeSlider.Limits(2), prefs.YAxisRange));
                    app.YAxisRangeSlider.Value = yRange;
                    updateYAxisRangeLabel(app, yRange);
                end
                if isfield(prefs, 'WaveformDisplay')
                    app.WaveformDisplayCheckBox.Value = logical(prefs.WaveformDisplay);
                end
                if isfield(prefs, 'FFTDisplay')
                    app.FFTDisplayCheckBox.Value = logical(prefs.FFTDisplay);
                end
                updateDisplayOptionState(app, []);
                if isfield(prefs, 'ChannelColors') && ~isempty(prefs.ChannelColors)
                    app.ChannelColors = prefs.ChannelColors;
                end
                if isfield(prefs, 'SelectedDeviceIDs')
                    app.SelectedDeviceIDs = prefs.SelectedDeviceIDs(:);
                end
                if isfield(prefs, 'SelectedDeviceNames')
                    app.SelectedDeviceNames = prefs.SelectedDeviceNames;
                end
                if isfield(prefs, 'SelectedAudioDeviceName')
                    app.SelectedAudioDeviceName = char(prefs.SelectedAudioDeviceName);
                end
                if isfield(prefs, 'SelectedAudioDriver')
                    app.SelectedAudioDriver = char(prefs.SelectedAudioDriver);
                end
                if isfield(prefs, 'AudioDriver')
                    app.SelectedAudioDriver = char(prefs.AudioDriver);
                end
                if isfield(prefs, 'SelectedDataAcqVendor')
                    app.SelectedDataAcqVendor = char(prefs.SelectedDataAcqVendor);
                end
                if isfield(prefs, 'SelectedDataAcqDeviceId')
                    app.SelectedDataAcqDeviceId = char(prefs.SelectedDataAcqDeviceId);
                end
                if isfield(prefs, 'UseDarkMode')
                    app.UseDarkMode = logical(prefs.UseDarkMode);
                    if ~isempty(app.DarkModeSwitch) && isvalid(app.DarkModeSwitch)
                        if app.UseDarkMode
                            app.DarkModeSwitch.Value = 'Dark';
                        else
                            app.DarkModeSwitch.Value = 'Light';
                        end
                    end
                    applyTheme(app);
                end
            catch
                % Ignore prefs load errors
            end
            app.IsApplyingPrefs = false;
            
            % Update the device button text with loaded device name
            updateDeviceButtonText(app);
        end

        function savePreferences(app)
            prefsPath = app.getPrefsFilePath();
            try
                prefs.SampleRate = app.SampleRate;
                prefs.Gain = app.GainSlider.Value;
                prefs.YAxisRange = app.YAxisRangeSlider.Value;
                prefs.WaveformDisplay = app.WaveformDisplayCheckBox.Value;
                prefs.FFTDisplay = app.FFTDisplayCheckBox.Value;
                prefs.ChannelColors = app.ChannelColors;
                prefs.AudioDriver = app.SelectedAudioDriver;
                prefs.SelectedDeviceIDs = app.SelectedDeviceIDs;
                prefs.SelectedDeviceNames = app.SelectedDeviceNames;
                prefs.SelectedAudioDeviceName = app.SelectedAudioDeviceName;
                prefs.SelectedAudioDriver = app.SelectedAudioDriver;
                prefs.SelectedDataAcqVendor = app.SelectedDataAcqVendor;
                prefs.SelectedDataAcqDeviceId = app.SelectedDataAcqDeviceId;
                prefs.UseDarkMode = app.UseDarkMode;
                save(prefsPath, 'prefs');
            catch
                % Ignore prefs save errors
            end
        end

        function tf = deviceHasAudioSubsystem(app, device)
            %#ok<INUSD>
            tf = false;
            try
                subs = device.Subsystems;
                if ischar(subs) || isstring(subs)
                    tf = contains(lower(string(subs)), "audio");
                    return;
                end
                if isstruct(subs)
                    for i = 1:numel(subs)
                        if isfield(subs(i), 'SubsystemType')
                            if contains(lower(string(subs(i).SubsystemType)), "audio")
                                tf = true;
                                return;
                            end
                        elseif isfield(subs(i), 'Name')
                            if contains(lower(string(subs(i).Name)), "audio")
                                tf = true;
                                return;
                            end
                        end
                    end
                end
            catch
            end
        end

        function [vendorName, deviceId] = pickDataAcqAudioDevice(app)
            %#ok<INUSD>
            vendorName = '';
            deviceId = '';
            vendorsToTry = ["directsound", "wasapi"];
            operationalVendor = getOperationalDaqVendor(app);
            if ~isempty(operationalVendor)
                vendorsToTry = [string(operationalVendor), vendorsToTry];
            end

            % Prefer daqlist when available
            if exist('daqlist', 'file') == 2
                for v = vendorsToTry
                    try
                        t = daqlist(v);
                        if ~isempty(t)
                            vendorName = char(v);
                            deviceId = t.DeviceID(1);
                            return;
                        end
                    catch
                    end
                end
            end

            % Fallback to daq.getDevices
            try
                devices = daq.getDevices;
                for i = 1:numel(devices)
                    if any(strcmpi(devices(i).Vendor, vendorsToTry)) && deviceHasAudioSubsystem(app, devices(i))
                        vendorName = devices(i).Vendor;
                        deviceId = devices(i).ID;
                        return;
                    end
                end
            catch
            end
        end
        
        function initializeAudioRecorders(app)
            % Initialize audio recorders - use Audio Toolbox if available, otherwise legacy method
            try
                % Prefer Data Acquisition Toolbox if available (more robust on Windows)
                if checkDataAcqToolbox(app)
                    try
                        initializeDataAcq(app);
                        return;
                    catch
                        app.UseDataAcq = false;
                        % Continue to try Audio Toolbox / legacy
                    end
                end

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

        function initializeDataAcq(app)
            % Initialize using Data Acquisition Toolbox audio input
            try
                % Clean up existing DAQ session and listener
                if ~isempty(app.DataAcqListener)
                    try
                        delete(app.DataAcqListener);
                    catch
                    end
                end
                app.DataAcqListener = [];

                if ~isempty(app.DataAcqSession)
                    try
                        stop(app.DataAcqSession);
                    catch
                    end
                    try
                        delete(app.DataAcqSession);
                    catch
                    end
                end
                app.DataAcqSession = [];

                % Pick vendor and device (prefer saved selection)
                vendorName = app.SelectedDataAcqVendor;
                deviceId = app.SelectedDataAcqDeviceId;
                if ~isOperationalDaqVendor(app, vendorName)
                    vendorName = '';
                    deviceId = '';
                end
                if isempty(vendorName) || isempty(deviceId)
                    [vendorName, deviceId] = pickDataAcqAudioDevice(app);
                end
                if isempty(vendorName)
                    vendorName = getOperationalDaqVendor(app);
                end
                if isempty(vendorName)
                    error('No operational DAQ vendor found. Run daqvendorlist to verify installed vendors.');
                end

                dq = daq(vendorName);
                channelCount = max(1, min(app.NumChannels, 4));
                if ~isempty(deviceId)
                    try
                        addinput(dq, deviceId, 1:channelCount, "Audio");
                    catch
                        addinput(dq, deviceId, 1, "Audio");
                    end
                else
                    % Fall back to first available device for vendor
                    try
                        addinput(dq, "Audio1", 1:channelCount, "Audio");
                    catch
                        addinput(dq, "Audio1", 1, "Audio");
                    end
                end

                dq.Rate = app.SampleRate;
                dq.NotifyWhenDataAvailableExceeds = max(256, round(dq.Rate * 0.05));

                app.DataAcqSession = dq;
                app.UseDataAcq = true;
                app.SelectedDataAcqVendor = char(vendorName);
                if ~isempty(deviceId)
                    app.SelectedDataAcqDeviceId = char(deviceId);
                end

                % Initialize audio history buffers (~0.5 seconds)
                app.NumChannels = channelCount;
                app.AudioHistory = cell(channelCount, 1);
                for i = 1:channelCount
                    app.AudioHistory{i} = zeros(0, 1);
                end
                app.DataAcqNoDataCount = 0;

                % Attach listener to collect data continuously
                app.DataAcqListener = addlistener(dq, "DataAvailable", ...
                    @(~, evt) onDataAcqDataAvailable(app, evt));

                app.StatusLabel.Text = sprintf('Status: Ready at %d Hz (%d ch, DAQ)', app.SampleRate, app.NumChannels);
            catch ME
                app.UseDataAcq = false;
                app.StatusLabel.Text = sprintf('Status: Error - %s', ME.message);
                throw(ME);
            end
        end

        function startDataAcqIfNeeded(app)
            if ~app.UseDataAcq || isempty(app.DataAcqSession)
                return;
            end
            try
                start(app.DataAcqSession, "continuous");
            catch
                try
                    start(app.DataAcqSession);
                catch
                end
            end
        end

        function onDataAcqDataAvailable(app, evt)
            % Listener callback for DAQ audio data
            try
                if isempty(evt) || isempty(evt.Data)
                    return;
                end
                frameData = evt.Data;
                if ~isa(frameData, 'double')
                    frameData = double(frameData);
                end
                frameData = frameData * app.GainSlider.Value;

                maxHistorySamples = round(app.SampleRate * 0.5);
                numChannels = min(size(frameData, 2), 4);
                app.NumChannels = numChannels;
                
                % Store each channel in its own history buffer
                for chIdx = 1:numChannels
                    if length(app.AudioHistory) < chIdx
                        app.AudioHistory{chIdx} = zeros(0, 1);
                    end
                    app.AudioHistory{chIdx} = [app.AudioHistory{chIdx}; frameData(:, chIdx)];
                    if length(app.AudioHistory{chIdx}) > maxHistorySamples
                        app.AudioHistory{chIdx} = app.AudioHistory{chIdx}(end-maxHistorySamples+1:end);
                    end
                end
            catch
                % Ignore listener errors
            end
        end
        
        function initializeAudioToolboxReaders(app)
            % Initialize using Audio Toolbox audioDeviceReader
            % Auto-detects number of channels from device (up to 4 max)
            % For multi-channel interfaces, ASIO driver is preferred
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
                
                % Use the selected device and driver from preferences
                deviceToUse = '';
                driverToUse = '';
                
                % First priority: use SelectedAudioDeviceName and SelectedAudioDriver (from dialog)
                if ~isempty(app.SelectedAudioDeviceName)
                    deviceToUse = app.SelectedAudioDeviceName;
                end
                if ~isempty(app.SelectedAudioDriver)
                    driverToUse = app.SelectedAudioDriver;
                end
                
                % Fallback: try to get device name from audiodevinfo if not set
                if isempty(deviceToUse)
                    try
                        info = audiodevinfo;
                        inputDevices = info.input;
                        if ~isempty(inputDevices)
                            if ~isempty(app.SelectedDeviceIDs)
                                matchIdx = find([inputDevices.ID] == app.SelectedDeviceIDs(1), 1);
                                if ~isempty(matchIdx)
                                    deviceToUse = inputDevices(matchIdx).Name;
                                end
                            end
                            if isempty(deviceToUse)
                                deviceToUse = inputDevices(1).Name;
                            end
                        end
                    catch
                        % Will use default device
                    end
                end
                
                % Create audioDeviceReader - try to get max channels (up to 4)
                % Frame size: 1024 samples is standard for real-time processing
                samplesPerFrame = 1024;
                maxChannels = 4;
                
                reader = [];
                actualChannels = 1;
                usedDriver = '';
                
                % Drivers to try - ASIO first for multi-channel support, then others
                driversToTry = {'ASIO', 'DirectSound', 'WASAPI', ''};
                if ~isempty(driverToUse)
                    % If user selected a driver, try that first
                    driversToTry = [{driverToUse}, driversToTry];
                end
                
                % Try each driver with max channels first
                for dIdx = 1:length(driversToTry)
                    if ~isempty(reader)
                        break;
                    end
                    tryDriver = driversToTry{dIdx};
                    
                    % Try to create reader with up to 4 channels, fall back to fewer if needed
                    for tryChannels = maxChannels:-1:1
                        if ~isempty(reader)
                            break;
                        end
                        try
                            if ~isempty(deviceToUse) && ~isempty(tryDriver)
                                reader = audioDeviceReader(...
                                    'Driver', tryDriver, ...
                                    'Device', deviceToUse, ...
                                    'SampleRate', app.SampleRate, ...
                                    'SamplesPerFrame', samplesPerFrame, ...
                                    'NumChannels', tryChannels);
                            elseif ~isempty(tryDriver)
                                reader = audioDeviceReader(...
                                    'Driver', tryDriver, ...
                                    'SampleRate', app.SampleRate, ...
                                    'SamplesPerFrame', samplesPerFrame, ...
                                    'NumChannels', tryChannels);
                            elseif ~isempty(deviceToUse)
                                reader = audioDeviceReader(...
                                    'Device', deviceToUse, ...
                                    'SampleRate', app.SampleRate, ...
                                    'SamplesPerFrame', samplesPerFrame, ...
                                    'NumChannels', tryChannels);
                            else
                                reader = audioDeviceReader(...
                                    'SampleRate', app.SampleRate, ...
                                    'SamplesPerFrame', samplesPerFrame, ...
                                    'NumChannels', tryChannels);
                            end
                            actualChannels = tryChannels;
                            usedDriver = tryDriver;
                        catch
                            reader = [];
                        end
                    end
                end
                
                % Final fallback - default device with default channels
                if isempty(reader)
                    try
                        reader = audioDeviceReader(...
                            'SampleRate', app.SampleRate, ...
                            'SamplesPerFrame', samplesPerFrame);
                        actualChannels = 1;
                        usedDriver = 'default';
                    catch ME
                        throw(ME);
                    end
                end
                
                % Query actual channel count from reader if possible
                try
                    if isprop(reader, 'NumChannels')
                        actualChannels = reader.NumChannels;
                    end
                catch
                    % Keep the value we set
                end
                
                % Store selected driver for future use
                if ~isempty(usedDriver) && ~strcmp(usedDriver, 'default')
                    app.SelectedAudioDriver = usedDriver;
                end
                
                app.AudioDeviceReaders{1} = reader;
                app.NumChannels = actualChannels;
                
                % Ensure ChannelColors array is sized correctly
                initializeChannelColors(app, actualChannels);
                
                % Initialize audio history buffers (keep ~0.5 seconds for display)
                app.AudioHistory = cell(actualChannels, 1);
                for i = 1:actualChannels
                    app.AudioHistory{i} = zeros(0, 1);  % Initialize empty
                end
                
                % Show driver info in status
                if ~isempty(usedDriver) && ~strcmp(usedDriver, 'default')
                    app.StatusLabel.Text = sprintf('Status: Ready %d ch @ %d Hz (%s)', actualChannels, app.SampleRate, usedDriver);
                else
                    app.StatusLabel.Text = sprintf('Status: Ready %d ch @ %d Hz', actualChannels, app.SampleRate);
                end
                
            catch ME
                errorMsg = ME.message;
                app.StatusLabel.Text = sprintf('Status: Error - %s', ME.message);
                uialert(app.UIFigure, sprintf('Error initializing audio:\n\n%s', errorMsg), 'Audio Error', 'Icon', getDialogIcon(app, 'error'));
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
                
                % Update status with device info (legacy mode supports 1 channel)
                app.NumChannels = 1;
                app.StatusLabel.Text = sprintf('Status: Ready at %d Hz (legacy mode)', app.SampleRate);

                % Reset legacy tracking counters after init
                app.LegacyLastTotalSamples = 0;
                app.LegacyNoDataCount = 0;
                app.LegacyErrorShown = false;
                
            catch ME
                errorMsg = ME.message;
                % Provide helpful suggestions for common errors
                if contains(errorMsg, 'sample rate', 'IgnoreCase', true)
                    errorMsg = sprintf('%s\n\nTry changing the sample rate to 48000 Hz or 44100 Hz.', errorMsg);
                elseif contains(errorMsg, 'device', 'IgnoreCase', true)
                    errorMsg = sprintf('%s\n\nMake sure your microphone is connected and not being used by another application.', errorMsg);
                end
                app.StatusLabel.Text = sprintf('Status: Error - %s', ME.message);
                uialert(app.UIFigure, sprintf('Error initializing audio:\n\n%s', errorMsg), 'Audio Error', 'Icon', getDialogIcon(app, 'error'));
            end
        end

        function restarted = restartLegacyRecorder(app, reason)
            % Attempt to recover an unresponsive legacy recorder
            restarted = false;
            try
                if now < app.LegacyRestartCooldownUntil
                    return;
                end
                app.LegacyRestartCooldownUntil = now + app.LegacyRestartCooldownSeconds / 86400;
                app.StatusLabel.Text = sprintf('Status: Restarting audio device (%s)...', reason);

                % Stop and delete existing recorders
                if ~isempty(app.AudioRecorders)
                    for i = 1:length(app.AudioRecorders)
                        if isvalid(app.AudioRecorders{i})
                            try
                                stop(app.AudioRecorders{i});
                                delete(app.AudioRecorders{i});
                            catch
                            end
                        end
                    end
                end
                app.AudioRecorders = {};

                % Reinitialize and start recording
                initializeAudioRecordersLegacy(app);
                for i = 1:length(app.AudioRecorders)
                    if isvalid(app.AudioRecorders{i})
                        try
                            record(app.AudioRecorders{i});
                        catch
                        end
                    end
                end

                app.LegacyLastTotalSamples = 0;
                app.LegacyNoDataCount = 0;
                restarted = true;
            catch
                % Keep running; next timer tick can retry
            end
        end
        
        function startVisualization(app)
            if app.IsRunning
                return;
            end
            
            try
                % Initialize audio recorders (Audio Toolbox or legacy)
                initializeAudioRecorders(app);
                
                if app.UseDataAcq
                    % DAQ method - session already running
                    if isempty(app.DataAcqSession)
                        error('No DAQ audio session available');
                    end
                    startDataAcqIfNeeded(app);
                    app.StatusLabel.Text = sprintf('Status: Running at %d Hz (DAQ)', app.SampleRate);
                    app.DataAcqNoDataCount = 0;
                elseif app.UseAudioToolbox
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

                    % Reset legacy tracking counters
                    app.LegacyLastTotalSamples = 0;
                    app.LegacyNoDataCount = 0;
                    app.LegacyErrorShown = false;
                end
                
                % Update UI immediately
                app.StartButton.Enable = 'off';
                app.StopButton.Enable = 'on';
                app.PauseButton.Enable = 'on';
                app.PauseButton.BackgroundColor = [0.6 0.6 0.2];  % Yellow-ish when active
                app.PauseButton.Text = 'Pause';
                app.IsPaused = false;
                setControlsForRunning(app, true);
                drawnow; % Allow UI to update before starting timer
                
                % Create timer for real-time visualization
                % Following MathWorks pattern: read frames and display immediately
                warning('off', 'MATLAB:audiorecorder:timeout');
                warning('off', 'matlabshared:asyncio:timeout');
                
                % Timer period: update at ~60 FPS for smooth visualization
                % Using OpenGL hardware acceleration for performance
                timerPeriod = 0.0167;  % ~16.7ms = 60 FPS
                
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
                uialert(app.UIFigure, sprintf('Error starting visualization: %s', ME.message), 'Error', 'Icon', getDialogIcon(app, 'error'));
                app.IsRunning = false;
                setControlsForRunning(app, false);
            end
        end
        
        function stopVisualization(app)
            % Force stop - don't wait for anything
            app.IsRunning = false;
            
            % Update UI immediately
            try
                if isvalid(app.StartButton)
                    app.StartButton.Enable = 'on';
                end
                if isvalid(app.StopButton)
                    app.StopButton.Enable = 'off';
                end
                if ~isempty(app.PauseButton) && isvalid(app.PauseButton)
                    app.PauseButton.Enable = 'off';
                    app.PauseButton.BackgroundColor = [0.5 0.5 0.5];  % Gray when disabled
                    app.PauseButton.Text = 'Pause';
                end
                app.IsPaused = false;
                if isvalid(app.StatusLabel)
                    app.StatusLabel.Text = 'Status: Stopped';
                end
                setControlsForRunning(app, false);
                if isvalid(app.UIFigure)
                    drawnow; % Allow UI to update immediately
                end
            catch
            end
            
            % Clear axes and reset plot lines
            try
                if isvalid(app.MicAxes)
                    cla(app.MicAxes);
                    app.PlotLines = {};
                    app.MicAxes.Visible = 'on';
                end
            catch
            end

            % Skip cleanup on Stop to avoid UI hang; cleanup happens on close
        end


        function cleanupAudioResources(app)
            % Stop all recorders/readers (best-effort, non-blocking)
            if app.UseDataAcq && ~isempty(app.DataAcqSession)
                try
                    if ~isempty(app.DataAcqListener)
                        delete(app.DataAcqListener);
                    end
                    app.DataAcqListener = [];
                catch
                end
                try
                    stop(app.DataAcqSession);
                catch
                end
                try
                    delete(app.DataAcqSession);
                catch
                end
                app.DataAcqSession = [];
                app.AudioHistory = {};
            end

            if app.UseAudioToolbox && ~isempty(app.AudioDeviceReaders)
                for i = 1:length(app.AudioDeviceReaders)
                    if isvalid(app.AudioDeviceReaders{i})
                        try
                            release(app.AudioDeviceReaders{i});
                        catch
                        end
                    end
                end
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

            % Reset legacy tracking counters
            app.LegacyLastTotalSamples = 0;
            app.LegacyNoDataCount = 0;
            app.LegacyErrorShown = false;
        end
        
        function updateSmoothAxisLimits(app, ax, timeData, audioData, isCombined)
            % Smoothly update axis limits to prevent choppy scaling
            % audioData can be a vector or matrix (columns = channels)
            if isempty(audioData) || isempty(timeData)
                return;
            end
            
            % Use fixed Y-axis range for smoother updates
            yRange = 1;
            if ~isempty(app.YAxisRangeSlider) && isvalid(app.YAxisRangeSlider)
                yRange = app.YAxisRangeSlider.Value;
            end
            newYMin = -yRange;
            newYMax = yRange;
            
            % Set X limits (time axis)
            xMin = min(timeData);
            xMax = max(timeData);
            if xMax - xMin < 0.001
                xMax = xMin + 0.5; % Default to 0.5 seconds
            end
            
            % Smooth X limits
            currentXLim = ax.XLim;
            if isempty(currentXLim) || any(isnan(currentXLim)) || currentXLim(1) == currentXLim(2)
                newXMin = xMin;
                newXMax = xMax;
            else
                currentRange = currentXLim(2) - currentXLim(1);
                targetRange = xMax - xMin;
                if currentRange <= 0 || targetRange <= 0
                    newXMin = xMin;
                    newXMax = xMax;
                else
                    rangeRatio = currentRange / targetRange;
                    if rangeRatio > 5 || rangeRatio < 0.2
                        % Snap when switching between FFT and waveform ranges
                        newXMin = xMin;
                        newXMax = xMax;
                    else
                        newXMin = currentXLim(1) + (xMin - currentXLim(1)) * app.SmoothingFactor;
                        newXMax = currentXLim(2) + (xMax - currentXLim(2)) * app.SmoothingFactor;
                    end
                end
            end
            
            % Apply limits
            ax.YLim = [newYMin, newYMax];
            ax.XLim = [newXMin, newXMax];
        end
        
        function updateSmoothAxisLimitsFFT(app, ax, freqData, magnitudeData)
            % Smoothly update axis limits for FFT plots
            if isempty(freqData) || isempty(magnitudeData)
                return;
            end
            
            % Use fixed Y-axis range for smoother updates
            yRange = 1;
            if ~isempty(app.YAxisRangeSlider) && isvalid(app.YAxisRangeSlider)
                yRange = app.YAxisRangeSlider.Value;
            end
            yMin = 0;
            yMax = yRange;
            
            xMin = min(freqData);
            xMax = max(freqData);
            if xMax - xMin < 1
                xMax = xMin + 100; % Default to 100 Hz range
            end
            
            % No smoothing for fixed limits
            newYMin = yMin;
            newYMax = yMax;
            
            currentXLim = ax.XLim;
            if isempty(currentXLim) || any(isnan(currentXLim)) || currentXLim(1) == currentXLim(2)
                newXMin = xMin;
                newXMax = xMax;
            else
                currentRange = currentXLim(2) - currentXLim(1);
                targetRange = xMax - xMin;
                if currentRange <= 0 || targetRange <= 0
                    newXMin = xMin;
                    newXMax = xMax;
                else
                    rangeRatio = currentRange / targetRange;
                    if rangeRatio > 5 || rangeRatio < 0.2
                        % Snap when switching between waveform and FFT ranges
                        newXMin = xMin;
                        newXMax = xMax;
                    else
                        newXMin = currentXLim(1) + (xMin - currentXLim(1)) * app.SmoothingFactor;
                        newXMax = currentXLim(2) + (xMax - currentXLim(2)) * app.SmoothingFactor;
                    end
                end
            end
            
            % Apply limits
            ax.YLim = [newYMin, newYMax];
            ax.XLim = [newXMin, newXMax];
        end
        
        function updateVisualization(app)
            if ~app.IsRunning
                return;
            end
            
            % Skip rendering when paused (but keep collecting data)
            if app.IsPaused
                return;
            end

            % Suppress ALL warnings to prevent timeout error spam
            warning('off', 'all');
            
            try
                colors = getThemeColors(app);
                % Get audio data from recorders
                audioData = [];
                timeData = [];
                
                if app.UseDataAcq
                    % DAQ method - use rolling history populated by listener
                    if ~isempty(app.AudioHistory) && ~isempty(app.AudioHistory{1})
                        app.DataAcqNoDataCount = 0;
                        numCh = min(length(app.AudioHistory), app.NumChannels);
                        if numCh == 1
                            audioData = app.AudioHistory{1}(:);
                        else
                            minLen = length(app.AudioHistory{1});
                            for chIdx = 2:numCh
                                if length(app.AudioHistory{chIdx}) < minLen
                                    minLen = length(app.AudioHistory{chIdx});
                                end
                            end
                            audioData = zeros(minLen, numCh);
                            for chIdx = 1:numCh
                                audioData(:, chIdx) = app.AudioHistory{chIdx}(1:minLen);
                            end
                        end
                        timeData = (0:size(audioData, 1)-1) / app.SampleRate;
                    else
                        app.DataAcqNoDataCount = app.DataAcqNoDataCount + 1;
                        if app.DataAcqNoDataCount >= app.DataAcqMaxNoDataFrames
                            app.StatusLabel.Text = 'Status: No audio data (DAQ). Check device/permissions.';
                        end
                    end
                elseif app.UseAudioToolbox
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
                                numChannels = min(size(frameData, 2), 4);
                                app.NumChannels = numChannels;
                                
                                % Store each channel in its own history buffer
                                for chIdx = 1:numChannels
                                    if length(app.AudioHistory) < chIdx
                                        app.AudioHistory{chIdx} = zeros(0, 1);
                                    end
                                    app.AudioHistory{chIdx} = [app.AudioHistory{chIdx}; frameData(:, chIdx)];
                                    if length(app.AudioHistory{chIdx}) > maxHistorySamples
                                        app.AudioHistory{chIdx} = app.AudioHistory{chIdx}(end-maxHistorySamples+1:end);
                                    end
                                end
                                
                                % Extract accumulated data for display
                                if ~isempty(app.AudioHistory{1})
                                    if numChannels == 1
                                        audioData = app.AudioHistory{1}(:);
                                    else
                                        % Combine all channel histories
                                        minLen = length(app.AudioHistory{1});
                                        for chIdx = 2:numChannels
                                            if length(app.AudioHistory{chIdx}) < minLen
                                                minLen = length(app.AudioHistory{chIdx});
                                            end
                                        end
                                        audioData = zeros(minLen, numChannels);
                                        for chIdx = 1:numChannels
                                            audioData(:, chIdx) = app.AudioHistory{chIdx}(1:minLen);
                                        end
                                    end
                                    % Create time vector
                                    timeData = (0:size(audioData, 1)-1) / app.SampleRate;
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
                    anyDataThisTick = false;
                    for i = 1:length(app.AudioRecorders)
                        if isvalid(app.AudioRecorders{i})
                            try
                                % Check if recorder is actually recording (may timeout, so catch it)
                                try
                                    isRec = isrecording(app.AudioRecorders{i});
                                catch
                                    isRec = false;
                                end
                                
                                % Don't skip on isrecording false; some drivers misreport
                                
                                % Get current audio data - completely suppress errors
                                try
                                    totalSamples = get(app.AudioRecorders{i}, 'TotalSamples');
                                catch
                                    totalSamples = 0;
                                end
                                
                                if totalSamples < 1  % Accept any data, even just 1 sample
                                    continue;
                                end

                                if totalSamples <= app.LegacyLastTotalSamples
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
                                    if ~app.LegacyErrorShown
                                        app.StatusLabel.Text = 'Status: Audio device unresponsive. Check permissions/exclusive use.';
                                        app.LegacyErrorShown = true;
                                    end
                                end
                                
                                if ~isempty(data) && length(data) > 0
                                    anyDataThisTick = true;
                                    app.LegacyLastTotalSamples = totalSamples;
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

                    if anyDataThisTick
                        app.LegacyNoDataCount = 0;
                    else
                        app.LegacyNoDataCount = app.LegacyNoDataCount + 1;
                        if app.LegacyNoDataCount >= app.LegacyMaxNoDataFrames
                            app.StatusLabel.Text = 'Status: No audio data. Check mic permissions/exclusive mode.';
                        end
                        if app.LegacyNoDataCount >= app.LegacyMaxNoDataFrames
                            if restartLegacyRecorder(app, 'no data received')
                                return;
                            end
                        end
                    end
                    
                    % Legacy recorder only supports 1 channel
                    app.NumChannels = 1;
                end
                
                if isempty(audioData)
                    % No data in this frame - skip update (will try again next timer tick)
                    return;
                end
                
                % Update status with channel count
                numCh = size(audioData, 2);
                if app.UseDataAcq
                    app.StatusLabel.Text = sprintf('Status: Running %d ch @ %d Hz (DAQ)', numCh, app.SampleRate);
                elseif app.UseAudioToolbox
                    app.StatusLabel.Text = sprintf('Status: Running %d ch @ %d Hz', numCh, app.SampleRate);
                else
                    app.StatusLabel.Text = sprintf('Status: Running %d channel(s)', numCh);
                end
                
                showWaveform = app.WaveformDisplayCheckBox.Value;
                showFFT = app.FFTDisplayCheckBox.Value;
                numChannels = size(audioData, 2);
                
                % Ensure channel colors are initialized
                if isempty(app.ChannelColors) || size(app.ChannelColors, 1) < numChannels
                    initializeChannelColors(app, numChannels);
                end
                
                % If neither is selected, clear plots and skip rendering
                if ~showWaveform && ~showFFT
                    cla(app.MicAxes);
                    applyAxesTheme(app, app.MicAxes);
                    app.MicAxes.Title.String = 'No display mode selected';
                    app.MicAxes.XLabel.String = '';
                    app.MicAxes.YLabel.String = '';
                    app.PlotLines = {};
                    return;
                end

                waveformAuto = audioData - mean(audioData, 1);
                app.LastWaveformData = waveformAuto;
                if showWaveform
                    waveformData = waveformAuto;
                else
                    waveformData = audioData;
                end
                
                % Ensure main axes are visible
                app.MicAxes.Visible = 'on';
                
                % OPTIMIZED RENDERING: Use line handle updates instead of cla/plot
                % This dramatically improves performance for 60fps
                needsFullRedraw = isempty(app.PlotLines) || length(app.PlotLines) ~= numChannels;
                
                if showWaveform && ~showFFT
                    % Waveform display - all channels on one graph
                    if needsFullRedraw
                        cla(app.MicAxes);
                        applyAxesTheme(app, app.MicAxes);
                        hold(app.MicAxes, 'on');
                        app.PlotLines = cell(numChannels, 1);
                        for chIdx = 1:numChannels
                            lineColor = app.ChannelColors(chIdx, :);
                            % Smooth lines with thicker width and anti-aliased rendering
                            app.PlotLines{chIdx} = plot(app.MicAxes, timeData, waveformData(:, chIdx), ...
                                'Color', [lineColor 0.85], 'LineWidth', 2.0, ...
                                'LineStyle', '-', ...
                                'DisplayName', sprintf('Ch %d', chIdx));
                        end
                        hold(app.MicAxes, 'off');
                        legend(app.MicAxes, 'show', 'Location', 'best');
                        applyLegendTheme(app, app.MicAxes, colors);
                    else
                        % Fast update: just update XData/YData
                        for chIdx = 1:numChannels
                            if chIdx <= length(app.PlotLines) && isvalid(app.PlotLines{chIdx})
                                set(app.PlotLines{chIdx}, 'XData', timeData, 'YData', waveformData(:, chIdx));
                                % Update color in case it changed
                                set(app.PlotLines{chIdx}, 'Color', app.ChannelColors(chIdx, :));
                            end
                        end
                    end
                    app.MicAxes.YLabel.String = 'Amplitude';
                    app.MicAxes.XLabel.String = 'Time (s)';
                    app.MicAxes.Title.String = sprintf('Audio Waveform (%d Channel(s))', numChannels);
                    
                    % Apply smooth axis scaling
                    updateSmoothAxisLimits(app, app.MicAxes, timeData, waveformData, false);
                    
                elseif showFFT && ~showWaveform
                    % FFT display - show each channel's spectrum
                    N = size(audioData, 1);
                    f = [];
                    if N > 0
                        f = app.SampleRate*(0:(N/2))/N;
                        maxFreq = min(8000, app.SampleRate/2);
                        freqIdx = f <= maxFreq;
                        fDisplay = f(freqIdx);
                        
                        if needsFullRedraw || length(app.PlotLines) ~= numChannels
                            cla(app.MicAxes);
                            applyAxesTheme(app, app.MicAxes);
                            hold(app.MicAxes, 'on');
                            app.PlotLines = cell(numChannels, 1);
                            for chIdx = 1:numChannels
                                fftData = audioData(:, chIdx);
                                windowed = fftData .* hann(N);
                                Y = fft(windowed);
                                P2 = abs(Y/N);
                                P1 = P2(1:N/2+1);
                                P1(2:end-1) = 2*P1(2:end-1);
                                lineColor = app.ChannelColors(chIdx, :);
                                % Smooth lines with thicker width and anti-aliased rendering
                                app.PlotLines{chIdx} = plot(app.MicAxes, fDisplay, P1(freqIdx), ...
                                    'Color', [lineColor 0.85], 'LineWidth', 2.0, ...
                                    'LineStyle', '-', ...
                                    'DisplayName', sprintf('Ch %d', chIdx));
                            end
                            hold(app.MicAxes, 'off');
                            legend(app.MicAxes, 'show', 'Location', 'best');
                            applyLegendTheme(app, app.MicAxes, colors);
                        else
                            % Fast update
                            for chIdx = 1:numChannels
                                if chIdx <= length(app.PlotLines) && isvalid(app.PlotLines{chIdx})
                                    fftData = audioData(:, chIdx);
                                    windowed = fftData .* hann(N);
                                    Y = fft(windowed);
                                    P2 = abs(Y/N);
                                    P1 = P2(1:N/2+1);
                                    P1(2:end-1) = 2*P1(2:end-1);
                                    set(app.PlotLines{chIdx}, 'XData', fDisplay, 'YData', P1(freqIdx));
                                    set(app.PlotLines{chIdx}, 'Color', app.ChannelColors(chIdx, :));
                                end
                            end
                        end
                        
                        % Store last FFT for auto-range
                        fftData = mean(audioData, 2);
                        windowed = fftData .* hann(N);
                        Y = fft(windowed);
                        P2 = abs(Y/N);
                        P1 = P2(1:N/2+1);
                        P1(2:end-1) = 2*P1(2:end-1);
                        app.LastFftMagnitude = P1(freqIdx);
                        applyInitialFftRange(app, P1(freqIdx));
                        
                        updateSmoothAxisLimitsFFT(app, app.MicAxes, fDisplay, P1(freqIdx));
                    end
                    
                    app.MicAxes.YLabel.String = 'Magnitude';
                    app.MicAxes.XLabel.String = 'Frequency (Hz)';
                    app.MicAxes.Title.String = sprintf('Frequency Spectrum (%d Channel(s))', numChannels);
                end
                
                app.MicAxes.XGrid = 'on';
                app.MicAxes.YGrid = 'on';
                
                % Force update using limitrate for 60fps performance
                try
                    drawnow limitrate;
                catch
                    try
                        drawnow;
                    catch
                    end
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

            % Load saved preferences
            app.PrefsFilePath = app.getPrefsFilePath();
            loadPreferences(app);

            % If FFT is enabled on startup (without waveform), set a one-time auto y-range
            app.ApplyInitialFftRange = app.FFTDisplayCheckBox.Value && ~app.WaveformDisplayCheckBox.Value;
            
            % Don't initialize audio on startup - wait until user clicks Start
            % This prevents hanging if device is busy
            app.StatusLabel.Text = 'Status: Ready - Click Start to begin';
        end
        
        % Code that executes before app deletion
        function delete(app)
            % Stop visualization
            stopVisualization(app);

            % Save preferences on exit
            savePreferences(app);

            % Clear app variable from base workspace if present
            try
                evalin('base', 'if exist(''app'', ''var''), clear app; end');
            catch
            end
            
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
        
        function SampleRateSpinnerValueChanged(app, event)
            newSampleRate = app.SampleRateSpinner.Value;
            if app.IsApplyingPrefs
                app.SampleRate = newSampleRate;
                return;
            end
            if app.IsRunning
                app.IsApplyingPrefs = true;
                app.SampleRateSpinner.Value = app.SampleRate;
                app.IsApplyingPrefs = false;
                app.StatusLabel.Text = 'Status: Change will take effect after restart';
                return;
            end
            app.SampleRate = newSampleRate;
            initializeAudioRecorders(app);
            savePreferences(app);
        end

        function GainSliderValueChanged(app, event)
            %#ok<INUSD>
            if app.IsApplyingPrefs
                return;
            end
            updateGainLabel(app, app.GainSlider.Value);
            savePreferences(app);
        end

        function GainSliderValueChanging(app, event)
            if isempty(event) || ~isprop(event, 'Value')
                return;
            end
            updateGainLabel(app, event.Value);
        end

        function updateGainLabel(app, value)
            if nargin < 2 || isempty(value)
                value = app.GainSlider.Value;
            end
            if isempty(app.GainValueLabel) || ~isvalid(app.GainValueLabel)
                return;
            end
            app.GainValueLabel.Text = sprintf('%.2f', value);
        end

        function applyInitialFftRange(app, magnitudeData)
            if ~app.ApplyInitialFftRange
                return;
            end
            if isempty(magnitudeData)
                return;
            end
            magnitudeData = magnitudeData(isfinite(magnitudeData));
            if isempty(magnitudeData)
                return;
            end
            maxMag = max(magnitudeData);
            if isempty(maxMag) || maxMag <= 0
                return;
            end
            if isempty(app.YAxisRangeSlider) || ~isvalid(app.YAxisRangeSlider)
                return;
            end
            limits = app.YAxisRangeSlider.Limits;
            yRange = maxMag * 1.5;
            yRange = max(limits(1), min(limits(2), yRange));
            app.IsApplyingPrefs = true;
            app.YAxisRangeSlider.Value = yRange;
            updateYAxisRangeLabel(app, yRange);
            app.IsApplyingPrefs = false;
            app.ApplyInitialFftRange = false;
        end

        function yRange = applyAutoRangeFromData(app, data, multiplier)
            yRange = [];
            if nargin < 3 || isempty(multiplier)
                multiplier = 1.25;
            end
            if isempty(data)
                return;
            end
            data = data(isfinite(data));
            if isempty(data)
                return;
            end
            maxVal = max(abs(data(:)));
            if isempty(maxVal) || maxVal <= 0
                return;
            end
            if isempty(app.YAxisRangeSlider) || ~isvalid(app.YAxisRangeSlider)
                return;
            end
            limits = app.YAxisRangeSlider.Limits;
            yRange = maxVal * multiplier;
            yRange = max(limits(1), min(limits(2), yRange));
            app.IsApplyingPrefs = true;
            app.YAxisRangeSlider.Value = yRange;
            updateYAxisRangeLabel(app, yRange);
            app.IsApplyingPrefs = false;
            savePreferences(app);
        end

        function [yRange, gainFactor] = applyAutoRangeFftWithGain(app)
            yRange = [];
            gainFactor = 1;
            if isempty(app.LastFftMagnitude)
                return;
            end
            maxMag = max(abs(app.LastFftMagnitude(:)));
            if isempty(maxMag) || ~isfinite(maxMag) || maxMag <= 0
                return;
            end
            if isempty(app.YAxisRangeSlider) || ~isvalid(app.YAxisRangeSlider)
                return;
            end
            if isempty(app.GainSlider) || ~isvalid(app.GainSlider)
                return;
            end

            minRange = app.YAxisRangeSlider.Limits(1);
            targetPeak = minRange * 0.8;
            if maxMag < targetPeak
                desiredGainFactor = targetPeak / maxMag;
                currentGain = app.GainSlider.Value;
                gainLimits = app.GainSlider.Limits;
                newGain = currentGain * desiredGainFactor;
                newGain = max(gainLimits(1), min(gainLimits(2), newGain));
                gainFactor = newGain / currentGain;
                if abs(newGain - currentGain) > 1e-3
                    app.IsApplyingPrefs = true;
                    app.GainSlider.Value = newGain;
                    updateGainLabel(app, newGain);
                    app.IsApplyingPrefs = false;
                    savePreferences(app);
                end
            end

            yRange = applyAutoRangeFromData(app, app.LastFftMagnitude * gainFactor, 1.2);
        end

        function updateYAxisRangeLabel(app, value)
            if nargin < 2 || isempty(value)
                value = app.YAxisRangeSlider.Value;
            end
            if isempty(app.YAxisRangeValueLabel) || ~isvalid(app.YAxisRangeValueLabel)
                return;
            end
            app.YAxisRangeValueLabel.Text = sprintf('%.2f', value);
        end

        function applyFixedYAxisLimits(app, yRange)
            if nargin < 2 || isempty(yRange)
                yRange = app.YAxisRangeSlider.Value;
            end
            if isempty(app.MicAxes) || ~isvalid(app.MicAxes)
                return;
            end
            app.MicAxes.YLim = [-yRange, yRange];
        end

        function applyFftYAxisLimits(app, yRange)
            if nargin < 2 || isempty(yRange)
                yRange = app.YAxisRangeSlider.Value;
            end
            if isempty(app.MicAxes) || ~isvalid(app.MicAxes)
                return;
            end
            app.MicAxes.YLim = [0, yRange];
        end

        function setControlsForRunning(app, isRunning)
            if isempty(app.UIFigure) || ~isvalid(app.UIFigure)
                return;
            end
            state = 'on';
            if isRunning
                state = 'off';
            end
            if ~isempty(app.SampleRateSpinner) && isvalid(app.SampleRateSpinner)
                app.SampleRateSpinner.Enable = state;
            end
            if ~isempty(app.SelectInputsButton) && isvalid(app.SelectInputsButton)
                app.SelectInputsButton.Enable = state;
            end
            % LineColorsButton stays enabled always - colors can be changed anytime
        end

        function YAxisRangeSliderValueChanged(app, event)
            %#ok<INUSD>
            if app.IsApplyingPrefs
                return;
            end
            yRange = app.YAxisRangeSlider.Value;
            updateYAxisRangeLabel(app, yRange);
            applyFixedYAxisLimits(app, yRange);
            savePreferences(app);
        end

        function YAxisRangeSliderValueChanging(app, event)
            if isempty(event) || ~isprop(event, 'Value')
                return;
            end
            updateYAxisRangeLabel(app, event.Value);
        end

        function AutoRangeButtonPushed(app, event)
            %#ok<INUSD>
            showWaveform = app.WaveformDisplayCheckBox.Value;
            showFFT = app.FFTDisplayCheckBox.Value;
            if showFFT && ~showWaveform
                [yRange, ~] = applyAutoRangeFftWithGain(app);
                if ~isempty(yRange)
                    applyFftYAxisLimits(app, yRange);
                end
            else
                yRange = applyAutoRangeFromData(app, app.LastWaveformData, 1.2);
                if ~isempty(yRange)
                    applyFixedYAxisLimits(app, yRange);
                end
            end
        end

        function DisplayOptionValueChanged(app, event)
            %#ok<INUSD>
            if app.IsApplyingPrefs
                return;
            end
            if ~isempty(event) && isprop(event, 'Source')
                updateDisplayOptionState(app, event.Source);
            else
                updateDisplayOptionState(app, []);
            end
            savePreferences(app);
        end

        function DarkModeSwitchValueChanged(app, event)
            %#ok<INUSD>
            if app.IsApplyingPrefs
                return;
            end
            app.UseDarkMode = strcmpi(app.DarkModeSwitch.Value, 'Dark');
            applyTheme(app);
            savePreferences(app);
        end
        
        % Button pushed function: SelectInputsButton
        function SelectInputsButtonPushed(app, event)
            % Allow UI to update before showing dialog
            drawnow;
            showInputDeviceDialog(app);
        end
        
        % Button pushed function: LineColorsButton
        function LineColorsButtonPushed(app, event)
            %#ok<INUSD>
            % Toggle visibility of color picker panel
            if strcmp(app.ColorPickerPanel.Visible, 'off')
                % Show the color picker
                initializeChannelColors(app, max(1, app.NumChannels));
                updateChannelDropdownItems(app);
                app.ColorPickerPanel.Visible = 'on';
                app.LineColorsButton.Text = 'Hide Colors';
            else
                % Hide the color picker
                app.ColorPickerPanel.Visible = 'off';
                app.LineColorsButton.Text = 'Line Colors';
            end
        end
        
        % Dropdown value changed: ChannelDropdown
        function ChannelDropdownValueChanged(app, event)
            %#ok<INUSD>
            channelStr = app.ChannelDropdown.Value;
            channelIdx = str2double(regexp(channelStr, '\d+', 'match', 'once'));
            if ~isnan(channelIdx) && channelIdx >= 1
                updateColorPickerForChannel(app, channelIdx);
            end
        end
        
        % Color slider changing (real-time preview)
        function ColorSliderChanging(app, event)
            %#ok<INUSD>
            updateColorPreview(app);
            applyCurrentColor(app);
        end
        
        % Color slider changed (final value)
        function ColorSliderChanged(app, event)
            %#ok<INUSD>
            updateColorPreview(app);
            applyCurrentColor(app);
        end

        % Button pushed function: FullscreenButton
        function FullscreenButtonPushed(app, event)
            %#ok<INUSD>
            if isempty(app.UIFigure) || ~isvalid(app.UIFigure)
                return;
            end
            if isprop(app.UIFigure, 'WindowState') && strcmpi(app.UIFigure.WindowState, 'fullscreen')
                app.UIFigure.WindowState = 'normal';
                app.FullscreenButton.Text = 'Fullscreen';
                return;
            end
            try
                app.UIFigure.WindowState = 'fullscreen';
                app.FullscreenButton.Text = 'Exit Fullscreen';
            catch
                try
                    app.UIFigure.WindowState = 'maximized';
                    app.FullscreenButton.Text = 'Exit Fullscreen';
                catch
                    app.UIFigure.WindowState = 'normal';
                    app.FullscreenButton.Text = 'Fullscreen';
                end
            end
        end
        
        function showInputDeviceDialog(app)
            % Create dialog figure for device selection
            % Simple layout: Driver dropdown, Device dropdown, OK/Cancel
            colors = getThemeColors(app);
            hasAudioToolbox = checkAudioToolbox(app);
            
            dialogHeight = 250;
            dialogFig = uifigure('Visible', 'off');
            dialogFig.Position = [400 300 480 dialogHeight];
            dialogFig.Name = 'Select Audio Input Device';
            dialogFig.Color = colors.Window;
            dialogFig.Resize = 'off';
            applyDialogIcon(app, dialogFig);
            
            % Main panel
            mainPanel = uipanel(dialogFig);
            mainPanel.BackgroundColor = colors.PanelAlt;
            mainPanel.Position = [10 10 460 dialogHeight-20];
            mainPanel.BorderType = 'line';
            if isprop(mainPanel, 'BorderColor')
                mainPanel.BorderColor = colors.Border;
            end
            
            % Title
            titleLabel = uilabel(mainPanel);
            titleLabel.Text = 'Audio Input Configuration';
            titleLabel.FontName = app.AppFontName;
            titleLabel.FontSize = 16;
            titleLabel.FontWeight = 'bold';
            titleLabel.FontColor = colors.Text;
            titleLabel.Position = [20 dialogHeight-55 420 30];
            titleLabel.HorizontalAlignment = 'center';

            % Note about ASIO
            noteLabel = uilabel(mainPanel);
            noteLabel.Text = 'Select ASIO driver for multi-channel USB interfaces (UMC404HD, etc.)';
            noteLabel.FontName = app.AppFontName;
            noteLabel.FontSize = 10;
            noteLabel.FontColor = colors.TextMuted;
            noteLabel.Position = [20 dialogHeight-80 420 18];
            noteLabel.HorizontalAlignment = 'center';

            % Driver selection row
            driverLabel = uilabel(mainPanel);
            driverLabel.Text = 'Audio Driver:';
            driverLabel.FontName = app.AppFontName;
            driverLabel.FontSize = 12;
            driverLabel.FontColor = colors.Text;
            driverLabel.Position = [20 dialogHeight-115 100 22];
            driverLabel.HorizontalAlignment = 'left';

            driverDropdown = uidropdown(mainPanel);
            driverDropdown.Items = {'ASIO (Multi-channel)', 'DirectSound', 'WASAPI', 'Auto-detect'};
            driverDropdown.ItemsData = {'ASIO', 'DirectSound', 'WASAPI', ''};
            driverDropdown.FontName = app.AppFontName;
            driverDropdown.FontSize = 11;
            driverDropdown.Position = [130 dialogHeight-115 180 22];
            if ~isempty(app.SelectedAudioDriver)
                try
                    driverDropdown.Value = app.SelectedAudioDriver;
                catch
                    driverDropdown.Value = '';
                end
            else
                driverDropdown.Value = '';
            end

            % Refresh button
            refreshBtn = uibutton(mainPanel, 'push');
            refreshBtn.Text = 'Refresh';
            refreshBtn.FontName = app.AppFontName;
            refreshBtn.FontSize = 10;
            refreshBtn.FontWeight = 'bold';
            refreshBtn.BackgroundColor = colors.ButtonSecondary;
            refreshBtn.FontColor = colors.ButtonSecondaryText;
            refreshBtn.Position = [320 dialogHeight-115 100 22];

            % Device selection row
            deviceLabel = uilabel(mainPanel);
            deviceLabel.Text = 'Input Device:';
            deviceLabel.FontName = app.AppFontName;
            deviceLabel.FontSize = 12;
            deviceLabel.FontColor = colors.Text;
            deviceLabel.Position = [20 dialogHeight-150 100 22];
            deviceLabel.HorizontalAlignment = 'left';

            deviceDropdown = uidropdown(mainPanel);
            deviceDropdown.Items = {'Loading...'};
            deviceDropdown.FontName = app.AppFontName;
            deviceDropdown.FontSize = 11;
            deviceDropdown.Position = [130 dialogHeight-150 290 22];

            % Status label
            statusLabel = uilabel(mainPanel);
            statusLabel.Text = 'Detecting devices...';
            statusLabel.FontName = app.AppFontName;
            statusLabel.FontSize = 10;
            statusLabel.FontColor = colors.TextMuted;
            statusLabel.Position = [20 dialogHeight-175 420 18];
            statusLabel.HorizontalAlignment = 'left';

            % Function to refresh device list based on selected driver
            function refreshDevices()
                selectedDriver = driverDropdown.Value;
                deviceNames = {};
                
                statusLabel.Text = 'Scanning for devices...';
                drawnow;
                
                if hasAudioToolbox
                    % Try the selected driver first
                    driversToTry = {};
                    if ~isempty(selectedDriver)
                        driversToTry = {selectedDriver};
                    else
                        driversToTry = {'ASIO', 'DirectSound', 'WASAPI'};
                    end
                    
                    for dIdx = 1:length(driversToTry)
                        tryDriver = driversToTry{dIdx};
                        try
                            r = audioDeviceReader('Driver', tryDriver);
                            devs = getAudioDevices(r);
                            release(r);
                            if ~isempty(devs)
                                for k = 1:numel(devs)
                                    deviceNames{end+1} = sprintf('%s (%s)', devs{k}, tryDriver);
                                end
                            end
                        catch
                        end
                    end
                end
                
                % Fallback to legacy audiodevinfo if no devices found
                if isempty(deviceNames)
                    try
                        info = audiodevinfo;
                        if ~isempty(info.input)
                            for k = 1:length(info.input)
                                deviceNames{end+1} = info.input(k).Name;
                            end
                        end
                    catch
                    end
                end
                
                if isempty(deviceNames)
                    deviceDropdown.Items = {'No devices found'};
                    statusLabel.Text = 'No audio input devices detected. Check connections.';
                else
                    deviceDropdown.Items = deviceNames;
                    % Try to select previously used device
                    if ~isempty(app.SelectedAudioDeviceName)
                        matchIdx = find(contains(deviceNames, app.SelectedAudioDeviceName), 1);
                        if ~isempty(matchIdx)
                            deviceDropdown.Value = deviceNames{matchIdx};
                        else
                            deviceDropdown.Value = deviceNames{1};
                        end
                    else
                        deviceDropdown.Value = deviceNames{1};
                    end
                    statusLabel.Text = sprintf('%d device(s) found', length(deviceNames));
                end
            end
            
            % Set callbacks
            refreshBtn.ButtonPushedFcn = @(~,~) refreshDevices();
            driverDropdown.ValueChangedFcn = @(~,~) refreshDevices();
            
            % Initial device scan
            refreshDevices();

            % OK Button
            okBtn = uibutton(mainPanel, 'push');
            okBtn.Text = 'OK';
            okBtn.FontName = app.AppFontName;
            okBtn.FontSize = 12;
            okBtn.FontWeight = 'bold';
            okBtn.BackgroundColor = colors.Success;
            okBtn.FontColor = [1 1 1];
            okBtn.Position = [130 20 100 35];
            okBtn.ButtonPushedFcn = @(~,~) applyDeviceSelection();
            
            % Cancel Button
            cancelBtn = uibutton(mainPanel, 'push');
            cancelBtn.Text = 'Cancel';
            cancelBtn.FontName = app.AppFontName;
            cancelBtn.FontSize = 12;
            cancelBtn.FontWeight = 'bold';
            cancelBtn.BackgroundColor = colors.Danger;
            cancelBtn.FontColor = [1 1 1];
            cancelBtn.Position = [250 20 100 35];
            cancelBtn.ButtonPushedFcn = @(~,~) delete(dialogFig);
            
            function applyDeviceSelection()
                % Save the selected driver and device
                app.SelectedAudioDriver = driverDropdown.Value;
                selectedDevice = deviceDropdown.Value;
                
                % Extract device name (remove driver suffix)
                if contains(selectedDevice, ' (ASIO)')
                    app.SelectedAudioDeviceName = strrep(selectedDevice, ' (ASIO)', '');
                    app.SelectedAudioDriver = 'ASIO';
                elseif contains(selectedDevice, ' (DirectSound)')
                    app.SelectedAudioDeviceName = strrep(selectedDevice, ' (DirectSound)', '');
                    app.SelectedAudioDriver = 'DirectSound';
                elseif contains(selectedDevice, ' (WASAPI)')
                    app.SelectedAudioDeviceName = strrep(selectedDevice, ' (WASAPI)', '');
                    app.SelectedAudioDriver = 'WASAPI';
                else
                    app.SelectedAudioDeviceName = selectedDevice;
                end
                
                % Stop if running
                if app.IsRunning
                    stopVisualization(app);
                end
                
                % Reinitialize with new settings
                initializeAudioRecorders(app);
                updateDeviceButtonText(app);
                savePreferences(app);

                if ~app.IsRunning
                    app.StatusLabel.Text = sprintf('Status: Device configured (%d ch)', app.NumChannels);
                end
                
                delete(dialogFig);
            end
            
            dialogFig.Visible = 'on';
        end
        
        function closeDialogWithDriver(app, dialogFig, driverDropdown)
            % Save the selected driver
            app.SelectedAudioDriver = driverDropdown.Value;
            closeDialog(app, dialogFig);
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
                            % Stop visualization if running when device changes
                            if app.IsRunning
                                stopVisualization(app);
                                app.StatusLabel.Text = 'Status: Stopped - Device selection changed. Click Start to begin.';
                            end
                            app.SelectedDeviceIDs(micIndex) = deviceID;
                        end
                    end
                end
            end
        end

        function updateDeviceNameFromDropdown(app, micIndex, dropdown, deviceNames, deviceDrivers)
            % Update Audio Toolbox device name selection
            selectedName = dropdown.Value;
            if app.IsRunning
                stopVisualization(app);
                app.StatusLabel.Text = 'Status: Stopped - Device selection changed. Click Start to begin.';
            end
            if isempty(app.SelectedDeviceNames) || length(app.SelectedDeviceNames) < micIndex
                app.SelectedDeviceNames = cell(max(micIndex, app.NumMics), 1);
            end
            app.SelectedDeviceNames{micIndex} = selectedName;
            idx = find(strcmp(deviceNames, selectedName), 1);
            if ~isempty(idx) && length(deviceDrivers) >= idx
                app.SelectedAudioDeviceName = selectedName;
                app.SelectedAudioDriver = deviceDrivers{idx};
            end
        end

        function updateDataAcqSelectionFromDropdown(app, dropdown, deviceNames, deviceIDs, deviceVendors)
            % Update DAQ device selection from dropdown list
            selectedName = dropdown.Value;
            idx = find(strcmp(deviceNames, selectedName), 1);
            if ~isempty(idx)
                % Stop visualization if running when device changes
                if app.IsRunning
                    stopVisualization(app);
                    app.StatusLabel.Text = 'Status: Stopped - Device selection changed. Click Start to begin.';
                end
                app.SelectedDataAcqDeviceId = deviceIDs{idx};
                app.SelectedDataAcqVendor = deviceVendors{idx};
            end
        end
        
        function closeDialog(app, dialogFig)
            % Stop visualization if running when device selection changes
            if app.IsRunning
                stopVisualization(app);
                app.StatusLabel.Text = 'Status: Stopped - Device selection changed. Click Start to begin.';
            end
            
            % Reinitialize audio recorders with new device selections
            initializeAudioRecorders(app);
            if ~app.IsRunning
                app.StatusLabel.Text = sprintf('Status: Device configured (%d channels detected)', app.NumChannels);
            end
            updateDeviceButtonText(app);
            savePreferences(app);
            delete(dialogFig);
        end
        
        function createColorPickerPanel(app)
            % Create the color picker panel (embedded in control panel, initially hidden)
            colors = getThemeColors(app);
            
            app.ColorPickerPanel = uipanel(app.ControlPanel);
            app.ColorPickerPanel.Title = 'Line Colors';
            app.ColorPickerPanel.BackgroundColor = colors.PanelAlt;
            app.ColorPickerPanel.ForegroundColor = colors.Text;
            app.ColorPickerPanel.FontName = app.AppFontName;
            app.ColorPickerPanel.FontSize = 10;
            app.ColorPickerPanel.Position = [10 410 220 190];
            app.ColorPickerPanel.Visible = 'off';
            
            % Channel dropdown
            channelLabel = uilabel(app.ColorPickerPanel);
            channelLabel.Text = 'Channel:';
            channelLabel.FontName = app.AppFontName;
            channelLabel.FontSize = 10;
            channelLabel.FontColor = colors.Text;
            channelLabel.Position = [10 145 60 20];
            
            app.ChannelDropdown = uidropdown(app.ColorPickerPanel);
            app.ChannelDropdown.Items = {'Channel 1'};
            app.ChannelDropdown.Value = 'Channel 1';
            app.ChannelDropdown.Position = [75 145 130 22];
            app.ChannelDropdown.FontName = app.AppFontName;
            app.ChannelDropdown.FontSize = 10;
            app.ChannelDropdown.ValueChangedFcn = createCallbackFcn(app, @ChannelDropdownValueChanged, true);
            
            % Color preview box
            app.ColorPreviewBox = uilabel(app.ColorPickerPanel);
            app.ColorPreviewBox.Text = '';
            app.ColorPreviewBox.BackgroundColor = [1 0.5 0];  % Default orange
            app.ColorPreviewBox.Position = [10 110 195 28];
            
            % Red slider
            app.ColorRedLabel = uilabel(app.ColorPickerPanel);
            app.ColorRedLabel.Text = 'R:';
            app.ColorRedLabel.FontName = app.AppFontName;
            app.ColorRedLabel.FontSize = 10;
            app.ColorRedLabel.FontColor = [0.9 0.3 0.3];
            app.ColorRedLabel.Position = [10 82 20 18];
            
            app.ColorRedSlider = uislider(app.ColorPickerPanel);
            app.ColorRedSlider.Limits = [0 1];
            app.ColorRedSlider.Value = 1;
            app.ColorRedSlider.Position = [30 90 170 3];
            app.ColorRedSlider.MajorTicks = [];
            app.ColorRedSlider.MinorTicks = [];
            app.ColorRedSlider.ValueChangingFcn = createCallbackFcn(app, @ColorSliderChanging, true);
            app.ColorRedSlider.ValueChangedFcn = createCallbackFcn(app, @ColorSliderChanged, true);
            
            % Green slider
            app.ColorGreenLabel = uilabel(app.ColorPickerPanel);
            app.ColorGreenLabel.Text = 'G:';
            app.ColorGreenLabel.FontName = app.AppFontName;
            app.ColorGreenLabel.FontSize = 10;
            app.ColorGreenLabel.FontColor = [0.3 0.9 0.3];
            app.ColorGreenLabel.Position = [10 52 20 18];
            
            app.ColorGreenSlider = uislider(app.ColorPickerPanel);
            app.ColorGreenSlider.Limits = [0 1];
            app.ColorGreenSlider.Value = 0.5;
            app.ColorGreenSlider.Position = [30 60 170 3];
            app.ColorGreenSlider.MajorTicks = [];
            app.ColorGreenSlider.MinorTicks = [];
            app.ColorGreenSlider.ValueChangingFcn = createCallbackFcn(app, @ColorSliderChanging, true);
            app.ColorGreenSlider.ValueChangedFcn = createCallbackFcn(app, @ColorSliderChanged, true);
            
            % Blue slider
            app.ColorBlueLabel = uilabel(app.ColorPickerPanel);
            app.ColorBlueLabel.Text = 'B:';
            app.ColorBlueLabel.FontName = app.AppFontName;
            app.ColorBlueLabel.FontSize = 10;
            app.ColorBlueLabel.FontColor = [0.3 0.3 0.9];
            app.ColorBlueLabel.Position = [10 22 20 18];
            
            app.ColorBlueSlider = uislider(app.ColorPickerPanel);
            app.ColorBlueSlider.Limits = [0 1];
            app.ColorBlueSlider.Value = 0;
            app.ColorBlueSlider.Position = [30 30 170 3];
            app.ColorBlueSlider.MajorTicks = [];
            app.ColorBlueSlider.MinorTicks = [];
            app.ColorBlueSlider.ValueChangingFcn = createCallbackFcn(app, @ColorSliderChanging, true);
            app.ColorBlueSlider.ValueChangedFcn = createCallbackFcn(app, @ColorSliderChanged, true);
        end
        
        function initializeChannelColors(app, numChannels)
            % Initialize channel colors with distinct default colors
            if numChannels < 1
                numChannels = 1;
            end
            
            % Use a set of visually distinct colors
            defaultColors = [
                0.93 0.67 0.00;  % Gold/Orange (WVU Gold-ish)
                0.00 0.45 0.74;  % Blue
                0.85 0.33 0.10;  % Red-orange
                0.49 0.18 0.56;  % Purple
                0.47 0.67 0.19;  % Green
                0.30 0.75 0.93;  % Cyan
                0.64 0.08 0.18;  % Dark red
                1.00 0.84 0.00;  % Yellow
            ];
            
            % Preserve existing colors if possible
            if isempty(app.ChannelColors)
                app.ChannelColors = zeros(numChannels, 3);
                for i = 1:numChannels
                    colorIdx = mod(i-1, size(defaultColors, 1)) + 1;
                    app.ChannelColors(i, :) = defaultColors(colorIdx, :);
                end
            elseif size(app.ChannelColors, 1) < numChannels
                % Extend with new colors
                oldCount = size(app.ChannelColors, 1);
                app.ChannelColors = [app.ChannelColors; zeros(numChannels - oldCount, 3)];
                for i = (oldCount+1):numChannels
                    colorIdx = mod(i-1, size(defaultColors, 1)) + 1;
                    app.ChannelColors(i, :) = defaultColors(colorIdx, :);
                end
            end
        end
        
        function updateColorPickerForChannel(app, channelIdx)
            % Update color picker sliders/preview for selected channel
            if channelIdx < 1 || channelIdx > size(app.ChannelColors, 1)
                return;
            end
            
            color = app.ChannelColors(channelIdx, :);
            
            app.ColorRedSlider.Value = color(1);
            app.ColorGreenSlider.Value = color(2);
            app.ColorBlueSlider.Value = color(3);
            app.ColorPreviewBox.BackgroundColor = color;
        end
        
        function updateColorPreview(app)
            % Update the color preview box from current slider values
            r = app.ColorRedSlider.Value;
            g = app.ColorGreenSlider.Value;
            b = app.ColorBlueSlider.Value;
            app.ColorPreviewBox.BackgroundColor = [r g b];
        end
        
        function applyCurrentColor(app)
            % Apply the current color to the selected channel
            channelStr = app.ChannelDropdown.Value;
            channelIdx = str2double(regexp(channelStr, '\d+', 'match', 'once'));
            
            if isnan(channelIdx) || channelIdx < 1
                return;
            end
            
            % Ensure channel colors array is large enough
            if size(app.ChannelColors, 1) < channelIdx
                initializeChannelColors(app, channelIdx);
            end
            
            r = app.ColorRedSlider.Value;
            g = app.ColorGreenSlider.Value;
            b = app.ColorBlueSlider.Value;
            app.ChannelColors(channelIdx, :) = [r g b];
            
            % Force redraw of plot lines with new color
            app.PlotLines = {};  % Clear to trigger full redraw
            
            savePreferences(app);
        end
        
        function updateChannelDropdownItems(app)
            % Update the channel dropdown with current number of channels
            numChannels = max(1, app.NumChannels);
            items = cell(numChannels, 1);
            for i = 1:numChannels
                items{i} = sprintf('Channel %d', i);
            end
            app.ChannelDropdown.Items = items;
            if ~any(strcmp(items, app.ChannelDropdown.Value))
                app.ChannelDropdown.Value = items{1};
            end
            
            % Update color picker for currently selected channel
            channelIdx = find(strcmp(items, app.ChannelDropdown.Value), 1);
            if isempty(channelIdx)
                channelIdx = 1;
            end
            updateColorPickerForChannel(app, channelIdx);
        end
        
        % Button pushed function: StartButton
        function StartButtonPushed(app, event)
            % Disable button immediately to show responsiveness
            app.StartButton.Enable = 'off';
            drawnow; % Allow UI to update immediately
            try
                startVisualization(app);
            catch ME
                % Re-enable button on error
                app.StartButton.Enable = 'on';
                drawnow;
                rethrow(ME);
            end
        end
        
        % Button pushed function: StopButton
        function StopButtonPushed(app, event)
            %#ok<INUSD>
            app.StopButton.Enable = 'off';
            drawnow;
            stopVisualization(app);
        end
        
        % Button pushed function: PauseButton
        function PauseButtonPushed(app, event)
            %#ok<INUSD>
            togglePause(app);
        end
        
        % Toggle pause state
        function togglePause(app)
            if ~app.IsRunning
                return;
            end
            
            app.IsPaused = ~app.IsPaused;
            
            if app.IsPaused
                app.PauseButton.Text = 'Resume';
                app.PauseButton.BackgroundColor = [0.8 0.6 0.0];  % Orange/amber for paused
                app.StatusLabel.Text = 'Status: Paused';
            else
                app.PauseButton.Text = 'Pause';
                app.PauseButton.BackgroundColor = [0.6 0.6 0.2];  % Yellow-ish for active pause button
                app.StatusLabel.Text = 'Status: Running';
            end
        end
        
        % Key press handler for UIFigure
        function UIFigureKeyPress(app, event)
            % Space bar toggles pause when running
            if strcmp(event.Key, 'space')
                if app.IsRunning
                    togglePause(app);
                end
            end
        end

        % Close request function: UIFigure
        function UIFigureCloseRequest(app, event)
            % Force stop everything immediately - don't wait for anything
            app.IsRunning = false;
            savePreferences(app);

            % Clear app variable from base workspace if present
            try
                evalin('base', 'if exist(''app'', ''var''), clear app; end');
            catch
            end
            
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
            cleanupAudioResources(app);
            
            % Clear plot lines
            app.PlotLines = {};
            
            % Delete the figure directly
            if isvalid(app.UIFigure)
                delete(app.UIFigure);
            end
            
            % Delete the app object
            delete(app);
        end
    end
end
