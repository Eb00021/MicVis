classdef MicVisualizer < matlab.apps.AppBase
    properties (Access = public)
        UIFigure                matlab.ui.Figure
        MainPanel               matlab.ui.container.Panel
        VisualizerPanel         matlab.ui.container.Panel
        ControlPanel            matlab.ui.container.Panel
        NumMicsSpinner          matlab.ui.control.Spinner
        NumMicsLabel            matlab.ui.control.Label
        StartButton             matlab.ui.control.Button
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
        SampleRateLabel         matlab.ui.control.Label
        SampleRateSpinner       matlab.ui.control.Spinner
        SelectInputsButton       matlab.ui.control.Button
        SplitGraphsButton         matlab.ui.control.Button
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
        NumMics = 1
        SampleRate = 44100
        BufferSize = 4096
        SelectedDeviceIDs = []
        SelectedDeviceNames = {}
        SelectedAudioDeviceName = ''
        SelectedAudioDriver = ''
        SplitInputs = false(16,1)
        SplitAxes = {}
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

            try
                opengl('hardware');
            catch
                warning('OpenGL hardware acceleration may not be available');
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
            app.ControlPanel.Position = [940 70 240 700];

            % Number of Microphones Spinner
            app.NumMicsLabel = uilabel(app.ControlPanel);
            app.NumMicsLabel.Text = 'Number of Mics:';
            app.NumMicsLabel.FontName = app.AppFontName;
            app.NumMicsLabel.FontSize = 12;
            app.NumMicsLabel.FontColor = app.WVUGold;
            app.NumMicsLabel.Position = [20 650 140 22];
            app.NumMicsLabel.HorizontalAlignment = 'left';

            app.NumMicsSpinner = uispinner(app.ControlPanel);
            app.NumMicsSpinner.Limits = [1 16];
            app.NumMicsSpinner.Value = 1;
            app.NumMicsSpinner.Position = [170 650 50 22];
            app.NumMicsSpinner.ValueChangedFcn = createCallbackFcn(app, @NumMicsSpinnerValueChanged, true);

            % Sample Rate Spinner
            app.SampleRateLabel = uilabel(app.ControlPanel);
            app.SampleRateLabel.Text = 'Sample Rate (Hz):';
            app.SampleRateLabel.FontName = app.AppFontName;
            app.SampleRateLabel.FontSize = 12;
            app.SampleRateLabel.FontColor = app.WVUGold;
            app.SampleRateLabel.Position = [20 615 140 22];
            app.SampleRateLabel.HorizontalAlignment = 'left';

            app.SampleRateSpinner = uispinner(app.ControlPanel);
            app.SampleRateSpinner.Limits = [8000 192000];
            app.SampleRateSpinner.Value = 44100;  % Default to 44.1kHz
            app.SampleRateSpinner.Step = 1000;
            app.SampleRateSpinner.Position = [150 615 70 22];
            app.SampleRateSpinner.ValueDisplayFormat = '%.0f';  % Display as integer, no scientific notation
            app.SampleRateSpinner.ValueChangedFcn = createCallbackFcn(app, @SampleRateSpinnerValueChanged, true);

            % Select Input Devices Button
            app.SelectInputsButton = uibutton(app.ControlPanel, 'push');
            app.SelectInputsButton.ButtonPushedFcn = createCallbackFcn(app, @SelectInputsButtonPushed, true);
            app.SelectInputsButton.Text = 'Select Input Devices';
            app.SelectInputsButton.FontName = app.AppFontName;
            app.SelectInputsButton.FontSize = 11;
            app.SelectInputsButton.FontWeight = 'bold';
            app.SelectInputsButton.BackgroundColor = app.WVUGold;
            app.SelectInputsButton.FontColor = app.WVUBlue;
            app.SelectInputsButton.Position = [20 570 200 32];

            % Gain Slider
            app.GainLabel = uilabel(app.ControlPanel);
            app.GainLabel.Text = 'Gain:';
            app.GainLabel.FontName = app.AppFontName;
            app.GainLabel.FontSize = 12;
            app.GainLabel.FontColor = app.WVUGold;
            app.GainLabel.Position = [20 520 120 22];
            app.GainLabel.HorizontalAlignment = 'left';

            app.GainValueLabel = uilabel(app.ControlPanel);
            app.GainValueLabel.Text = sprintf('%.2f', 1);
            app.GainValueLabel.FontName = app.AppFontName;
            app.GainValueLabel.FontSize = 11;
            app.GainValueLabel.FontColor = app.WVUGold;
            app.GainValueLabel.Position = [160 520 60 22];
            app.GainValueLabel.HorizontalAlignment = 'right';

            app.GainSlider = uislider(app.ControlPanel);
            app.GainSlider.Limits = [0.1 5];
            app.GainSlider.Value = 1;
            app.GainSlider.Position = [20 505 200 3];
            app.GainSlider.ValueChangedFcn = createCallbackFcn(app, @GainSliderValueChanged, true);
            app.GainSlider.ValueChangingFcn = createCallbackFcn(app, @GainSliderValueChanging, true);

            % Y-Axis Range Slider (constant y-limits for smoother updates)
            app.YAxisRangeLabel = uilabel(app.ControlPanel);
            app.YAxisRangeLabel.Text = 'Y Range (+/-):';
            app.YAxisRangeLabel.FontName = app.AppFontName;
            app.YAxisRangeLabel.FontSize = 12;
            app.YAxisRangeLabel.FontColor = app.WVUGold;
            app.YAxisRangeLabel.Position = [20 460 120 22];
            app.YAxisRangeLabel.HorizontalAlignment = 'left';

            app.YAxisRangeValueLabel = uilabel(app.ControlPanel);
            app.YAxisRangeValueLabel.Text = '1.00';
            app.YAxisRangeValueLabel.FontName = app.AppFontName;
            app.YAxisRangeValueLabel.FontSize = 11;
            app.YAxisRangeValueLabel.FontColor = app.WVUGold;
            app.YAxisRangeValueLabel.Position = [160 460 60 22];
            app.YAxisRangeValueLabel.HorizontalAlignment = 'right';

            app.YAxisRangeSlider = uislider(app.ControlPanel);
            app.YAxisRangeSlider.Limits = [0.1 5];
            app.YAxisRangeSlider.Value = 1;
            app.YAxisRangeSlider.Position = [20 450 200 3];
            app.YAxisRangeSlider.ValueChangedFcn = createCallbackFcn(app, @YAxisRangeSliderValueChanged, true);
            app.YAxisRangeSlider.ValueChangingFcn = createCallbackFcn(app, @YAxisRangeSliderValueChanging, true);

            % Display Options
            app.WaveformDisplayCheckBox = uicheckbox(app.ControlPanel);
            app.WaveformDisplayCheckBox.Text = 'Waveform Display';
            app.WaveformDisplayCheckBox.FontName = app.AppFontName;
            app.WaveformDisplayCheckBox.FontSize = 12;
            app.WaveformDisplayCheckBox.FontColor = app.WVUGold;
            app.WaveformDisplayCheckBox.Value = true;
            app.WaveformDisplayCheckBox.Position = [20 405 150 22];
            app.WaveformDisplayCheckBox.ValueChangedFcn = createCallbackFcn(app, @DisplayOptionValueChanged, true);

            app.FFTDisplayCheckBox = uicheckbox(app.ControlPanel);
            app.FFTDisplayCheckBox.Text = 'FFT Display';
            app.FFTDisplayCheckBox.FontName = app.AppFontName;
            app.FFTDisplayCheckBox.FontSize = 12;
            app.FFTDisplayCheckBox.FontColor = app.WVUGold;
            app.FFTDisplayCheckBox.Value = false;
            app.FFTDisplayCheckBox.Position = [20 380 150 22];
            app.FFTDisplayCheckBox.ValueChangedFcn = createCallbackFcn(app, @DisplayOptionValueChanged, true);

            % Split Graphs Button
            app.SplitGraphsButton = uibutton(app.ControlPanel, 'push');
            app.SplitGraphsButton.ButtonPushedFcn = createCallbackFcn(app, @SplitGraphsButtonPushed, true);
            app.SplitGraphsButton.Text = 'Configure Split Graphs';
            app.SplitGraphsButton.FontName = app.AppFontName;
            app.SplitGraphsButton.FontSize = 11;
            app.SplitGraphsButton.FontWeight = 'bold';
            app.SplitGraphsButton.BackgroundColor = app.WVUGold;
            app.SplitGraphsButton.FontColor = app.WVUBlue;
            app.SplitGraphsButton.Position = [20 330 200 30];

            % Fullscreen Button
            app.FullscreenButton = uibutton(app.ControlPanel, 'push');
            app.FullscreenButton.ButtonPushedFcn = createCallbackFcn(app, @FullscreenButtonPushed, true);
            app.FullscreenButton.Text = 'Fullscreen';
            app.FullscreenButton.FontName = app.AppFontName;
            app.FullscreenButton.FontSize = 11;
            app.FullscreenButton.FontWeight = 'bold';
            app.FullscreenButton.BackgroundColor = app.WVUGold;
            app.FullscreenButton.FontColor = app.WVUBlue;
            app.FullscreenButton.Position = [20 355 200 24];

            % Start Button
            app.StartButton = uibutton(app.ControlPanel, 'push');
            app.StartButton.ButtonPushedFcn = createCallbackFcn(app, @StartButtonPushed, true);
            app.StartButton.Text = 'Start';
            app.StartButton.FontName = app.AppFontName;
            app.StartButton.FontSize = 14;
            app.StartButton.FontWeight = 'bold';
            app.StartButton.BackgroundColor = [0.2 0.6 0.2];
            app.StartButton.FontColor = [1 1 1];
            app.StartButton.Position = [20 280 200 40];

            % Stop Button
            app.StopButton = uibutton(app.ControlPanel, 'push');
            app.StopButton.ButtonPushedFcn = createCallbackFcn(app, @StopButtonPushed, true);
            app.StopButton.Text = 'Stop';
            app.StopButton.FontName = app.AppFontName;
            app.StopButton.FontSize = 14;
            app.StopButton.FontWeight = 'bold';
            app.StopButton.BackgroundColor = [0.6 0.2 0.2];
            app.StopButton.FontColor = [1 1 1];
            app.StopButton.Position = [20 230 200 40];
            app.StopButton.Enable = 'off';

            % Status Label
            app.StatusLabel = uilabel(app.ControlPanel);
            app.StatusLabel.Text = 'Status: Ready';
            app.StatusLabel.FontName = app.AppFontName;
            app.StatusLabel.FontSize = 11;
            app.StatusLabel.FontColor = app.WVUGold;
            app.StatusLabel.Position = [20 180 200 22];
            app.StatusLabel.HorizontalAlignment = 'left';

            % Dark Mode Toggle
            app.DarkModeLabel = uilabel(app.ControlPanel);
            app.DarkModeLabel.Text = 'Dark Mode';
            app.DarkModeLabel.FontName = app.AppFontName;
            app.DarkModeLabel.FontSize = 11;
            app.DarkModeLabel.FontColor = app.WVUGold;
            app.DarkModeLabel.Position = [20 140 120 22];
            app.DarkModeLabel.HorizontalAlignment = 'left';

            app.DarkModeSwitch = uiswitch(app.ControlPanel, 'slider');
            app.DarkModeSwitch.Items = {'Light', 'Dark'};
            app.DarkModeSwitch.Value = 'Dark';
            app.DarkModeSwitch.Position = [150 140 70 22];
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
            labelHandles = {app.NumMicsLabel, app.SampleRateLabel, app.GainLabel, ...
                app.GainValueLabel, app.YAxisRangeLabel, app.YAxisRangeValueLabel, ...
                app.WaveformDisplayCheckBox, app.FFTDisplayCheckBox, app.StatusLabel, ...
                app.DarkModeLabel};
            for i = 1:numel(labelHandles)
                if ~isempty(labelHandles{i}) && isvalid(labelHandles{i})
                    labelHandles{i}.FontColor = colors.Text;
                end
            end

            if ~isempty(app.NumMicsSpinner) && isvalid(app.NumMicsSpinner)
                if isprop(app.NumMicsSpinner, 'FontColor')
                    app.NumMicsSpinner.FontColor = colors.Text;
                end
                if isprop(app.NumMicsSpinner, 'BackgroundColor')
                    app.NumMicsSpinner.BackgroundColor = colors.Panel;
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
            app.SplitGraphsButton.BackgroundColor = colors.ButtonSecondary;
            app.SplitGraphsButton.FontColor = colors.ButtonSecondaryText;
            app.FullscreenButton.BackgroundColor = colors.ButtonSecondary;
            app.FullscreenButton.FontColor = colors.ButtonSecondaryText;
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
            if ~isempty(app.SplitAxes)
                for i = 1:numel(app.SplitAxes)
                    applyAxesTheme(app, app.SplitAxes{i});
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

                if isfield(prefs, 'NumMics')
                    app.NumMics = max(1, min(16, prefs.NumMics));
                    app.NumMicsSpinner.Value = app.NumMics;
                end
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
                if isfield(prefs, 'SplitInputs')
                    split = logical(prefs.SplitInputs(:));
                    if length(split) ~= app.NumMics
                        split = false(app.NumMics, 1);
                    end
                    app.SplitInputs = split;
                else
                    app.SplitInputs = false(app.NumMics, 1);
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
        end

        function savePreferences(app)
            prefsPath = app.getPrefsFilePath();
            try
                prefs.NumMics = app.NumMics;
                prefs.SampleRate = app.SampleRate;
                prefs.Gain = app.GainSlider.Value;
                prefs.YAxisRange = app.YAxisRangeSlider.Value;
                prefs.WaveformDisplay = app.WaveformDisplayCheckBox.Value;
                prefs.FFTDisplay = app.FFTDisplayCheckBox.Value;
                prefs.SplitInputs = app.SplitInputs;
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
                channelCount = max(1, min(app.NumMics, 16));
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
                for i = 1:app.NumMics
                    app.AudioHistory{i} = zeros(0, 1);
                end
                app.DataAcqNoDataCount = 0;

                % Attach listener to collect data continuously
                app.DataAcqListener = addlistener(dq, "DataAvailable", ...
                    @(~, evt) onDataAcqDataAvailable(app, evt));

                app.StatusLabel.Text = sprintf('Status: Ready at %d Hz (DAQ)', app.SampleRate);
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
                numChannels = size(frameData, 2);
                if numChannels <= 1 && app.NumMics > 1
                    % Duplicate single channel for multiple mic displays
                    for micIdx = 1:app.NumMics
                        app.AudioHistory{micIdx} = [app.AudioHistory{micIdx}; frameData(:)];
                        if length(app.AudioHistory{micIdx}) > maxHistorySamples
                            app.AudioHistory{micIdx} = app.AudioHistory{micIdx}(end-maxHistorySamples+1:end);
                        end
                    end
                else
                    channelsToUse = min(app.NumMics, numChannels);
                    for micIdx = 1:channelsToUse
                        app.AudioHistory{micIdx} = [app.AudioHistory{micIdx}; frameData(:, micIdx)];
                        if length(app.AudioHistory{micIdx}) > maxHistorySamples
                            app.AudioHistory{micIdx} = app.AudioHistory{micIdx}(end-maxHistorySamples+1:end);
                        end
                    end
                    if channelsToUse < app.NumMics && channelsToUse > 0
                        % Duplicate last available channel for remaining displays
                        lastChannel = frameData(:, channelsToUse);
                        for micIdx = (channelsToUse + 1):app.NumMics
                            app.AudioHistory{micIdx} = [app.AudioHistory{micIdx}; lastChannel];
                            if length(app.AudioHistory{micIdx}) > maxHistorySamples
                                app.AudioHistory{micIdx} = app.AudioHistory{micIdx}(end-maxHistorySamples+1:end);
                            end
                        end
                    end
                end
            catch
                % Ignore listener errors
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
                driverToUse = '';
                try
                    info = audiodevinfo;
                    inputDevices = info.input;
                    if ~isempty(inputDevices)
                        % Prefer selected device ID if available (from input dialog)
                        if ~isempty(app.SelectedDeviceIDs)
                            matchIdx = find([inputDevices.ID] == app.SelectedDeviceIDs(1), 1);
                            if ~isempty(matchIdx)
                                deviceToUse = inputDevices(matchIdx).Name;
                            end
                        end
                        % Fall back to selected device name or first device
                        if isempty(deviceToUse)
                            if ~isempty(app.SelectedAudioDeviceName)
                                deviceToUse = app.SelectedAudioDeviceName;
                                driverToUse = app.SelectedAudioDriver;
                            end
                            if ~isempty(app.SelectedDeviceNames) && length(app.SelectedDeviceNames) >= 1
                                deviceToUse = app.SelectedDeviceNames{1};
                            else
                                deviceToUse = inputDevices(1).Name;
                            end
                        end
                    end
                catch
                    % Will use default device
                end
                
                % Create audioDeviceReader following MathWorks pattern
                % Frame size: 1024 samples is standard for real-time processing
                samplesPerFrame = 1024;
                
                desiredChannels = max(1, min(app.NumMics, 16));
                reader = [];
                try
                    if ~isempty(deviceToUse)
                        reader = audioDeviceReader(...
                            'Driver', driverToUse, ...
                            'Device', deviceToUse, ...
                            'SampleRate', app.SampleRate, ...
                            'SamplesPerFrame', samplesPerFrame, ...
                            'NumChannels', desiredChannels);
                    else
                        reader = audioDeviceReader(...
                            'Driver', driverToUse, ...
                            'SampleRate', app.SampleRate, ...
                            'SamplesPerFrame', samplesPerFrame, ...
                            'NumChannels', desiredChannels);
                    end
                catch
                end
                if isempty(reader)
                    try
                        if ~isempty(deviceToUse)
                            reader = audioDeviceReader(...
                                'Driver', driverToUse, ...
                                'Device', deviceToUse, ...
                                'SampleRate', app.SampleRate, ...
                                'SamplesPerFrame', samplesPerFrame);
                        else
                            reader = audioDeviceReader(...
                                'Driver', driverToUse, ...
                                'SampleRate', app.SampleRate, ...
                                'SamplesPerFrame', samplesPerFrame);
                        end
                    catch
                        % Fallback to default device
                        reader = audioDeviceReader(...
                            'SampleRate', app.SampleRate, ...
                            'SamplesPerFrame', samplesPerFrame);
                    end
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
                
                % Update status with device info
                if length(app.AudioRecorders) == app.NumMics
                    app.StatusLabel.Text = sprintf('Status: Initialized %d microphone(s) at %d Hz', ...
                        length(app.AudioRecorders), app.SampleRate);
                else
                    app.StatusLabel.Text = sprintf('Status: Initialized %d microphone(s) (requested %d)', ...
                        length(app.AudioRecorders), app.NumMics);
                end

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
            setControlsForRunning(app, true);
                drawnow; % Allow UI to update before starting timer
                
                % Create timer for real-time visualization
                % Following MathWorks pattern: read frames and display immediately
                warning('off', 'MATLAB:audiorecorder:timeout');
                warning('off', 'matlabshared:asyncio:timeout');
                
                % Timer period: update at ~25 FPS for smoother visualization
                % For audioDeviceReader with 1024 samples at 48kHz: ~21ms per frame
                % Timer at 40ms balances smoothness and missed frames
                timerPeriod = 0.04;  % 40ms = 25 FPS
                
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
                if isvalid(app.StatusLabel)
                    app.StatusLabel.Text = 'Status: Stopped';
                end
                setControlsForRunning(app, false);
                if isvalid(app.UIFigure)
                    drawnow; % Allow UI to update immediately
                end
            catch
            end
            
            % Clear axes and cleanup split axes
            try
                if isvalid(app.MicAxes)
                    cla(app.MicAxes);
                    cleanupSplitAxes(app);
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
                newXMin = currentXLim(1) + (xMin - currentXLim(1)) * app.SmoothingFactor;
                newXMax = currentXLim(2) + (xMax - currentXLim(2)) * app.SmoothingFactor;
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
                newXMin = currentXLim(1) + (xMin - currentXLim(1)) * app.SmoothingFactor;
                newXMax = currentXLim(2) + (xMax - currentXLim(2)) * app.SmoothingFactor;
            end
            
            % Apply limits
            ax.YLim = [newYMin, newYMax];
            ax.XLim = [newXMin, newXMax];
        end
        
        function updateVisualization(app)
            if ~app.IsRunning
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
                        if app.NumMics == 1
                            audioData = app.AudioHistory{1}(:);
                        else
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
                        timeData = (0:length(audioData)-1) / app.SampleRate;
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
                                numChannels = size(frameData, 2);
                                if numChannels <= 1 && app.NumMics > 1
                                    % Duplicate single channel for multiple mic displays
                                    for micIdx = 1:app.NumMics
                                        app.AudioHistory{micIdx} = [app.AudioHistory{micIdx}; frameData(:)];
                                        if length(app.AudioHistory{micIdx}) > maxHistorySamples
                                            app.AudioHistory{micIdx} = app.AudioHistory{micIdx}(end-maxHistorySamples+1:end);
                                        end
                                    end
                                else
                                    channelsToUse = min(app.NumMics, numChannels);
                                    for micIdx = 1:channelsToUse
                                        app.AudioHistory{micIdx} = [app.AudioHistory{micIdx}; frameData(:, micIdx)];
                                        if length(app.AudioHistory{micIdx}) > maxHistorySamples
                                            app.AudioHistory{micIdx} = app.AudioHistory{micIdx}(end-maxHistorySamples+1:end);
                                        end
                                    end
                                    if channelsToUse < app.NumMics && channelsToUse > 0
                                        % Duplicate last available channel for remaining displays
                                        lastChannel = frameData(:, channelsToUse);
                                        for micIdx = (channelsToUse + 1):app.NumMics
                                            app.AudioHistory{micIdx} = [app.AudioHistory{micIdx}; lastChannel];
                                            if length(app.AudioHistory{micIdx}) > maxHistorySamples
                                                app.AudioHistory{micIdx} = app.AudioHistory{micIdx}(end-maxHistorySamples+1:end);
                                            end
                                        end
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
                if app.UseDataAcq
                    app.StatusLabel.Text = sprintf('Status: Running at %d Hz (DAQ)', app.SampleRate);
                elseif app.UseAudioToolbox
                    app.StatusLabel.Text = sprintf('Status: Running at %d Hz', app.SampleRate);
                else
                    app.StatusLabel.Text = sprintf('Status: Running (%d channel(s))', size(audioData, 2));
                end
                
                showWaveform = app.WaveformDisplayCheckBox.Value;
                showFFT = app.FFTDisplayCheckBox.Value;
                
                % If neither is selected, clear plots and skip rendering
                if ~showWaveform && ~showFFT
                    if ~isempty(app.SplitAxes)
                        for i = 1:numel(app.SplitAxes)
                            if isvalid(app.SplitAxes{i})
                                ax = app.SplitAxes{i};
                                cla(ax);
                                applyAxesTheme(app, ax);
                                ax.Title.String = 'No display mode selected';
                                ax.XLabel.String = '';
                                ax.YLabel.String = '';
                            end
                        end
                    end
                    cla(app.MicAxes);
                    applyAxesTheme(app, app.MicAxes);
                    app.MicAxes.Title.String = 'No display mode selected';
                    app.MicAxes.XLabel.String = '';
                    app.MicAxes.YLabel.String = '';
                    return;
                end

                if showWaveform
                    waveformData = audioData - mean(audioData, 1);
                else
                    waveformData = audioData;
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
                        applyAxesTheme(app, ax);
                        hold(ax, 'on');
                        
                        if showWaveform
                            plot(ax, timeData, waveformData(:, channelIdx), ...
                                'Color', colors.Accent, 'LineWidth', 1.5);
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
                                applyInitialFftRange(app, P1(idx));
                                plot(ax, f(idx), P1(idx), 'Color', colors.Accent, 'LineWidth', 2);
                                ax.YLabel.String = 'Magnitude';
                                ax.XLabel.String = 'Frequency (Hz)';
                                ax.Title.String = sprintf('Input %d - Frequency Spectrum', channelIdx);
                            end
                        end
                        hold(ax, 'off');
                        ax.XGrid = 'on';
                        ax.YGrid = 'on';
                        
                        % Apply smooth axis scaling for split axes
                        if showWaveform
                            updateSmoothAxisLimits(app, ax, timeData, waveformData(:, channelIdx), false);
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
                                updateSmoothAxisLimitsFFT(app, ax, f(idx), P1(idx));
                            end
                        end
                    end
                end
                
                % Plot combined inputs on main axes
                if ~isempty(combinedIndices)
                    cla(app.MicAxes);
                    applyAxesTheme(app, app.MicAxes);
                    hold(app.MicAxes, 'on');
                    
                    if showWaveform && ~showFFT
                        channelColors = getChannelColors(app, length(combinedIndices));
                        for i = 1:length(combinedIndices)
                            chIdx = combinedIndices(i);
                            plot(app.MicAxes, timeData, waveformData(:, chIdx), ...
                                'Color', channelColors(i,:), 'LineWidth', 1.5, ...
                                'DisplayName', sprintf('Mic %d', chIdx));
                        end
                        app.MicAxes.YLabel.String = 'Amplitude';
                        app.MicAxes.XLabel.String = 'Time (s)';
                        app.MicAxes.Title.String = sprintf('Combined Waveform (%d Mic(s))', length(combinedIndices));
                        legend(app.MicAxes, 'show', 'Location', 'best');
                        applyLegendTheme(app, app.MicAxes, colors);
                        
                    elseif showFFT && ~showWaveform
                        fftData = mean(audioData(:, combinedIndices), 2);
                        N = length(fftData);
                        f = [];
                        P1 = [];
                        if N > 0
                            windowed = fftData .* hann(N);
                            Y = fft(windowed);
                            P2 = abs(Y/N);
                            P1 = P2(1:N/2+1);
                            P1(2:end-1) = 2*P1(2:end-1);
                            f = app.SampleRate*(0:(N/2))/N;
                            maxFreq = min(8000, app.SampleRate/2);
                            idx = f <= maxFreq;
                            applyInitialFftRange(app, P1(idx));
                            plot(app.MicAxes, f(idx), P1(idx), ...
                                'Color', colors.Accent, 'LineWidth', 2);
                            app.MicAxes.YLabel.String = 'Magnitude';
                            app.MicAxes.XLabel.String = 'Frequency (Hz)';
                            app.MicAxes.Title.String = 'Combined Frequency Spectrum';
                        end
                        
                    elseif showWaveform && showFFT
                        channelColors = getChannelColors(app, length(combinedIndices));
                        for i = 1:length(combinedIndices)
                            chIdx = combinedIndices(i);
                            plot(app.MicAxes, timeData, waveformData(:, chIdx), ...
                                'Color', channelColors(i,:), 'LineWidth', 1.5, ...
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
                        legend(app.MicAxes, 'show', 'Location', 'best');
                        applyLegendTheme(app, app.MicAxes, colors);
                    end
                    
                    hold(app.MicAxes, 'off');
                    app.MicAxes.XGrid = 'on';
                    app.MicAxes.YGrid = 'on';
                    
                    % Apply smooth axis scaling
                    if showWaveform && ~showFFT
                        % Waveform only
                        updateSmoothAxisLimits(app, app.MicAxes, timeData, waveformData(:, combinedIndices), false);
                    elseif showFFT && ~showWaveform
                        % FFT only - use pre-calculated data
                        if ~isempty(f) && ~isempty(P1)
                            maxFreq = min(8000, app.SampleRate/2);
                            idx = f <= maxFreq;
                            updateSmoothAxisLimitsFFT(app, app.MicAxes, f(idx), P1(idx));
                        end
                    elseif showWaveform && showFFT
                        % Both - scale for waveform (FFT is just shown in title)
                        updateSmoothAxisLimits(app, app.MicAxes, timeData, waveformData(:, combinedIndices), false);
                    end
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
        
        % Code that executes when component value is changed.
        function NumMicsSpinnerValueChanged(app, event)
            newNumMics = app.NumMicsSpinner.Value;

            if app.IsApplyingPrefs
                app.NumMics = newNumMics;
                app.SplitInputs = false(newNumMics, 1);
                return;
            end

            if app.IsRunning
                app.IsApplyingPrefs = true;
                app.NumMicsSpinner.Value = app.NumMics;
                app.IsApplyingPrefs = false;
                app.StatusLabel.Text = 'Status: Change will take effect after restart';
                return;
            end

            useDaq = checkDataAcqToolbox(app);
            hasAudioToolbox = checkAudioToolbox(app);
            
            % Adjust SelectedDeviceIDs array if number of mics changed
            if ~useDaq && newNumMics ~= app.NumMics
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
            initializeAudioRecorders(app);

            savePreferences(app);
        end
        
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
            if ~isempty(app.SplitAxes)
                for i = 1:numel(app.SplitAxes)
                    if ~isempty(app.SplitAxes{i}) && isvalid(app.SplitAxes{i})
                        app.SplitAxes{i}.YLim = [-yRange, yRange];
                    end
                end
            end
        end

        function setControlsForRunning(app, isRunning)
            if isempty(app.UIFigure) || ~isvalid(app.UIFigure)
                return;
            end
            state = 'on';
            if isRunning
                state = 'off';
            end
            if ~isempty(app.NumMicsSpinner) && isvalid(app.NumMicsSpinner)
                app.NumMicsSpinner.Enable = state;
            end
            if ~isempty(app.SampleRateSpinner) && isvalid(app.SampleRateSpinner)
                app.SampleRateSpinner.Enable = state;
            end
            if ~isempty(app.SelectInputsButton) && isvalid(app.SelectInputsButton)
                app.SelectInputsButton.Enable = state;
            end
            if ~isempty(app.SplitGraphsButton) && isvalid(app.SplitGraphsButton)
                app.SplitGraphsButton.Enable = state;
            end
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
        
        % Button pushed function: SplitGraphsButton
        function SplitGraphsButtonPushed(app, event)
            % Allow UI to update before showing dialog
            drawnow;
            showSplitGraphsDialog(app);
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
            % Adjust height based on number of microphones
            numMics = app.NumMics;
            baseHeight = 150;
            micHeight = 35;
            dialogHeight = min(600, baseHeight + numMics * micHeight); % Cap at 600px
            useDaq = checkDataAcqToolbox(app);
            hasAudioToolbox = checkAudioToolbox(app);
            colors = getThemeColors(app);
            
            dialogFig = uifigure('Visible', 'off');
            dialogFig.Position = [400 300 500 dialogHeight];
            dialogFig.Name = 'Select Audio Input Devices';
            dialogFig.Color = colors.Window;
            dialogFig.Resize = 'off';
            applyDialogIcon(app, dialogFig);
            
            % Main panel
            mainPanel = uipanel(dialogFig);
            mainPanel.BackgroundColor = colors.PanelAlt;
            mainPanel.Position = [10 10 480 dialogHeight-20];
            mainPanel.BorderType = 'line';
            if isprop(mainPanel, 'BorderColor')
                mainPanel.BorderColor = colors.Border;
            end
            
            % Title
            titleLabel = uilabel(mainPanel);
            titleLabel.Text = 'Select Input Device for Each Microphone';
            titleLabel.FontName = app.AppFontName;
            titleLabel.FontSize = 16;
            titleLabel.FontWeight = 'bold';
            titleLabel.FontColor = colors.Text;
            titleLabel.Position = [20 dialogHeight-50 440 30];
            titleLabel.HorizontalAlignment = 'center';

            % Note about multi-channel USB interfaces without Audio Toolbox/DAQ
            if ~useDaq && ~hasAudioToolbox
                noteLabel = uilabel(mainPanel);
                noteLabel.Text = ['Audio Toolbox not detected. Multi-channel USB interfaces ' ...
                    '(e.g., UMC404HD) may not appear without Audio Toolbox or Data Acquisition Toolbox.'];
                noteLabel.FontName = app.AppFontName;
                noteLabel.FontSize = 10;
                noteLabel.FontColor = colors.TextMuted;
                noteLabel.Position = [20 dialogHeight-105 440 40];
                noteLabel.HorizontalAlignment = 'center';
                noteLabel.WordWrap = 'on';
            end
            
            % Refresh button
            refreshBtn = uibutton(mainPanel, 'push');
            refreshBtn.Text = 'Refresh Devices';
            refreshBtn.FontName = app.AppFontName;
            refreshBtn.FontSize = 10;
            refreshBtn.FontWeight = 'bold';
            refreshBtn.BackgroundColor = colors.ButtonSecondary;
            refreshBtn.FontColor = colors.ButtonSecondaryText;
            refreshBtn.Position = [20 dialogHeight-80 120 25];

            % Device summary label (updated on refresh)
            deviceSummaryLabel = uilabel(mainPanel);
            deviceSummaryLabel.Text = 'Detecting devices...';
            deviceSummaryLabel.FontName = app.AppFontName;
            deviceSummaryLabel.FontSize = 10;
            deviceSummaryLabel.FontColor = colors.Text;
            deviceSummaryLabel.Position = [160 dialogHeight-82 280 22];
            deviceSummaryLabel.HorizontalAlignment = 'left';
            
            % Create dropdowns for each microphone (will be populated by refresh function)
            numMics = app.NumMics;
            dropdowns = cell(numMics, 1);
            labels = cell(numMics, 1);
            startY = dialogHeight - 120;
            spacing = 35;
            
            % Function to refresh device list and update dropdowns
            function refreshDeviceList()
                inputDevices = [];
                deviceNames = {};
                deviceIDs = [];
                deviceVendors = {};
                deviceDrivers = {};
                useAudioToolboxList = false;
                useDaqList = useDaq;

                if useDaq
                    % Prefer DAQ device list when available
                    try
                        vendorsToTry = ["directsound", "wasapi"];
                        for v = vendorsToTry
                            try
                                t = daqlist(v);
                                if ~isempty(t)
                                    for k = 1:height(t)
                                        deviceNames{end+1,1} = sprintf('%s (%s:%s)', ...
                                            t.Description(k), v, t.DeviceID(k));
                                        deviceIDs{end+1,1} = char(t.DeviceID(k));
                                        deviceVendors{end+1,1} = char(v);
                                    end
                                end
                            catch
                            end
                        end
                    catch
                    end
                    % If DAQ has no devices, fall back to Audio Toolbox list
                    if isempty(deviceNames) && hasAudioToolbox && exist('getAudioDevices', 'file') == 2
                        try
                            % Prefer ASIO, then WASAPI/DirectSound
                            driversToTry = ["ASIO", "WASAPI", "DirectSound"];
                            for d = driversToTry
                                try
                                    r = audioDeviceReader('Driver', char(d));
                                    devs = getAudioDevices(r);
                                    release(r);
                                    if ~isempty(devs)
                                        for k = 1:numel(devs)
                                            deviceNames{end+1,1} = devs{k};
                                            deviceDrivers{end+1,1} = char(d);
                                        end
                                        useAudioToolboxList = true;
                                    end
                                catch
                                end
                                if useAudioToolboxList
                                    break;
                                end
                            end
                            if ~useAudioToolboxList
                                devs = getAudioDevices;
                                if ~isempty(devs)
                                    deviceNames = devs(:);
                                    deviceDrivers = repmat({''}, numel(devs), 1);
                                    useAudioToolboxList = true;
                                end
                            end
                        catch
                            deviceNames = {};
                        end
                    end
                    % If still empty, fall back to legacy list
                    if isempty(deviceNames) && ~useAudioToolboxList
                        try
                            info = audiodevinfo;
                            inputDevices = info.input;
                        catch
                            inputDevices = [];
                        end
                    end
                else
                    if hasAudioToolbox && exist('getAudioDevices', 'file') == 2
                        % Audio Toolbox device list (includes multi-channel interfaces)
                        try
                            driversToTry = ["ASIO", "WASAPI", "DirectSound"];
                            for d = driversToTry
                                try
                                    r = audioDeviceReader('Driver', char(d));
                                    devs = getAudioDevices(r);
                                    release(r);
                                    if ~isempty(devs)
                                        for k = 1:numel(devs)
                                            deviceNames{end+1,1} = devs{k};
                                            deviceDrivers{end+1,1} = char(d);
                                        end
                                        useAudioToolboxList = true;
                                    end
                                catch
                                end
                                if useAudioToolboxList
                                    break;
                                end
                            end
                            if ~useAudioToolboxList
                                devs = getAudioDevices;
                                if ~isempty(devs)
                                    deviceNames = devs(:);
                                    deviceDrivers = repmat({''}, numel(devs), 1);
                                    useAudioToolboxList = true;
                                end
                            end
                        catch
                            deviceNames = {};
                        end
                    end
                    if ~useAudioToolboxList
                        % Legacy device list
                        try
                            info = audiodevinfo;
                            inputDevices = info.input;
                        catch
                            inputDevices = [];
                        end
                    end
                end
                
                useDaqList = useDaq && ~useAudioToolboxList;
                if ~useAudioToolboxList && ~isempty(inputDevices)
                    % Use legacy device list (even if DAQ toolbox is present)
                    useDaqList = false;
                    deviceNames = cell(length(inputDevices), 1);
                    deviceIDs = zeros(length(inputDevices), 1);
                    for i = 1:length(inputDevices)
                        deviceNames{i} = sprintf('%s (ID: %d)', inputDevices(i).Name, inputDevices(i).ID);
                        deviceIDs(i) = inputDevices(i).ID;
                    end
                end

                if isempty(deviceNames)
                    if isvalid(deviceSummaryLabel)
                        if useDaq
                            deviceSummaryLabel.Text = 'No DAQ audio devices detected';
                        elseif useAudioToolboxList
                            deviceSummaryLabel.Text = 'No Audio Toolbox devices detected';
                        else
                            deviceSummaryLabel.Text = 'No legacy audio devices detected';
                        end
                    end
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
                        if ~hasAudioToolbox && ~useDaq
                            errorLabel.Text = ['No audio input devices found. Some interfaces (ASIO) are not visible without ' ...
                                'Audio Toolbox or Data Acquisition Toolbox.'];
                        else
                            errorLabel.Text = 'No audio input devices found. Plug in a microphone and click Refresh.';
                        end
                        errorLabel.FontName = app.AppFontName;
                        errorLabel.FontSize = 12;
                    errorLabel.FontColor = colors.Danger;
                        errorLabel.Position = [20 max(60, dialogHeight-180) 440 60];
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
                if isvalid(deviceSummaryLabel)
                    if useAudioToolboxList
                        deviceSummaryLabel.Text = sprintf('Audio Toolbox devices detected: %d', length(deviceNames));
                    elseif useDaq
                        deviceSummaryLabel.Text = sprintf('DAQ devices detected: %d', length(deviceNames));
                    else
                        deviceSummaryLabel.Text = sprintf('Legacy devices detected: %d', length(deviceNames));
                    end
                end
                
                if useDaqList
                    % DAQ only supports one stream; show one dropdown and hide others
                    if isempty(app.SelectedDataAcqDeviceId) && ~isempty(deviceIDs)
                        app.SelectedDataAcqDeviceId = deviceIDs{1};
                        app.SelectedDataAcqVendor = deviceVendors{1};
                    end
                elseif useAudioToolboxList
                    % Initialize selected device names if empty
                    if isempty(app.SelectedDeviceNames) || length(app.SelectedDeviceNames) < numMics
                        app.SelectedDeviceNames = cell(numMics, 1);
                        for i = 1:min(numMics, length(deviceNames))
                            app.SelectedDeviceNames{i} = deviceNames{i};
                        end
                        % Fill remaining with first device
                        if numMics > length(deviceNames) && ~isempty(deviceNames)
                            for i = length(deviceNames)+1:numMics
                                app.SelectedDeviceNames{i} = deviceNames{1};
                            end
                        end
                    end
                    if isempty(app.SelectedAudioDeviceName) && ~isempty(deviceNames)
                        app.SelectedAudioDeviceName = deviceNames{1};
                    end
                    if isempty(app.SelectedAudioDriver) && ~isempty(deviceDrivers)
                        app.SelectedAudioDriver = deviceDrivers{1};
                    end
                else
                    % Initialize selected device IDs if empty
                    if isempty(app.SelectedDeviceIDs) || length(app.SelectedDeviceIDs) < numMics
                        app.SelectedDeviceIDs = zeros(numMics, 1);
                        for i = 1:min(numMics, length(deviceIDs))
                            app.SelectedDeviceIDs(i) = deviceIDs(i);
                        end
                        % Fill remaining with first device
                        if numMics > length(deviceIDs)
                            for i = length(deviceIDs)+1:numMics
                                app.SelectedDeviceIDs(i) = deviceIDs(1);
                            end
                        end
                    end
                end
                
                % Create or update dropdowns for each microphone
                for i = 1:numMics
                    % Create label if it doesn't exist
                    if isempty(labels{i}) || ~isvalid(labels{i})
                        labels{i} = uilabel(mainPanel);
                        if useDaqList && i == 1
                            labels{i}.Text = 'Audio Input Device:';
                        else
                            labels{i}.Text = sprintf('Microphone %d:', i);
                        end
                        labels{i}.FontName = app.AppFontName;
                        labels{i}.FontSize = 11;
                        labels{i}.FontColor = colors.Text;
                        labels{i}.Position = [30 startY - (i-1)*spacing 120 22];
                        labels{i}.HorizontalAlignment = 'left';
                    end
                    if useDaqList && i > 1
                        labels{i}.Visible = 'off';
                    else
                        labels{i}.Visible = 'on';
                    end
                    
                    % Create or update dropdown
                    if isempty(dropdowns{i}) || ~isvalid(dropdowns{i})
                        dropdowns{i} = uidropdown(mainPanel);
                        dropdowns{i}.FontName = app.AppFontName;
                        dropdowns{i}.FontSize = 11;
                        dropdowns{i}.Position = [160 startY - (i-1)*spacing 280 22];
                        if isprop(dropdowns{i}, 'FontColor')
                            dropdowns{i}.FontColor = colors.Text;
                        end
                        if isprop(dropdowns{i}, 'BackgroundColor')
                            dropdowns{i}.BackgroundColor = colors.Panel;
                        end
                    end
                    
                    % Update dropdown items with fresh device list
                    dropdowns{i}.Items = deviceNames;
                    if useDaqList && i > 1
                        dropdowns{i}.Visible = 'off';
                    else
                        dropdowns{i}.Visible = 'on';
                    end
                    
                    % Set current selection (try to preserve if device still exists)
                    if useDaqList
                        currentID = app.SelectedDataAcqDeviceId;
                        idx = find(strcmp(deviceIDs, currentID), 1);
                        if ~isempty(idx)
                            dropdowns{i}.Value = deviceNames{idx};
                        else
                            if ~isempty(deviceNames)
                                dropdowns{i}.Value = deviceNames{1};
                                app.SelectedDataAcqDeviceId = deviceIDs{1};
                                app.SelectedDataAcqVendor = deviceVendors{1};
                            end
                        end
                    elseif useAudioToolboxList
                        if length(app.SelectedDeviceNames) >= i && ~isempty(app.SelectedDeviceNames{i})
                            currentName = app.SelectedDeviceNames{i};
                        else
                            currentName = '';
                        end
                        idx = find(strcmp(deviceNames, currentName), 1);
                        if ~isempty(idx)
                            dropdowns{i}.Value = deviceNames{idx};
                        else
                            if ~isempty(deviceNames)
                                dropdowns{i}.Value = deviceNames{1};
                                app.SelectedDeviceNames{i} = deviceNames{1};
                            end
                        end
                    else
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
                    end
                    
                    % Store device ID when changed - use a callback that looks up from current items
                    % This ensures it works even after refresh
                    micIdx = i; % Capture loop variable
                    if useDaqList
                        dropdowns{i}.ValueChangedFcn = @(src,~) updateDataAcqSelectionFromDropdown(app, src, deviceNames, deviceIDs, deviceVendors);
                    elseif useAudioToolboxList
                        dropdowns{i}.ValueChangedFcn = @(src,~) updateDeviceNameFromDropdown(app, micIdx, src, deviceNames, deviceDrivers);
                    else
                        dropdowns{i}.ValueChangedFcn = @(src,~) updateDeviceIDFromDropdown(app, micIdx, src);
                    end
                end
            end
            
            % Set refresh button callback
            refreshBtn.ButtonPushedFcn = @(~,~) refreshDeviceList();
            
            % Initial refresh of device list
            refreshDeviceList();
            
            % Buttons
            okBtn = uibutton(mainPanel, 'push');
            okBtn.Text = 'OK';
            okBtn.FontName = app.AppFontName;
            okBtn.FontSize = 12;
            okBtn.FontWeight = 'bold';
            okBtn.BackgroundColor = colors.Success;
            okBtn.FontColor = [1 1 1];
            okBtn.Position = [150 30 100 35];
            okBtn.ButtonPushedFcn = @(~,~) closeDialog(app, dialogFig);
            
            cancelBtn = uibutton(mainPanel, 'push');
            cancelBtn.Text = 'Cancel';
            cancelBtn.FontName = app.AppFontName;
            cancelBtn.FontSize = 12;
            cancelBtn.FontWeight = 'bold';
            cancelBtn.BackgroundColor = colors.Danger;
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
                app.StatusLabel.Text = sprintf('Status: Devices configured for %d microphone(s)', app.NumMics);
            end
            savePreferences(app);
            delete(dialogFig);
        end
        
        function showSplitGraphsDialog(app)
            % Create dialog for selecting which inputs to split onto separate graphs
            numMics = app.NumMics;
            dialogHeight = min(500, 150 + numMics * 30);
            colors = getThemeColors(app);
            
            dialogFig = uifigure('Visible', 'off');
            dialogFig.Position = [400 300 400 dialogHeight];
            dialogFig.Name = 'Configure Split Graphs';
            dialogFig.Color = colors.Window;
            dialogFig.Resize = 'off';
            applyDialogIcon(app, dialogFig);
            
            % Main panel
            mainPanel = uipanel(dialogFig);
            mainPanel.BackgroundColor = colors.PanelAlt;
            mainPanel.Position = [10 10 380 dialogHeight-20];
            mainPanel.BorderType = 'line';
            if isprop(mainPanel, 'BorderColor')
                mainPanel.BorderColor = colors.Border;
            end
            
            % Title
            titleLabel = uilabel(mainPanel);
            titleLabel.Text = 'Select Inputs to Display on Separate Graphs';
            titleLabel.FontName = app.AppFontName;
            titleLabel.FontSize = 14;
            titleLabel.FontWeight = 'bold';
            titleLabel.FontColor = colors.Text;
            titleLabel.Position = [20 dialogHeight-60 340 30];
            titleLabel.HorizontalAlignment = 'center';
            
            % Create checkboxes for each input
            checkboxes = cell(numMics, 1);
            startY = dialogHeight - 100;
            spacing = 30;
            
            for i = 1:numMics
                checkboxes{i} = uicheckbox(mainPanel);
                checkboxes{i}.Text = sprintf('Split Input %d', i);
                checkboxes{i}.FontName = app.AppFontName;
                checkboxes{i}.FontSize = 11;
                checkboxes{i}.FontColor = colors.Text;
                checkboxes{i}.Value = app.SplitInputs(i);
                checkboxes{i}.Position = [40 startY - (i-1)*spacing 200 22];
                
                % Store callback - need to use a function handle that properly assigns
                micIdx = i;
                checkboxes{i}.ValueChangedFcn = @(~,~) setSplitInput(app, micIdx, checkboxes{micIdx}.Value);
            end
            
            % Buttons
            okBtn = uibutton(mainPanel, 'push');
            okBtn.Text = 'OK';
            okBtn.FontName = app.AppFontName;
            okBtn.FontSize = 12;
            okBtn.FontWeight = 'bold';
            okBtn.BackgroundColor = colors.Success;
            okBtn.FontColor = [1 1 1];
            okBtn.Position = [120 30 100 35];
            okBtn.ButtonPushedFcn = @(~,~) closeSplitDialog(app, dialogFig);
            
            cancelBtn = uibutton(mainPanel, 'push');
            cancelBtn.Text = 'Cancel';
            cancelBtn.FontName = app.AppFontName;
            cancelBtn.FontSize = 12;
            cancelBtn.FontWeight = 'bold';
            cancelBtn.BackgroundColor = colors.Danger;
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
            savePreferences(app);
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
                    ax.FontName = app.AppFontName;
                    applyAxesTheme(app, ax);
                    
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
            % Disable button immediately to show responsiveness
            app.StopButton.Enable = 'off';
            drawnow; % Allow UI to update immediately
            stopVisualization(app);
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
