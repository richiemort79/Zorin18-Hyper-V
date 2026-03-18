# Zorin OS 18 Pro on Hyper-V (Surface Laptop 7)

Automated setup scripts for running Zorin OS 18 Pro in Hyper-V on Surface Laptop 7 with native resolution, proper integration, and dual network profile support.

## Features

- ✅ Native Surface Laptop 7 resolution (2496x1664) and 4K external monitor (3840x2160)
- ✅ Easy resolution switching between Surface and 4K displays
- ✅ Hyper-V integration services
- ✅ Display driver fix (Ubuntu 24.04 hyperv_fb conflict)
- ✅ VM hang prevention (disables problematic suspend)
- ✅ DNS fix for Google WiFi (systemd-resolved → nscd)
- ✅ Dual network profiles (Home & Eduroam with easy switching)
- ✅ Mouse lag fix (disabled acceleration)
- ✅ Maestral (Dropbox) GUI client
- ✅ Minimal approach - no unnecessary complexity
- ✅ Tested on Surface Laptop 7 (Intel Core Ultra, 32GB RAM)

## Quick Start

### 1. On Windows Host (PowerShell as Administrator)

```powershell
.\setup_zorin_hyperv_clean.ps1
```

This will:
- Prompt for VM name (or use default "Zorin18Pro")
- Check for existing VM and warn before overwriting
- Create Gen 2 VM with optimal settings
- Configure maximum resolution to 4K (3840x2160) - supports both Surface and external monitors
- Set up External Virtual Switch for networking
- Disable Secure Boot (required for Zorin ISO)

**Important:** Edit `$vswitchName` in the script to match your network switch name (see [NETWORK_SETUP_GUIDE.md](NETWORK_SETUP_GUIDE.md))

### 2. Install Zorin OS

1. Boot the VM (it will auto-boot from ISO)
2. Install Zorin OS 18 Pro normally
3. **Choose Xorg session** (Wayland not supported in Hyper-V)
4. Reboot after installation

### 3. Inside Zorin (Guest OS)

```bash
chmod +x zorin_minimal_setup.sh
./zorin_minimal_setup.sh
```

This installs:
- Hyper-V integration tools
- **Display driver fix** (blacklists hyperv_fb to prevent corruption)
- Resolution configuration (2496x1664)
- DNS fix (systemd-resolved → nscd)
- **Network switching profiles** (Home & Eduroam)
- Mouse performance fixes
- Maestral (Dropbox client)
- Disables VM suspend to prevent hangs

The script is **idempotent** - safe to run multiple times, skips already-configured parts.

## Network Switching (Home vs University)

The setup creates two network profiles for different locations:

### At Home (Google WiFi):
```bash
net-home
```
Uses Google DNS (8.8.8.8) - compatible with Google WiFi

### At University (Eduroam):
```bash
net-edu
```
Uses Lancaster University DNS (148.88.65.52, 148.88.65.53)

### Three Ways to Switch:

1. **Desktop Shortcuts** (GUI):
   - Search: "Switch to Home Network"
   - Search: "Switch to Eduroam Network"

2. **Terminal Aliases** (Quick):
   ```bash
   net-home     # Switch to home
   net-edu      # Switch to eduroam
   net-status   # Show current DNS
   ```

3. **Direct Script**:
   ```bash
   ~/.switch-network.sh home
   ~/.switch-network.sh eduroam
   ```

**Note:** You may need to ensure the VM is connected to the correct Hyper-V External Virtual Switch that matches your current location.

## Resolution Switching (Surface vs External Monitor)

The setup supports switching between Surface native and external 4K monitor resolutions:

### Surface Laptop 7 Native (2496x1664):
```bash
res-surface
```

### External 4K Monitor (3840x2160):
```bash
res-4k
```

### Three Ways to Switch Resolutions:

1. **Desktop Shortcuts** (GUI):
   - Search: "Switch to Surface Resolution"
   - Search: "Switch to 4K Resolution"

2. **Terminal Aliases** (Quick):
   ```bash
   res-surface  # Surface native (2496x1664)
   res-4k       # 4K external (3840x2160)
   res-status   # Show current resolution
   ```

3. **Direct Script**:
   ```bash
   ~/.switch-resolution.sh surface
   ~/.switch-resolution.sh 4k
   ```

Your chosen resolution persists across reboots.

## Configuration

### VM Settings (PowerShell script):
- **Memory**: 16GB (recommended - higher values may cause stability issues)
- **CPUs**: 6 cores (adjust `$cpuCount`)
- **Disk**: 150GB (adjust `$diskSizeGB`)
- **Network**: External Virtual Switch (edit `$vswitchName`)

