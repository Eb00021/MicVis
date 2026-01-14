# WVU EcoCAR EV Challenge - Microphone Audio Visualizer

A real-time microphone audio visualizer application for the WVU EcoCAR EV Challenge Team, featuring WVU branding and optimized performance.

## Features

- **Multi-Microphone Support**: Adjustable number of microphones (1-16), including 4-channel USB interfaces
- **Real-Time Visualization**: Smooth waveform and FFT displays
- **WVU Branding**: Official WVU colors (Old Gold and Blue) and Helvetica Neue font
- **High Performance**: OpenGL hardware acceleration for smooth rendering
- **User-Friendly GUI**: Intuitive controls for all settings
- **Adjustable Settings**: 
  - Number of microphones
  - Sample rate (8kHz - 192kHz)
  - Gain control
  - Display mode (Waveform, FFT, or both)

## Requirements

- MATLAB R2018b or later
- Audio Toolbox (recommended for multi-channel USB interfaces)
- Data Acquisition Toolbox (optional alternative for multi-channel interfaces)
- Audio input device(s) (microphone(s))

## Installation

1. Ensure all files are in the same directory
2. Open MATLAB and navigate to the project directory
3. Run the launcher script:
   ```matlab
   runMicVisualizer
   ```

## Usage

1. **Launch the Application**: Run `runMicVisualizer.m` in MATLAB
2. **Configure Settings**:
   - Set the number of microphones using the spinner
   - Adjust sample rate if needed (default: 44100 Hz)
   - Set gain level using the slider
   - Choose display mode (Waveform, FFT, or both)
    - For Behringer UMC404HD, set the number of microphones to 4
3. **Start Visualization**: Click the "Start" button
4. **Stop Visualization**: Click the "Stop" button when done

## Adding Logos and Icons

To add the WVU logo:
1. Place your logo image file in the project directory
2. In `MicVisualizer.m`, locate the `WVULogo` component
3. Set the `ImageSource` property to your logo file path:
   ```matlab
   app.WVULogo.ImageSource = 'path/to/your/logo.png';
   app.WVULogo.Visible = 'on';
   ```

To add a custom icon for the application window:
1. Create or obtain an `.ico` file
2. In `MicVisualizer.m`, add to the `createComponents` function:
   ```matlab
   app.UIFigure.Icon = 'path/to/your/icon.ico';
   ```

## Performance Tips

- The application uses OpenGL hardware acceleration automatically
- For best performance with multiple microphones, use a lower sample rate
- The visualization updates at 20 FPS (every 50ms) for smooth performance
- If experiencing lag, reduce the number of microphones or sample rate

## Troubleshooting

**No audio input detected:**
- Check that your microphone is connected and recognized by Windows
- Verify Audio Toolbox is installed (required for many ASIO multi-channel devices)
- Try reducing the number of microphones

**Visualization is choppy:**
- Ensure OpenGL hardware acceleration is enabled
- Reduce sample rate
- Close other applications using audio devices

**Error initializing audio:**
- Check that no other application is using the microphone
- Verify microphone permissions in Windows settings
- Try restarting MATLAB

## WVU Branding

The application uses:
- **Colors**: 
  - WVU Gold: RGB(238, 170, 0)
  - WVU Blue: RGB(0, 40, 85)
- **Font**: Helvetica Neue (or Helvetica if unavailable)

## Support

For issues or questions, contact the WVU EcoCAR EV Challenge Team.

## License

This software is developed for the WVU EcoCAR EV Challenge Team.
