# Zorin OS 18 on Hyper-V (Surface Laptop 7)

A minimal, tested setup for running Zorin OS 18 on Hyper-V with proper resolution support and Hyper-V integration on a Surface Laptop 7.

## Features

- ✅ Native Surface Laptop 7 resolution (2496x1664)
- ✅ Hyper-V integration services
- ✅ VM hang prevention (disables problematic suspend)
- ✅ DNS fix (replaces systemd-resolved with nscd)
- ✅ Maestral (Dropbox) GUI client
- ✅ Minimal approach - no unnecessary complexity
- ✅ Tested on Surface Laptop 7 (32GB RAM)

## Quick Start

### 1. Windows Host Setup

Run as Administrator:

```powershell
# Edit the script first - change line 18 to use your external switch:
# $vswitchName = "External Virtual Switch"

.\setup_zorin_hyperv_clean.ps1
```

This creates and configures your Hyper-V VM with:
- 16GB RAM (static)
- 6 CPU cores
- 150GB disk
- 2496x1664 resolution
- Secure Boot disabled (required for Zorin)
- External network switch (for internet)

### 2. Install Zorin OS

1. Start the VM from Hyper-V Manager
2. Install Zorin OS normally
3. **Important**: Choose **Xorg** session (not Wayland) during login

### 3. Guest Setup

Inside the Zorin VM:

```bash
chmod +x zorin_minimal_setup.sh
./zorin_minimal_setup.sh
sudo reboot
```

This installs:
- Hyper-V integration tools
- **Display driver fix** (blacklists hyperv_fb to prevent corruption)
- Resolution configuration (2496x1664)
- DNS fix (systemd-resolved → nscd)
- Maestral (Dropbox client)
- Disables VM suspend to prevent hangs

## Files

### PowerShell Scripts (Windows Host)

- **`setup_zorin_hyperv_clean.ps1`** - Main VM creation script
- **`update_existing_vm.ps1`** - Update settings on existing VM
- **`change_vm_network.ps1`** - Switch VM network adapter

### Bash Scripts (Zorin Guest)

- **`zorin_minimal_setup.sh`** - Post-install configuration script

### Documentation

- **`README.md`** - This file
- **`NETWORK_SETUP_GUIDE.md`** - Detailed network configuration guide
- **`LICENSE`** - MIT License

## Important Notes

### Network Configuration

**For internet access**, you need an **External Virtual Switch**:

1. Open Hyper-V Manager
2. Virtual Switch Manager → New → External
3. Select your physical network adapter (Wi-Fi or Ethernet)
4. Name it "External Virtual Switch"

Or via PowerShell:
```powershell
New-VMSwitch -Name "External Virtual Switch" -NetAdapterName "Wi-Fi" -AllowManagementOS $true
```

Then edit line 18 in `setup_zorin_hyperv_clean.ps1`:
```powershell
$vswitchName = "External Virtual Switch"
```

### VM Suspend/Sleep

**DO NOT use guest OS suspend** - it will hang the VM after multiple sleep cycles.

Instead:
- Use **Hyper-V "Save State"** from the host
- Close laptop lid (configured to save VM state automatically)

The setup script disables guest suspend to prevent this issue.

### Resolution

The resolution is set via:
1. **Host side**: PowerShell script sets 2496x1664 via `Set-VMVideo`
2. **Guest side**: xrandr creates and applies the mode
3. **Persistence**: Auto-runs on login via `~/.xrandr_setup.sh`

If resolution ever resets:
```bash
~/.xrandr_setup.sh
```

### Maestral (Dropbox)

After setup, launch Maestral:
```bash
maestral gui
```

First run:
1. Sign in to Dropbox
2. Choose sync folder (default: ~/Dropbox)
3. Maestral runs in system tray

Enable autostart:
```bash
maestral autostart -Y
```

## Troubleshooting

### Boot Error: "Signed image's hash is not allowed"

