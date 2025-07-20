# Ubuntu Core Advanced Installation Guide

This guide provides detailed instructions for advanced Ubuntu Core setup and configuration for the Linux Photo Booth application.

## Prerequisites

Before starting, ensure you have:
- Raspberry Pi 4 (4GB RAM minimum, 8GB recommended)
- 32GB+ MicroSD card (Class 10 recommended)
- USB camera (Logitech C920 or compatible)
- Touch screen display
- Network connection (WiFi or Ethernet)
- Ubuntu One account

## Ubuntu Core Image Preparation

### Download Ubuntu Core Image

```bash
# Download the latest Ubuntu Core 22.04 LTS image
wget https://cdimage.ubuntu.com/ubuntu-core/22/stable/current/ubuntu-core-22-arm64+raspi.img.xz

# Verify download integrity
wget https://cdimage.ubuntu.com/ubuntu-core/22/stable/current/SHA256SUMS
sha256sum -c SHA256SUMS

# Extract the image
xz -d ubuntu-core-22-arm64+raspi.img.xz
```

### Flash Image to SD Card

```bash
# Identify your SD card device
lsblk

# Flash the image (replace /dev/sdb with your SD card device)
sudo dd if=ubuntu-core-22-arm64+raspi.img of=/dev/sdb bs=4M status=progress conv=fsync

# Verify the flash
sudo dd if=/dev/sdb of=/tmp/verify.img bs=4M count=1000
diff ubuntu-core-22-arm64+raspi.img /tmp/verify.img
```

## Initial Ubuntu Core Setup

### First Boot Configuration

1. **Insert SD card into Raspberry Pi and power on**
2. **Connect to WiFi network** during initial setup
3. **Create Ubuntu One account** if you don't have one
4. **Note the device IP address** for SSH access

### SSH Access Setup

```bash
# Generate SSH key pair (on your development machine)
ssh-keygen -t ed25519 -C "your-email@example.com"

# Copy public key to Ubuntu Core device
ssh-copy-id -i ~/.ssh/id_ed25519.pub ubuntu@<device-ip>

# Test SSH connection
ssh ubuntu@<device-ip>
```

## Advanced System Configuration

### Network Configuration

```bash
# Configure static IP (optional)
sudo nano /etc/netplan/50-cloud-init.yaml

# Apply network configuration
sudo netplan apply

# Test network connectivity
ping -c 3 8.8.8.8
```

### System Updates

```bash
# Check for system updates
sudo snap refresh --list

# Update all snaps
sudo snap refresh

# Check system status
snap list
snap services
```

### Hardware Optimization

```bash
# Check hardware information
lscpu
free -h
df -h
lsusb
lspci

# Monitor system resources
htop
```

## Ubuntu Frame Advanced Configuration

### Frame Installation and Setup

```bash
# Install Ubuntu Frame
sudo snap install ubuntu-frame

# Configure Frame for optimal performance
sudo snap set ubuntu-frame daemon.enable=true
sudo snap set ubuntu-frame daemon.restart-condition=always
sudo snap set ubuntu-frame daemon.restart-delay=10s

# Set display configuration
sudo snap set ubuntu-frame daemon.environment="DISPLAY=:0 WAYLAND_DISPLAY=wayland-0"
```

### Display Configuration

```bash
# Check display information
echo $DISPLAY
echo $WAYLAND_DISPLAY

# Configure display rotation (if needed)
sudo snap set ubuntu-frame daemon.environment="DISPLAY=:0 WAYLAND_DISPLAY=wayland-0 XDG_SESSION_TYPE=wayland"

# Test display
sudo snap restart ubuntu-frame
```

### Touch Screen Calibration

```bash
# Install calibration tools
sudo snap install xinput-calibrator

# Run calibration
xinput_calibrator

# Save calibration data
sudo cp /etc/X11/xorg.conf.d/99-calibration.conf /etc/X11/xorg.conf.d/99-calibration.conf.backup
```

## CUPS Advanced Configuration

### CUPS Installation and Setup

```bash
# Install CUPS
sudo snap install cups

# Enable CUPS web interface
sudo snap set cups interface.enable=true

# Connect USB printer interface
sudo snap connect cups:usb-control
sudo snap connect cups:network-control

# Start CUPS service
sudo snap start cups
```

### Printer Configuration

```bash
# List available printers
lpstat -p

# Set default printer
lpoptions -d <printer-name>

# Configure printer settings
lpoptions -p <printer-name> -o media=4x6 -o print-quality=5

# Test printer
echo "Test print" | lp -d <printer-name>
```

### CUPS Web Interface

```bash
# Access CUPS web interface
# Open browser and navigate to: http://<device-ip>:631

# Enable remote access (if needed)
sudo snap set cups interface.enable=true
sudo snap connect cups:network-control
```

## Camera Configuration

### Camera Detection and Setup

```bash
# Check available cameras
v4l2-ctl --list-devices

# Test camera
gst-launch-1.0 v4l2src device=/dev/video0 ! videoconvert ! autovideosink

# Check camera capabilities
v4l2-ctl --device=/dev/video0 --list-formats-ext

# Set camera resolution
v4l2-ctl --device=/dev/video0 --set-fmt-video=width=1920,height=1080,pixelformat=YUYV
```

### Camera Permissions

```bash
# Check camera permissions
snap connections linux-photo-booth

# Connect camera interface
sudo snap connect linux-photo-booth:camera

# Test camera access
sudo snap run linux-photo-booth
```

