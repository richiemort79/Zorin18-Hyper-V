# =====================================================
# Change Hyper-V VM Network Switch
# Switch between Default/External/Internal switches
# =====================================================
# Run as Administrator

param(
    [string]$VMName = "Zorin18Pro",
    [string]$SwitchName = ""
)

Write-Host "=================================" -ForegroundColor Cyan
Write-Host "Change VM Network Switch" -ForegroundColor Cyan
Write-Host "=================================" -ForegroundColor Cyan
Write-Host ""

# Check if running as Administrator
$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "ERROR: This script must be run as Administrator!" -ForegroundColor Red
    exit 1
}

# Check if VM exists
$vm = Get-VM -Name $VMName -ErrorAction SilentlyContinue
if (-not $vm) {
    Write-Host "ERROR: VM '$VMName' not found!" -ForegroundColor Red
    exit 1
}

# List available switches
Write-Host "Available Virtual Switches:" -ForegroundColor Cyan
$switches = Get-VMSwitch
if (-not $switches) {
    Write-Host "  No virtual switches found!" -ForegroundColor Red
    Write-Host "  Create a switch in Hyper-V Manager first." -ForegroundColor Yellow
    exit 1
}

$switchList = @()
$index = 1
foreach ($switch in $switches) {
    Write-Host "  [$index] $($switch.Name) - $($switch.SwitchType)" -ForegroundColor White
    if ($switch.SwitchType -eq "External") {
        Write-Host "      (Recommended for internet access)" -ForegroundColor Green
    } elseif ($switch.SwitchType -eq "Internal") {
        Write-Host "      (VM-to-Host only, no internet)" -ForegroundColor Yellow
    } elseif ($switch.Name -eq "Default Switch") {
        Write-Host "      (NAT-based internet access)" -ForegroundColor Cyan
    }
    $switchList += $switch
    $index++
}

Write-Host ""

# Get current adapter
$currentAdapter = Get-VMNetworkAdapter -VMName $VMName
Write-Host "Current Switch: $($currentAdapter.SwitchName)" -ForegroundColor Yellow
Write-Host ""

# If switch name not provided, prompt for it
if (-not $SwitchName) {
    $selection = Read-Host "Select switch number (1-$($switches.Count)) or press Enter to cancel"
    
    if ([string]::IsNullOrWhiteSpace($selection)) {
        Write-Host "Cancelled." -ForegroundColor Yellow
        exit 0
    }
    
    $selectedIndex = [int]$selection - 1
    if ($selectedIndex -lt 0 -or $selectedIndex -ge $switches.Count) {
        Write-Host "Invalid selection!" -ForegroundColor Red
        exit 1
    }
    
    $SwitchName = $switchList[$selectedIndex].Name
}

# Verify switch exists
$targetSwitch = Get-VMSwitch -Name $SwitchName -ErrorAction SilentlyContinue
if (-not $targetSwitch) {
    Write-Host "ERROR: Switch '$SwitchName' not found!" -ForegroundColor Red
    exit 1
}

# Change the switch
Write-Host "Changing network switch to: $SwitchName" -ForegroundColor Yellow

try {
    Connect-VMNetworkAdapter -VMName $VMName -SwitchName $SwitchName
    Write-Host ""
    Write-Host "✓ Network switch changed successfully!" -ForegroundColor Green
    Write-Host ""
    
    # Show new configuration
    $newAdapter = Get-VMNetworkAdapter -VMName $VMName
    Write-Host "New Configuration:" -ForegroundColor Cyan
    Write-Host "  VM Name:  $VMName" -ForegroundColor White
    Write-Host "  Switch:   $($newAdapter.SwitchName)" -ForegroundColor White
    Write-Host "  Type:     $($targetSwitch.SwitchType)" -ForegroundColor White
    Write-Host ""
    
    if ($vm.State -eq "Running") {
        Write-Host "NOTE: VM is running. You may need to restart the network inside the VM." -ForegroundColor Yellow
        Write-Host "In Zorin, run: sudo systemctl restart NetworkManager" -ForegroundColor Gray
        Write-Host ""
    }
    
} catch {
    Write-Host "ERROR: Failed to change network switch!" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    exit 1
}
