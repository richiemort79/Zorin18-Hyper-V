# =====================================================
# Hyper-V Zorin 18 Pro Setup Script (Surface Laptop 7)
# Enhanced for Linux guests with Xorg
# =====================================================
# Run as Administrator

[CmdletBinding()]
param()

# VM Configuration
$vmName      = "Zorin18Pro"
$vmPath      = "C:\HyperV\Zorin18Pro"
$vhdPath     = "$vmPath\Zorin18Pro.vhdx"
$isoPath     = "C:\ISOs\Zorin-OS-18-Pro.iso"
$memory      = 16GB
$cpuCount    = 6
$diskSizeGB  = 150

# IMPORTANT: Change this to "External Virtual Switch" for internet access
# Or change to match the name of your external switch
$vswitchName = "Default Switch"

# Native Surface Laptop 7 resolution
$horizontalRes = 2496
$verticalRes   = 1664

Write-Host "=================================" -ForegroundColor Cyan
Write-Host "Zorin 18 Pro Hyper-V VM Setup" -ForegroundColor Cyan
Write-Host "Surface Laptop 7 Optimized" -ForegroundColor Cyan
Write-Host "=================================" -ForegroundColor Cyan
Write-Host ""

# Check if running as Administrator
$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "ERROR: This script must be run as Administrator!" -ForegroundColor Red
    exit 1
}

# Verify ISO exists
if (-not (Test-Path $isoPath)) {
    Write-Host "ERROR: ISO file not found at $isoPath" -ForegroundColor Red
    Write-Host "Please update the isoPath variable or place the ISO at the specified location." -ForegroundColor Yellow
    exit 1
}

# List available virtual switches
Write-Host "Available Virtual Switches:" -ForegroundColor Cyan
$switches = Get-VMSwitch
if ($switches.Count -gt 0) {
    foreach ($switch in $switches) {
        $type = $switch.SwitchType
        $marker = ""
        if ($switch.Name -eq $vswitchName) {
            $marker = " <- SELECTED"
        }
        Write-Host "  - $($switch.Name) [$type]$marker" -ForegroundColor White
    }
}
else {
    Write-Host "  No virtual switches found!" -ForegroundColor Red
    Write-Host "  You need to create a virtual switch in Hyper-V Manager first." -ForegroundColor Yellow
    exit 1
}

Write-Host ""

# Enable hibernation (needed for safe lid-close behavior)
Write-Host "[1/8] Enabling hibernation for safe VM suspend..." -ForegroundColor Yellow
powercfg -h on

# Ensure VM folder exists
Write-Host "[2/8] Creating VM directory structure..." -ForegroundColor Yellow
New-Item -ItemType Directory -Path $vmPath -Force | Out-Null

# Check if VM exists
$existingVM = Get-VM -Name $vmName -ErrorAction SilentlyContinue

