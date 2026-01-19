# Hyper-V Network Setup for Zorin VM

## Understanding Hyper-V Virtual Switches

### External Switch (RECOMMENDED for Internet)
- **What it does**: Bridges VM to your physical network adapter
- **Internet**: ✅ Yes - VM gets its own IP from your router
- **Access**: VM can access internet and local network
- **Best for**: Internet access, file sharing, updates
- **Drawback**: May briefly disconnect host network when created

### Default Switch
- **What it does**: Internal NAT-based network
- **Internet**: ✅ Usually yes - shares host connection via NAT
- **Access**: VM can access internet through host
- **Best for**: Quick setup, doesn't affect host network
- **Drawback**: Sometimes has connectivity issues, slower

### Internal Switch
- **What it does**: VM-to-host communication only
- **Internet**: ❌ No - isolated network
- **Access**: Only between host and VM
- **Best for**: Secure isolated testing
- **Drawback**: No internet access

## How to Create an External Switch

### Option 1: Using Hyper-V Manager (GUI)
1. Open **Hyper-V Manager**
2. Click your computer name in left panel
3. Click **Virtual Switch Manager** in right panel (Actions)
4. Click **New virtual network switch**
5. Select **External**
6. Click **Create Virtual Switch**
7. Give it a name (e.g., "External Switch")
8. Select your physical network adapter from dropdown
   - Usually "Wi-Fi" or "Ethernet"
9. Check **Allow management operating system to share this network adapter**
10. Click **OK**
11. Click **Yes** to warning about network disruption

### Option 2: Using PowerShell
```powershell
# List your physical network adapters
Get-NetAdapter

# Create external switch (replace "Wi-Fi" with your adapter name)
New-VMSwitch -Name "External Switch" -NetAdapterName "Wi-Fi" -AllowManagementOS $true
```

## Changing VM Network Switch

### Using the Helper Script
```powershell
.\change_vm_network.ps1
```
This will:
- Show all available switches
- Let you select the one you want
- Change the VM's network adapter

### Manual Method
```powershell
# List available switches
Get-VMSwitch

# Change VM to use external switch
Connect-VMNetworkAdapter -VMName "Zorin18Pro" -SwitchName "External Switch"
```

## Troubleshooting Internet Access in VM

### 1. Verify Network Connection
Inside Zorin VM:
```bash
# Check network interfaces
ip addr show

# Check if you have an IP address
ip addr show eth0

# Test DNS
ping -c 4 8.8.8.8

# Test internet
ping -c 4 google.com
```

### 2. Restart Network Manager
```bash
sudo systemctl restart NetworkManager
```

### 3. Check Network Settings in Zorin
1. Click **Settings** (top right menu)
2. Go to **Network**
3. Make sure **Wired** connection is enabled
4. Click the gear icon next to the connection
5. Check **IPv4** tab - should be set to **Automatic (DHCP)**

### 4. Verify Hyper-V Integration Services
```bash
# Check if Hyper-V network driver is loaded
lsmod | grep hv_netvsc

# Should show something like:
# hv_netvsc    xyz    0
```

### 5. Host-Side Check
On Windows host:
```powershell
# Verify VM network adapter is connected
Get-VMNetworkAdapter -VMName "Zorin18Pro"

# Check switch
Get-VMSwitch

# Verify network adapter state
Get-VM "Zorin18Pro" | Get-VMNetworkAdapter | Select-Object Name, SwitchName, Connected
```

## Recommended Setup for Most Users

**Best configuration for internet access:**
1. Create an **External Switch** in Hyper-V Manager
2. Connect your VM to that External Switch
3. Inside Zorin, network should auto-configure via DHCP

This gives you:
- ✅ Full internet access
- ✅ Ability to access local network resources
- ✅ VM gets its own IP address
- ✅ Best performance
