# Linux Photo Booth

A professional photo booth application designed for Ubuntu Core and Ubuntu Frame. Perfect for events, parties, and commercial photo booth installations.

## Overview

Linux Photo Booth is a complete photo booth solution that runs seamlessly on Ubuntu Core with Ubuntu Frame, providing a touch-optimized interface for capturing, editing, and printing photos. It's designed to work out-of-the-box on Raspberry Pi and other Ubuntu Core devices.

## Features

- **Real-time camera capture** using GStreamer
- **Multiple photo layouts** (1x1, 2x2) with customizable frames
- **Frame overlay system** with professional templates
- **Direct printing** via CUPS with automatic printer detection
- **Countdown timer** with visual feedback
- **Touch-optimized interface** for kiosk environments
- **Automatic kiosk mode** with Ubuntu Frame integration
- **Background themes** and customization options
- **Remote management** capabilities
- **Secure sandboxed** environment with Snap confinement

## Ubuntu Core + Ubuntu Frame

This application is specifically designed for Ubuntu Core, which provides:

- **Security**: Sandboxed applications with strict confinement
- **Reliability**: Automatic updates and rollback capabilities
- **Simplicity**: One-command installation and management
- **Performance**: Optimized for IoT and edge computing devices

Ubuntu Frame handles the display server and kiosk management automatically.

## Quick Start

### 1. Install Ubuntu Core

1. **Download Ubuntu Core image**
   ```bash
   wget https://cdimage.ubuntu.com/ubuntu-core/22/stable/current/ubuntu-core-22-arm64+raspi.img.xz
   xz -d ubuntu-core-22-arm64+raspi.img.xz
   ```

2. **Flash to SD card**
   ```bash
   sudo dd if=ubuntu-core-22-arm64+raspi.img of=/dev/sdb bs=4M status=progress
   ```

3. **Boot and configure**
   - Insert SD card into Raspberry Pi
   - Connect to WiFi during initial setup
   - Create Ubuntu One account if needed
   - Note the device IP address

### 2. Install Ubuntu Frame

```bash
# SSH into your Ubuntu Core device
ssh ubuntu@<device-ip>

# Install Ubuntu Frame
sudo snap install ubuntu-frame

# Configure Frame for kiosk mode
sudo snap set ubuntu-frame daemon.enable=true
sudo snap set ubuntu-frame daemon.restart-condition=always
```

### 3. Install Photo Booth

```bash
# Install from Snap Store (when published)
sudo snap install linux-photo-booth

# Or install locally built snap
sudo snap install --dangerous linux-photo-booth_*.snap

# Connect required interfaces
sudo snap connect linux-photo-booth:camera
sudo snap connect linux-photo-booth:cups-control
sudo snap connect linux-photo-booth:desktop
sudo snap connect linux-photo-booth:network
sudo snap connect linux-photo-booth:network-bind
```

### 4. Configure Ubuntu Frame

```bash
# Set photo booth as the default application
sudo snap set ubuntu-frame daemon.command="linux-photo-booth"

# Restart Frame to apply changes
sudo snap restart ubuntu-frame
```

## Development Setup

### Prerequisites

```bash
# Install snapcraft
sudo snap install snapcraft --classic

# Install Flutter
sudo snap install flutter --classic

# Install build dependencies
sudo apt update
sudo apt install -y \
  build-essential \
  git \
  curl \
  wget
```

### Build Snap Package

```bash
# Clone repository
git clone https://github.com/your-username/flutter-linux-photo-booth.git
cd flutter-linux-photo-booth

# Build snap package (for local testing)
./build-snap.sh

# For Raspberry Pi (arm64) build, use:
snapcraft --destructive-mode
```

### Test Locally

```bash
# Install snap in development mode
sudo snap install --devmode linux-photo-booth_*.snap

# Connect interfaces
sudo snap connect linux-photo-booth:camera
sudo snap connect linux-photo-booth:cups-control
sudo snap connect linux-photo-booth:desktop

# Test the application
linux-photo-booth
```

### Advanced Setup

For advanced Ubuntu Core configuration, monitoring, and troubleshooting, see the detailed guide in [ubuntu-core/install-ubuntu-core.md](ubuntu-core/install-ubuntu-core.md).

For automated setup of Ubuntu Core with all necessary services and monitoring, use the setup script:

```bash
# Run the automated setup script
sudo ./ubuntu-core/setup-ubuntu-core.sh
```

## Project Structure

```
flutter-linux-photo-booth/
├── lib/
│   ├── controllers/          # State management (GetX)
│   ├── helpers/             # Utility functions
│   ├── pages/              # UI pages
│   └── main.dart           # Application entry point
├── assets/
│   ├── images/             # Frame templates and test images
│   └── backgrounds/        # UI background images
├── snap/
│   ├── snapcraft.yaml      # Snap package configuration
│   └── desktop/           # Desktop integration files
├── ubuntu-core/
│   ├── setup-ubuntu-core.sh # Ubuntu Core setup script
│   └── install-ubuntu-core.md # Detailed installation guide
├── server.py              # Flask print server
├── requirement.txt        # Python dependencies
└── build-snap.sh         # Snap build script
```

