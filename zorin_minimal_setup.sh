#!/bin/bash
# =====================================================
# Zorin 18 Minimal Post-Install
# Just the essentials - no Xorg config file mess
# =====================================================

set -e

echo "========================================"
echo "Zorin 18 Minimal Setup"
echo "========================================"
echo ""

# Update system
echo "[1/4] Updating system..."
sudo apt update && sudo apt upgrade -y

# Install Hyper-V tools
echo "[2/4] Installing Hyper-V integration tools..."
sudo apt install -y \
    linux-tools-virtual-hwe-24.04 \
    linux-cloud-tools-virtual-hwe-24.04

# Fix KVP daemon paths (common Ubuntu 24.04 issue)
if [ ! -d /usr/libexec/hypervkvpd ]; then
    sudo mkdir -p /usr/libexec/hypervkvpd/
    sudo ln -sf /usr/sbin/hv_get_dhcp_info /usr/libexec/hypervkvpd/hv_get_dhcp_info 2>/dev/null || true
    sudo ln -sf /usr/sbin/hv_get_dns_info /usr/libexec/hypervkvpd/hv_get_dns_info 2>/dev/null || true
fi

# Blacklist hyperv_fb driver (Ubuntu 24.04 bug - conflicts with hyperv_drm causing display corruption)
echo "  Blacklisting hyperv_fb driver (fixes Xorg display corruption)..."
echo "blacklist hyperv_fb" | sudo tee /etc/modprobe.d/blacklist-hyperv-fb.conf > /dev/null
sudo update-initramfs -u

# Fix mouse lag/slowdown (common Hyper-V issue)
echo "  Configuring mouse settings for better Hyper-V performance..."
mkdir -p ~/.config
cat > ~/.config/mouse-fix.sh << 'EOF'
#!/bin/bash
# Disable mouse acceleration for smoother movement
xinput set-prop pointer:'Microsoft Vmbus HID-compliant Mouse' 'libinput Accel Profile Enabled' 0, 1 2>/dev/null || true
xinput set-prop pointer:'Microsoft Vmbus HID-compliant Mouse' 'libinput Accel Speed' 0 2>/dev/null || true
EOF
chmod +x ~/.config/mouse-fix.sh

# Run on startup
mkdir -p ~/.config/autostart
cat > ~/.config/autostart/mouse-fix.desktop << 'EOF'
[Desktop Entry]
Type=Application
Name=Fix Mouse Performance
Exec=/bin/bash -c "sleep 2 && ~/.config/mouse-fix.sh"
Hidden=false
NoDisplay=false
X-GNOME-Autostart-enabled=true
EOF

# Disable VM suspend to prevent hangs
echo "[3/5] Disabling VM suspend (use Hyper-V Save State instead)..."
gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-ac-timeout 0
gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-battery-timeout 0

# Fix DNS - replace systemd-resolved with nscd
echo "[4/6] Fixing DNS (replacing systemd-resolved with nscd)..."

# Stop and disable systemd-resolved
sudo systemctl stop systemd-resolved
sudo systemctl disable systemd-resolved

# Remove symlink to systemd-resolved
sudo rm /etc/resolv.conf

# Create static resolv.conf with common DNS servers
cat << EOF | sudo tee /etc/resolv.conf > /dev/null
# Static DNS configuration
nameserver 8.8.8.8
nameserver 8.8.4.4
nameserver 1.1.1.1
EOF

# Make it immutable so nothing overwrites it
sudo chattr +i /etc/resolv.conf

# Install and enable nscd for DNS caching
sudo apt install -y nscd
sudo systemctl enable nscd
sudo systemctl start nscd

echo "✓ DNS configured with nscd caching"

# Set resolution mode
echo "[5/6] Setting display resolution (2496x1664)..."

# Generate modeline - need to get the full line with proper parsing
MODELINE_FULL=$(cvt 2496 1664 60 | grep Modeline)
MODE_NAME=$(echo "$MODELINE_FULL" | awk '{print $2}' | tr -d '"')
MODE_PARAMS=$(echo "$MODELINE_FULL" | cut -d' ' -f3-)

echo "Setting up mode: $MODE_NAME"

# Check if mode already exists
if ! xrandr | grep -q "$MODE_NAME"; then
    echo "Creating new mode..."
    xrandr --newmode "$MODE_NAME" $MODE_PARAMS
else
    echo "Mode already exists, skipping creation"
fi

# Add mode to Virtual-1 (ignore error if already added)
xrandr --addmode Virtual-1 "$MODE_NAME" 2>/dev/null || true

# Apply the mode
xrandr --output Virtual-1 --mode "$MODE_NAME"

echo "✓ Resolution set to $MODE_NAME"

# Make it persistent on login
cat > ~/.xrandr_setup.sh << 'EOF'
#!/bin/bash
MODE="2496x1664_60.00"
if ! xrandr | grep -q "$MODE"; then
    xrandr --newmode "$MODE" 352.50 2496 2688 2952 3408 1664 1667 1677 1724 -hsync +vsync 2>/dev/null || true
fi
xrandr --addmode Virtual-1 "$MODE" 2>/dev/null || true
xrandr --output Virtual-1 --mode "$MODE"
EOF
chmod +x ~/.xrandr_setup.sh

# Use autostart instead of .profile - runs after desktop loads
mkdir -p ~/.config/autostart
cat > ~/.config/autostart/xrandr-resolution.desktop << 'EOF'
[Desktop Entry]
Type=Application
Name=Set Resolution
Exec=/bin/bash -c "sleep 2 && /home/$USER/.xrandr_setup.sh"
Hidden=false
NoDisplay=false
X-GNOME-Autostart-enabled=true
EOF

echo "✓ Resolution will be set automatically on login"

# Install Maestral
echo "[6/6] Installing Maestral..."

# Install Qt dependencies needed for Maestral GUI
sudo apt install -y pipx libxcb-cursor0 libxcb-xinerama0 libxcb-icccm4 libxcb-image0 libxcb-keysyms1 libxcb-randr0 libxcb-render-util0 libxcb-shape0

pipx install 'maestral[gui]'
pipx ensurepath

echo "✓ Maestral installed via pipx"

echo ""
echo "========================================"
echo "Setup Complete!"
echo "========================================"
echo ""
echo "DNS Configuration:"
echo "  systemd-resolved disabled"
echo "  Using nscd for DNS caching"
echo "  DNS servers: 8.8.8.8, 8.8.4.4, 1.1.1.1"
echo "  /etc/resolv.conf is immutable (chattr +i)"
echo ""
echo "Resolution Setup:"
echo "  The PowerShell script already set 2496x1664 on the host."
echo "  It should just work. If not, run:"
echo "    xrandr --output Virtual-1 --auto"
echo ""
echo "To launch Maestral:"
echo "  maestral gui"
echo ""
echo "IMPORTANT - VM Sleep/Suspend:"
echo "  DO NOT use guest suspend - it will hang the VM"
echo "  Use Hyper-V 'Save State' from the host instead"
echo ""
echo "Reboot recommended: sudo reboot"
echo ""