## Security Configuration

### Firewall Setup

```bash
# Enable UFW firewall
sudo ufw --force enable

# Allow SSH access
sudo ufw allow ssh

# Allow CUPS web interface
sudo ufw allow 631

# Check firewall status
sudo ufw status verbose
```

### Snap Security

```bash
# Check snap confinement
snap list --all

# Review snap connections
snap connections

# Check snap permissions
snap connections linux-photo-booth
```

### System Monitoring

```bash
# Install monitoring tools
sudo snap install htop

# Monitor system resources
htop

# Check disk usage
df -h

# Monitor network
iftop
```

## Performance Optimization

### Memory Optimization

```bash
# Check memory usage
free -h

# Monitor memory usage over time
watch -n 1 free -h

# Check swap usage
swapon --show
```

### Storage Optimization

```bash
# Check disk usage
df -h

# Clean old snap versions
sudo snap set system refresh.retain=2

# Clean temporary files
sudo journalctl --vacuum-time=7d
```

### Network Optimization

```bash
# Check network performance
iperf3 -c 8.8.8.8

# Monitor network usage
iftop

# Configure network buffer sizes (if needed)
sudo sysctl -w net.core.rmem_max=26214400
sudo sysctl -w net.core.wmem_max=26214400
```

## Troubleshooting

### Common Issues and Solutions

#### Display Issues
```bash
# Check Frame service status
sudo snap services ubuntu-frame

# Restart Frame service
sudo snap restart ubuntu-frame

# Check display environment
env | grep -E "(DISPLAY|WAYLAND|XDG)"

# Reset Frame configuration
sudo snap set ubuntu-frame daemon.enable=false
sudo snap set ubuntu-frame daemon.enable=true
```

#### Camera Issues
```bash
# Check camera device
ls -la /dev/video*

# Test camera with GStreamer
gst-launch-1.0 v4l2src device=/dev/video0 ! videoconvert ! autovideosink

# Check camera permissions
sudo usermod -aG video ubuntu

# Reconnect camera interface
sudo snap disconnect linux-photo-booth:camera
sudo snap connect linux-photo-booth:camera
```

#### Printer Issues
```bash
# Check CUPS service
sudo snap services cups

# Restart CUPS service
sudo snap restart cups

# Check printer connections
snap connections cups

# Test printer communication
lpstat -p
echo "Test" | lp
```

#### Network Issues
```bash
# Check network configuration
ip addr show
ip route show

# Test network connectivity
ping -c 3 8.8.8.8
nslookup google.com

# Check DNS resolution
systemd-resolve --status
```

### Debug Commands

```bash
# System information
uname -a
cat /etc/os-release
snap version

# Hardware information
lscpu
free -h
df -h
lsusb
lspci

# Service status
systemctl status
snap services

# Log analysis
journalctl -f
sudo snap logs ubuntu-frame
sudo snap logs linux-photo-booth
```

## Backup and Recovery

### System Backup

```bash
# Create system backup
sudo snap save photo-booth-system-backup

# List available backups
sudo snap saved

# Create configuration backup
sudo tar -czf /home/ubuntu/photo-booth-config-backup.tar.gz \
    /etc/systemd/system/photo-booth-server.service \
    /usr/local/bin/photo-booth-*.sh \
    /etc/cron.d/photo-booth-monitor \
    /etc/logrotate.d/photo-booth
```

### Recovery Procedures

```bash
# Restore from snap backup
sudo snap restore <backup-id>

# Restore configuration files
sudo tar -xzf /home/ubuntu/photo-booth-config-backup.tar.gz -C /

# Restart services after recovery
sudo snap restart ubuntu-frame
sudo snap restart linux-photo-booth
```

## Maintenance

### Regular Maintenance Tasks

```bash
# Daily tasks
sudo snap refresh --list
sudo journalctl --vacuum-time=7d

# Weekly tasks
sudo snap save weekly-backup
sudo apt update && sudo apt upgrade

# Monthly tasks
sudo snap set system refresh.retain=2
sudo logrotate -f /etc/logrotate.d/photo-booth
```

### Monitoring Scripts

The setup script creates monitoring scripts that:
- Check application status every 5 minutes
- Monitor disk usage and clean old files
- Restart services if they fail
- Create automatic backups

### Log Management

```bash
# View application logs
sudo snap logs linux-photo-booth -f

# View system logs
journalctl -u snap.ubuntu-frame.ubuntu-frame -f

# Configure log rotation
sudo nano /etc/logrotate.d/photo-booth
```

## Support and Resources

### Official Documentation
- [Ubuntu Core Documentation](https://ubuntu.com/core/docs)
- [Ubuntu Frame Documentation](https://snapcraft.io/ubuntu-frame)
- [Snapcraft Documentation](https://snapcraft.io/docs)

### Community Resources
- [Ubuntu Forums](https://ubuntuforums.org/)
- [Snapcraft Community](https://forum.snapcraft.io/)
- [Raspberry Pi Forums](https://www.raspberrypi.org/forums/)

### Troubleshooting Resources
- [Ubuntu Core Troubleshooting](https://ubuntu.com/core/docs/troubleshooting)
- [Snap Troubleshooting](https://snapcraft.io/docs/troubleshooting)
- [GStreamer Documentation](https://gstreamer.freedesktop.org/documentation/)

---

This guide covers advanced configuration options for Ubuntu Core. For basic installation, refer to the main README.md file. 