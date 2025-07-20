#!/bin/bash

# Ubuntu Core + Ubuntu Frame Photo Booth Setup Script
# This script automates the setup of a photo booth kiosk using Ubuntu Core

set -e

echo "Setting up Ubuntu Core Photo Booth Kiosk..."

# Check if running on Ubuntu Core
if ! snap list | grep -q "ubuntu-core"; then
    echo "ERROR: This script is designed for Ubuntu Core"
    echo "Please install Ubuntu Core first: https://ubuntu.com/core/docs/getting-started"
    exit 1
fi

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo "ERROR: This script must be run as root (use sudo)"
    exit 1
fi

echo "Installing Ubuntu Frame..."
snap install ubuntu-frame

echo "Configuring Ubuntu Frame..."
snap set ubuntu-frame daemon.enable=true
snap set ubuntu-frame daemon.restart-condition=always
snap set ubuntu-frame daemon.restart-delay=10s

echo "Installing CUPS for printing..."
snap install cups
snap set cups interface.enable=true

echo "Connecting CUPS interfaces..."
snap connect cups:usb-control
snap connect cups:network-control

echo "Installing display utilities..."
snap install xinput-calibrator

echo "Creating configuration directory..."
mkdir -p /home/ubuntu/.photo-booth
chown ubuntu:ubuntu /home/ubuntu/.photo-booth

echo "Creating monitoring script..."
cat > /usr/local/bin/photo-booth-monitor.sh << 'EOF'
#!/bin/bash

LOG_FILE="/home/ubuntu/.photo-booth/kiosk.log"
APP_PID=$(pgrep -f "linux-photo-booth")

if [ -z "$APP_PID" ]; then
    echo "$(date): Photo booth app not running, restarting..." >> "$LOG_FILE"
    snap restart ubuntu-frame
fi

# Check disk space
DISK_USAGE=$(df / | awk 'NR==2 {print $5}' | sed 's/%//')
if [ "$DISK_USAGE" -gt 90 ]; then
    echo "$(date): Disk usage high: ${DISK_USAGE}%" >> "$LOG_FILE"
    # Clean up old photos
    find /home/ubuntu/Pictures -name "*.png" -mtime +7 -delete 2>/dev/null || true
fi
EOF

chmod +x /usr/local/bin/photo-booth-monitor.sh

echo "Setting up monitoring cron job..."
cat > /etc/cron.d/photo-booth-monitor << 'EOF'
*/5 * * * * root /usr/local/bin/photo-booth-monitor.sh
EOF

echo "Creating backup script..."
cat > /usr/local/bin/photo-booth-backup.sh << 'EOF'
#!/bin/bash

BACKUP_DIR="/home/ubuntu/backups"
DATE=$(date +%Y%m%d_%H%M%S)

mkdir -p "$BACKUP_DIR"
snap save photo-booth-config-$DATE

# Keep only last 7 backups
snap saved | grep photo-booth-config | tail -n +8 | awk '{print $1}' | xargs -r snap forget
EOF

chmod +x /usr/local/bin/photo-booth-backup.sh

echo "Setting up firewall..."
ufw --force enable
ufw allow ssh
ufw allow 631  # CUPS web interface

echo "Setting up log rotation..."
cat > /etc/logrotate.d/photo-booth << 'EOF'
/home/ubuntu/.photo-booth/*.log {
    daily
    missingok
    rotate 7
    compress
    notifempty
    create 644 ubuntu ubuntu
}
EOF

echo "Ubuntu Core Photo Booth Kiosk setup complete!"
echo ""
echo "Next steps:"
echo "1. Build and install the snap package:"
echo "   ./build-snap.sh"
echo "   scp linux-photo-booth_*.snap ubuntu@<raspberry-pi-ip>:~/"
echo "   sudo snap install --dangerous linux-photo-booth_*.snap"
echo ""
echo "2. Connect snap interfaces:"
echo "   sudo snap connect linux-photo-booth:camera"
echo "   sudo snap connect linux-photo-booth:cups-control"
echo "   sudo snap connect linux-photo-booth:desktop"
echo "   sudo snap connect linux-photo-booth:network"
echo "   sudo snap connect linux-photo-booth:network-bind"
echo "   sudo snap connect linux-photo-booth:wayland"
echo ""
echo "3. Configure Ubuntu Frame:"
echo "   sudo snap set ubuntu-frame daemon.command='linux-photo-booth'"
echo "   sudo snap restart ubuntu-frame"
echo ""
echo "4. Test the setup:"
echo "   sudo snap services ubuntu-frame"
echo "   sudo snap logs ubuntu-frame"
echo ""
echo "Troubleshooting:"
echo "- Check logs: sudo snap logs ubuntu-frame"
echo "- Check services: sudo snap services"
echo "- Restart Frame: sudo snap restart ubuntu-frame"
echo "- Test camera: v4l2-ctl --list-devices" 