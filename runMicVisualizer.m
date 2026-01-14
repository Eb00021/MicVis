% Launch the microphone visualizer.

clear all;
close all;

fprintf('Initializing WVU EcoCAR Microphone Visualizer...\n');

% Pre-warm the audio subsystem in background to avoid hang on first access
% This is necessary because Windows audio initialization can be slow on fresh MATLAB sessions
try
    fprintf('Warming up audio subsystem (this may take a moment on first run)...\n');
    drawnow;  % Ensure message is displayed
    
    % Quick non-blocking check for audio devices to initialize Windows audio
    try
        info = audiodevinfo;
        if ~isempty(info.input)
            fprintf('Found %d audio input device(s)\n', length(info.input));
        end
    catch
        % Ignore errors during warmup
    end
catch
    % Continue even if warmup fails
end

hasAudioToolbox = false;
try
    hasAudioToolbox = license('test', 'Audio_Toolbox');
catch
end
if ~hasAudioToolbox
    try
        hasAudioToolbox = ~isempty(ver('audio'));
    catch
    end
end
if ~hasAudioToolbox
    hasAudioToolbox = exist('audioDeviceReader', 'class') == 8 || exist('audioDeviceReader', 'file') == 2;
end
if hasAudioToolbox
    fprintf('Audio Toolbox detected - full functionality available\n');
else
    fprintf('Note: Audio Toolbox not detected, but core functionality will work\n');
end

try
    opengl('hardware');
    fprintf('OpenGL hardware acceleration enabled\n');
catch
    warning('Could not enable OpenGL hardware acceleration');
end

fprintf('Launching visualizer...\n');
drawnow;  % Ensure UI messages are displayed before app creation

app = MicVisualizer;

fprintf('Visualizer is running. Close the window to exit.\n');

