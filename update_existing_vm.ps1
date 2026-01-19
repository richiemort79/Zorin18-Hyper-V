# =====================================================
# Update Existing Zorin VM Configuration
# For VMs that are already created - just updates settings
# =====================================================
# Run as Administrator

$vmName = "Zorin18Pro"

Write-Host "=================================" -ForegroundColor Cyan
Write-Host "Updating Zorin VM Configuration" -ForegroundColor Cyan
Write-Host "=================================" -ForegroundColor Cyan
Write-Host ""

# Check if running as Administrator
$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "ERROR: This script must be run as Administrator!" -ForegroundColor Red
    exit 1
}

# Check if VM exists
$vm = Get-VM -Name $vmName -ErrorAction SilentlyContinue
if (-not $vm) {
    Write-Host "ERROR: VM '$vmName' not found!" -ForegroundColor Red
    Write-Host "Please create the VM first or check the VM name." -ForegroundColor Yellow
    exit 1
}

Write-Host "Found VM: $vmName" -ForegroundColor Green
Write-Host ""

# Update CPU settings
Write-Host "[1/6] Configuring CPU (6 cores, 90% cap)..." -ForegroundColor Yellow
Set-VMProcessor -VMName $vmName -Count 6 -Maximum 90 -EnableHostResourceProtection $true

# Set static memory
Write-Host "[2/6] Configuring memory (static 16GB)..." -ForegroundColor Yellow
Set-VMMemory -VMName $vmName -DynamicMemoryEnabled $false -StartupBytes 16GB

# Set display resolution
Write-Host "[3/6] Setting display resolution (2496x1664)..." -ForegroundColor Yellow
Set-VMVideo -VMName $vmName -HorizontalResolution 2496 -VerticalResolution 1664 -ResolutionType Single

# Configure automatic start/stop behavior
Write-Host "[4/6] Configuring power management..." -ForegroundColor Yellow
Set-VM -VMName $vmName `
    -AutomaticStartAction StartIfRunning `
    -AutomaticStopAction Save `
    -AutomaticStartDelay 0

# Disable checkpoints (optional)
Write-Host "[5/6] Disabling checkpoints..." -ForegroundColor Yellow
Set-VM -VMName $vmName -CheckpointType Disabled

# Enable Enhanced Session Mode and Integration Services
Write-Host "[6/6] Configuring integration services..." -ForegroundColor Yellow
Set-VMHost -EnableEnhancedSessionMode $true
Set-VM -VMName $vmName -EnhancedSessionTransportType HvSocket

Enable-VMIntegrationService -VMName $vmName -Name "Guest Service Interface"
Enable-VMIntegrationService -VMName $vmName -Name "Heartbeat"
Enable-VMIntegrationService -VMName $vmName -Name "Key-Value Pair Exchange"
Enable-VMIntegrationService -VMName $vmName -Name "Shutdown"
Enable-VMIntegrationService -VMName $vmName -Name "Time Synchronization"
Enable-VMIntegrationService -VMName $vmName -Name "VSS"

Write-Host ""
Write-Host "=================================" -ForegroundColor Green
Write-Host "Configuration Updated!" -ForegroundColor Green
Write-Host "=================================" -ForegroundColor Green
Write-Host ""
Write-Host "Current VM Settings:" -ForegroundColor Cyan

$vm = Get-VM -Name $vmName
$vmProcessor = Get-VMProcessor -VMName $vmName
$vmMemory = Get-VMMemory -VMName $vmName
$vmVideo = Get-VMVideo -VMName $vmName

Write-Host "  State:      $($vm.State)" -ForegroundColor White
Write-Host "  CPUs:       $($vmProcessor.Count) cores" -ForegroundColor White
Write-Host "  Memory:     $($vmMemory.Startup / 1GB) GB $(if ($vmMemory.DynamicMemoryEnabled) { '(Dynamic)' } else { '(Static)' })" -ForegroundColor White
Write-Host "  Resolution: $($vmVideo.HorizontalResolution)x$($vmVideo.VerticalResolution)" -ForegroundColor White
Write-Host ""

if ($vm.State -eq "Running") {
    Write-Host "NOTE: VM is currently running. Some changes may require a restart." -ForegroundColor Yellow
    Write-Host ""
}

Write-Host "Next Steps:" -ForegroundColor Yellow
Write-Host "  1. Start/Restart the VM if needed" -ForegroundColor White
Write-Host "  2. Run the post-install script inside the VM" -ForegroundColor White
Write-Host ""