## Configuration

### Ubuntu Frame Configuration

Ubuntu Frame automatically handles kiosk mode. To customize the behavior:

```bash
# Configure Frame settings
sudo snap set ubuntu-frame daemon.restart-condition=always
sudo snap set ubuntu-frame daemon.restart-delay=10s

# Set display environment
sudo snap set ubuntu-frame daemon.environment="DISPLAY=:0 WAYLAND_DISPLAY=wayland-0"
```

### Camera Settings

The application uses `/dev/video0` by default. To use a different camera:

1. Edit `lib/pages/takePicturePage.dart`
2. Modify the GStreamer pipeline in the `GstPlayer` widget
3. Change `device=/dev/video0` to your camera device

### Printer Configuration

The Flask server automatically detects the default printer. To configure manually:

1. Edit `server.py`
2. Modify the `get_default_printer()` function
3. Or set a specific printer name

## Printer Setup

### CUPS Installation

```bash
# Install CUPS snap
sudo snap install cups

# Enable CUPS web interface
sudo snap set cups interface.enable=true

# Connect USB printer interface
sudo snap connect cups:usb-control
```

### Printer Configuration

```bash
# List available printers
lpstat -p

# Set default printer
lpoptions -d <printer-name>

# Test print
echo "Test" | lp
```

### Web Interface

Access CUPS web interface at `http://<device-ip>:631` to configure printers.

## Monitoring and Management

### Logs

```bash
# Application logs
sudo snap logs linux-photo-booth

# Ubuntu Frame logs
sudo snap logs ubuntu-frame

# System logs
journalctl -u snap.ubuntu-frame.ubuntu-frame
```

### Status Check

```bash
# Check snap services
snap services

# Check snap connections
snap connections linux-photo-booth

# Check system resources
htop
df -h
```

### Remote Management

```bash
# SSH into device
ssh ubuntu@<device-ip>

# Restart application
sudo snap restart linux-photo-booth

# Update application
sudo snap refresh linux-photo-booth

# Check for updates
sudo snap refresh --list
```

## Security

### Snap Confinement

The application runs in strict confinement, providing:

- **Isolation**: Applications cannot access each other's data
- **Permissions**: Explicit permission grants for hardware access
- **Updates**: Automatic security updates
- **Rollback**: Automatic rollback on failures

### Interface Connections

```bash
# Required interfaces
sudo snap connect linux-photo-booth:camera      # Camera access
sudo snap connect linux-photo-booth:cups-control # Printer access
sudo snap connect linux-photo-booth:desktop     # Display access
sudo snap connect linux-photo-booth:network     # Network access
sudo snap connect linux-photo-booth:network-bind # Network binding
```

## Troubleshooting

### Common Issues

#### Camera Not Working
```bash
# Check camera permissions
snap connections linux-photo-booth

# Reconnect camera interface
sudo snap disconnect linux-photo-booth:camera
sudo snap connect linux-photo-booth:camera

# Test camera
v4l2-ctl --list-devices
```

#### Display Issues
```bash
# Check Frame service
sudo snap services ubuntu-frame

# Restart Frame
sudo snap restart ubuntu-frame

# Check display environment
echo $DISPLAY
echo $WAYLAND_DISPLAY
```

#### Printer Issues
```bash
# Check CUPS service
sudo snap services cups

# Check printer connections
snap connections cups

# Test printer
lpstat -p
echo "Test" | lp
```

### Debug Commands

```bash
# System information
uname -a
snap version

# Hardware information
lsusb
lspci

# Network information
ip addr show
ping -c 3 8.8.8.8
```

## Performance Optimization

### Memory Optimization

```bash
# Monitor memory usage
free -h

# Check snap memory usage
snap list --all
```

### Storage Optimization

```bash
# Check disk usage
df -h

# Clean old snap versions
snap set system refresh.retain=2
```

## Updates and Maintenance

### Automatic Updates

Ubuntu Core automatically updates snaps in the background.

### Manual Updates

```bash
# Check for updates
sudo snap refresh --list

# Update specific snap
sudo snap refresh linux-photo-booth

# Update all snaps
sudo snap refresh
```

### Backup and Restore

```bash
# Create backup
sudo snap save photo-booth-backup

# List backups
sudo snap saved

# Restore from backup
sudo snap restore <backup-id>
```

## Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

### Development Guidelines

- Follow Flutter best practices
- Add tests for new features
- Update documentation for API changes
- Ensure snap confinement compatibility

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Support

### Documentation
- [Ubuntu Core Documentation](https://ubuntu.com/core/docs)
- [Ubuntu Frame Documentation](https://snapcraft.io/ubuntu-frame)
- [Snapcraft Documentation](https://snapcraft.io/docs)

### Community
- [Ubuntu Forums](https://ubuntuforums.org/)
- [Snapcraft Community](https://forum.snapcraft.io/)

### Issues
- [GitHub Issues](https://github.com/your-username/flutter-linux-photo-booth/issues)

## Acknowledgments

- Ubuntu Core team for the excellent IoT platform
- Flutter team for the amazing UI framework
- GStreamer team for multimedia capabilities
- CUPS team for printing support