Secure Boot is enabled. Disable it:
```powershell
Set-VMFirmware -VMName "Zorin18Pro" -EnableSecureBoot Off
```

The clean setup script does this automatically.

### No Internet in VM

Check network switch:
```powershell
# View current switch
Get-VMNetworkAdapter -VMName "Zorin18Pro"

# Change to external switch
.\change_vm_network.ps1
```

Inside VM:
```bash
# Check network
ip addr show

# Restart network
sudo systemctl restart NetworkManager
```

### Wrong Resolution

```bash
# Check current resolution
xrandr

# Re-apply resolution
~/.xrandr_setup.sh
```

### VM Hangs After Sleep

This is why we disable guest suspend. Always use:
- Hyper-V "Save State" (not guest suspend)
- Or shutdown/restart the VM

### Maestral Qt Error

Install missing dependencies:
```bash
sudo apt install -y libxcb-cursor0 libxcb-xinerama0 libxcb-icccm4 libxcb-image0 libxcb-keysyms1 libxcb-randr0 libxcb-render-util0 libxcb-shape0
```

### DNS Not Working

The script disables systemd-resolved and uses nscd. To verify:

```bash
# Check DNS is working
ping -c 4 google.com

# Check resolv.conf
cat /etc/resolv.conf

# Restart nscd if needed
sudo systemctl restart nscd
```

To change DNS servers:
```bash
# Make resolv.conf writable
sudo chattr -i /etc/resolv.conf

# Edit it
sudo nano /etc/resolv.conf

# Make it immutable again
sudo chattr +i /etc/resolv.conf

# Restart nscd
sudo systemctl restart nscd
```

### Display Corruption / Graphical Glitches in Xorg

**Symptoms**: Horizontal lines, screen corruption, distorted display (but Hyper-V thumbnail looks fine)

**Cause**: Ubuntu 24.04/Zorin 18 loads both `hyperv_fb` (old) and `hyperv_drm` (new) drivers which conflict

**Fix**: The script automatically blacklists `hyperv_fb`. If you installed before this fix:

```bash
echo "blacklist hyperv_fb" | sudo tee /etc/modprobe.d/blacklist-hyperv-fb.conf
sudo update-initramfs -u
sudo reboot
```

This forces use of only the modern `hyperv_drm` driver.

## System Requirements

- **Host**: Windows 11 with Hyper-V enabled
- **RAM**: 16GB+ recommended (VM uses 16GB)
- **Disk**: 150GB+ free space
- **CPU**: 6+ cores recommended
- **Tested on**: Surface Laptop 7 (32GB RAM, Snapdragon X Elite)

## Customization

### Change VM Resources

Edit these variables in `setup_zorin_hyperv_clean.ps1`:

```powershell
$memory      = 16GB    # Adjust RAM
$cpuCount    = 6       # Adjust CPU cores
$diskSizeGB  = 150     # Adjust disk size
```

### Change Resolution

Edit both scripts to use your desired resolution:

**PowerShell** (line 22-23):
```powershell
$horizontalRes = 2496
$verticalRes   = 1664
```

**Bash** (the cvt command automatically adjusts):
```bash
cvt 2496 1664 60
```

## Known Issues

1. **Wayland not supported** - Must use Xorg session
2. **Guest suspend causes hangs** - Use Hyper-V Save State instead
3. **Ubuntu 24.04 display driver conflict** - Fixed by blacklisting hyperv_fb driver (script does this automatically)
4. **First boot may be slow** - Hyper-V integration services loading

## Contributing

Issues and pull requests welcome! This is a minimal, tested setup but there's always room for improvement.

## Acknowledgments

- Tested on Surface Laptop 7 with Hyper-V
- Zorin OS 18 (based on Ubuntu 24.04)
- Hyper-V integration tools from Ubuntu

## License

MIT License - see LICENSE file for details

## Support

For issues:
1. Check the troubleshooting section above
2. Review `NETWORK_SETUP_GUIDE.md` for network issues
3. Open an issue on GitHub with details and error messages