if (-not $existingVM) {
    Write-Host "[3/8] Creating new VM: $vmName" -ForegroundColor Yellow
    
    # Check if VHDX already exists (leftover from deleted VM)
    if (Test-Path $vhdPath) {
        Write-Host "    WARNING: VHDX file already exists at $vhdPath" -ForegroundColor Yellow
        $response = Read-Host "    Delete existing VHDX and create new VM? (y/n)"
        if ($response -eq 'y') {
            Write-Host "    Deleting existing VHDX..." -ForegroundColor Yellow
            Remove-Item $vhdPath -Force
        }
        else {
            Write-Host "    Attaching existing VHDX to new VM..." -ForegroundColor Yellow
            New-VM `
                -Name $vmName `
                -Generation 2 `
                -MemoryStartupBytes $memory `
                -VHDPath $vhdPath `
                -Path $vmPath `
                -SwitchName $vswitchName
            Write-Host "    VM created with existing disk" -ForegroundColor Green
        }
    }
    
    # Create VM with new VHDX if we deleted the old one or it didn't exist
    if (-not (Test-Path $vhdPath)) {
        $diskSizeBytes = $diskSizeGB * 1GB
        
        New-VM `
            -Name $vmName `
            -Generation 2 `
            -MemoryStartupBytes $memory `
            -NewVHDPath $vhdPath `
            -NewVHDSizeBytes $diskSizeBytes `
            -Path $vmPath `
            -SwitchName $vswitchName
        
        Write-Host "    VM created successfully" -ForegroundColor Green
    }
}
else {
    Write-Host "[3/8] VM already exists, updating configuration..." -ForegroundColor Yellow
}

# Configure CPU (applies to new or existing VM)
Write-Host "[4/8] Configuring CPU ($cpuCount cores, 90% cap)..." -ForegroundColor Yellow
Set-VMProcessor -VMName $vmName -Count $cpuCount -Maximum 90 -EnableHostResourceProtection $true

# Disable Dynamic Memory (important for Linux + graphics stability)
Write-Host "[5/8] Configuring memory (static $($memory/1GB)GB)..." -ForegroundColor Yellow
Set-VMMemory -VMName $vmName -DynamicMemoryEnabled $false -StartupBytes $memory

# Configure video resolution
Write-Host "[6/8] Setting display resolution (${horizontalRes}x${verticalRes})..." -ForegroundColor Yellow
Set-VMVideo -VMName $vmName `
    -HorizontalResolution $horizontalRes `
    -VerticalResolution $verticalRes `
    -ResolutionType Single

# Disable checkpoints to save disk space (optional - comment out if you want checkpoints)
Write-Host "[7/8] Configuring VM settings..." -ForegroundColor Yellow
Set-VM -VMName $vmName -CheckpointType Disabled

# Configure automatic start/stop behavior for sleep/hibernate safety
Set-VM -VMName $vmName `
    -AutomaticStartAction StartIfRunning `
    -AutomaticStopAction Save `
    -AutomaticStartDelay 0

# Disable Secure Boot (needed for Zorin ISO to boot)
Write-Host "    Disabling Secure Boot for Linux compatibility..." -ForegroundColor Yellow
Set-VMFirmware -VMName $vmName -EnableSecureBoot Off

# Enable Enhanced Session Mode (for better clipboard/resolution integration)
Set-VMHost -EnableEnhancedSessionMode $true
Set-VM -VMName $vmName -EnhancedSessionTransportType HvSocket

# Configure Integration Services
Enable-VMIntegrationService -VMName $vmName -Name "Guest Service Interface"
Enable-VMIntegrationService -VMName $vmName -Name "Heartbeat"
Enable-VMIntegrationService -VMName $vmName -Name "Key-Value Pair Exchange"
Enable-VMIntegrationService -VMName $vmName -Name "Shutdown"
Enable-VMIntegrationService -VMName $vmName -Name "Time Synchronization"
Enable-VMIntegrationService -VMName $vmName -Name "VSS"

# Add/configure DVD drive for installation
$dvd = Get-VMDvdDrive -VMName $vmName
if (-not $dvd) {
    Write-Host "    Adding DVD drive with ISO..." -ForegroundColor Yellow
    Add-VMDvdDrive -VMName $vmName -Path $isoPath
    $dvd = Get-VMDvdDrive -VMName $vmName
}
else {
    Write-Host "    Mounting ISO to existing DVD drive..." -ForegroundColor Yellow
    Set-VMDvdDrive -VMName $vmName -Path $isoPath
}

# Set boot order (DVD first for installation)
Write-Host "[8/8] Setting boot order (DVD first)..." -ForegroundColor Yellow
Set-VMFirmware -VMName $vmName -FirstBootDevice $dvd

Write-Host ""
Write-Host "=================================" -ForegroundColor Green
Write-Host "Setup Complete!" -ForegroundColor Green
Write-Host "=================================" -ForegroundColor Green
Write-Host ""
Write-Host "VM Configuration Summary:" -ForegroundColor Cyan
Write-Host "  Name:       $vmName" -ForegroundColor White
Write-Host "  Memory:     $($memory/1GB) GB (Static)" -ForegroundColor White
Write-Host "  CPUs:       $cpuCount cores" -ForegroundColor White
Write-Host "  Disk:       $diskSizeGB GB" -ForegroundColor White
Write-Host "  Resolution: ${horizontalRes}x${verticalRes}" -ForegroundColor White
Write-Host "  Network:    $vswitchName" -ForegroundColor White
Write-Host "  SecureBoot: Disabled" -ForegroundColor White
Write-Host ""

# Check if using internal/default switch and warn
$currentSwitch = Get-VMSwitch -Name $vswitchName -ErrorAction SilentlyContinue
if ($currentSwitch) {
    if ($currentSwitch.SwitchType -eq "Internal") {
        Write-Host "WARNING: Using Internal switch - VM will NOT have internet access!" -ForegroundColor Yellow
        Write-Host "To fix: Run .\change_vm_network.ps1 and select an External switch" -ForegroundColor Yellow
        Write-Host ""
    }
}

Write-Host "Next Steps:" -ForegroundColor Yellow
Write-Host "  1. Start the VM from Hyper-V Manager" -ForegroundColor White
Write-Host "  2. Install Zorin OS (choose 'Zorin' session with Xorg, not Wayland)" -ForegroundColor White
Write-Host "  3. After installation, run the post-install script in the VM" -ForegroundColor White
Write-Host "  4. Remove the ISO after installation:" -ForegroundColor White
Write-Host "     Set-VMDvdDrive -VMName $vmName -Path `$null" -ForegroundColor Gray
Write-Host ""