**Note**: While Surface Laptop 7 has more RAM, keeping VM at 16GB provides best stability. Higher allocations may cause issues.

### Resolution:
Set in PowerShell script (`$horizontalRes`, `$verticalRes`). Persistence handled by guest script via autostart.

## Known Issues

1. **Wayland not supported** - Must use Xorg session
2. **Guest suspend causes hangs** - Use Hyper-V Save State instead
3. **Ubuntu 24.04 display driver conflict** - Fixed by blacklisting hyperv_fb driver (script does this automatically)
4. **Camera/Microphone not supported** - Hyper-V Enhanced Session doesn't work well with Linux guests
5. **DNS conflicts with Google WiFi** - Fixed by using nscd instead of systemd-resolved

## Troubleshooting

### Display Corruption / Graphical Glitches in Xorg

**Symptoms**: Horizontal lines, screen corruption, distorted display (but Hyper-V thumbnail looks fine)

**Cause**: Ubuntu 24.04/Zorin 18 loads both `hyperv_fb` (old) and `hyperv_drm` (new) drivers which conflict

**Fix**: The script automatically blacklists `hyperv_fb`. If you installed before this fix:

```bash
echo "blacklist hyperv_fb" | sudo tee /etc/modprobe.d/blacklist-hyperv-fb.conf
sudo update-initramfs -u
sudo reboot
```

### Mouse Lag/Slowdown

The script automatically disables pointer acceleration. If you still experience lag:

```bash
~/.config/mouse-fix.sh
```

### Resolution Not Correct

```bash
~/.xrandr_setup.sh
```

### Maestral Qt Error

Install missing dependencies:
```bash
sudo apt install -y libxcb-cursor0 libxcb-xinerama0 libxcb-icccm4 libxcb-image0 libxcb-keysyms1 libxcb-randr0 libxcb-render-util0 libxcb-shape0
```

### DNS Not Working

Check which profile you're using:
```bash
net-status
```

Switch to appropriate profile for your location (home vs university).

If still not working:
```bash
# Check DNS is resolving
ping -c 4 8.8.8.8
ping -c 4 google.com

# Check nscd status
sudo systemctl status nscd

# Restart nscd
sudo systemctl restart nscd
```

### Network Not Working at University

Make sure:
1. Windows host is connected to eduroam
2. VM network adapter is set to **External Virtual Switch** (not Default Switch)
3. You're using the eduroam profile: `net-edu`

Check adapter in PowerShell:
```powershell
Get-VMNetworkAdapter -VMName "Zorin18Pro" | Select-Object SwitchName
```

Should show "External Virtual Switch" or your external switch name.

## Files Included

- `setup_zorin_hyperv_clean.ps1` - VM creation script (Windows host)
- `zorin_minimal_setup.sh` - Post-install configuration (Zorin guest)
- `README.md` - This file
- `LICENSE` - MIT License
- `NETWORK_SETUP_GUIDE.md` - Detailed network configuration guide

## Requirements

- Windows 11 with Hyper-V enabled
- Surface Laptop 7 (tested on Intel model with 32GB RAM)
- Zorin OS 18 Pro ISO (place in `C:\ISOs\`)
- Administrator access

## Technical Details

### Why systemd-resolved → nscd?

Ubuntu 24.04/Zorin 18 has a conflict between systemd-resolved and Google WiFi routers causing DNS resolution failures. The fix:
1. Disable systemd-resolved
2. Use nscd (Name Service Cache Daemon) for DNS caching
3. Static `/etc/resolv.conf` with appropriate DNS servers

### Why Two Network Profiles?

- **Home**: Google WiFi requires specific DNS setup (fixed with nscd)
- **Eduroam**: University network requires Lancaster-specific DNS servers (148.88.65.52/53)
- Switching between locations requires different DNS configurations
- Both profiles keep nscd active for caching

### Why Blacklist hyperv_fb?

Ubuntu 24.04 changed Hyper-V driver loading and now loads both:
- `hyperv_fb` - Old framebuffer driver (no dynamic resolution, causes conflicts)
- `hyperv_drm` - New DRM driver (supports mode setting)

Loading both causes display corruption. Blacklisting `hyperv_fb` forces exclusive use of the modern `hyperv_drm` driver.

## Credits

Developed and tested on Surface Laptop 7 with Zorin OS 18 Pro (Ubuntu 24.04 base).

## License

MIT License - see [LICENSE](LICENSE) file.

## Contributing

Issues and pull requests welcome! Please test on Surface Laptop 7 hardware when possible.
