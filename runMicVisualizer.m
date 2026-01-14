% WVU EcoCAR EV Challenge - Microphone Audio Visualizer Launcher
% This script launches the microphone audio visualizer application
%
% Usage: Simply run this script in MATLAB
%        >> runMicVisualizer

% Clear any existing instances
clear all;
close all;

% Check for required toolboxes (informational only)
% Note: The application uses audiorecorder which is part of core MATLAB
% Audio Toolbox is not strictly required, but may provide additional features
if license('test', 'Audio_Toolbox')
    fprintf('Audio Toolbox detected - full functionality available\n');
else
    fprintf('Note: Audio Toolbox not detected, but core functionality will work\n');
end

% Enable OpenGL hardware acceleration for smooth performance
try
    opengl('hardware');
    fprintf('OpenGL hardware acceleration enabled\n');
catch
    warning('Could not enable OpenGL hardware acceleration');
end

% Create and run the visualizer
fprintf('Launching WVU EcoCAR Microphone Visualizer...\n');
app = MicVisualizer;

% Keep the app running
fprintf('Visualizer is running. Close the window to exit.\n');

% Note: The app will clean up automatically when the window is closed
% If you need to programmatically close it, use: delete(app);
