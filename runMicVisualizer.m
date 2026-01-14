% Launch the microphone visualizer.

clear all;
close all;

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

fprintf('Launching WVU EcoCAR Microphone Visualizer...\n');
app = MicVisualizer;

fprintf('Visualizer is running. Close the window to exit.\n');

