# Canon DSLR Live View & Keep-Alive Service using digiCamControl Standalone DLL
# Uses CameraControl.Devices.dll (https://www.digicamcontrol.com/doc/development/lib)
# 100% Standalone. No GUI desktop apps required.

param (
    [int]$IntervalMinutes = 2,
    [string]$DllPath = "C:\Program Files (x86)\digiCamControl\CameraControl.Devices.dll",
    [string]$FrameworkDllPath = "C:\Program Files (x86)\digiCamControl\Canon.Eos.Framework.dll"
)

$LogFile = Join-Path -Path $PSScriptRoot -ChildPath "keep_alive.log"

function Write-Log {
    param ([string]$Message)
    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $LogMessage = "[$Timestamp] $Message"
    Write-Host $LogMessage
    Add-Content -Path $LogFile -Value $LogMessage -ErrorAction SilentlyContinue
}

Write-Log "=== Canon Standalone DLL Keep-Alive Started (Interval: $IntervalMinutes Min) ==="

try {
    Write-Log "Loading digiCamControl Standalone Library ($DllPath)..."
    Add-Type -Path $FrameworkDllPath -ErrorAction SilentlyContinue
    Add-Type -Path $DllPath
    
    $dm = New-Object CameraControl.Devices.CameraDeviceManager("")
    Write-Log "Connecting to Canon DSLR via CameraControl.Devices API..."
    $null = $dm.ConnectToCamera()
    Start-Sleep -Seconds 3
    
    if ($dm.SelectedCameraDevice) {
        Write-Log "SUCCESS: Connected to $($dm.SelectedCameraDevice.DisplayName)!"
        Write-Log "Triggering StartLiveView() via digiCamControl Library..."
        $null = $dm.SelectedCameraDevice.StartLiveView()
        Write-Log "SUCCESS: Live View stream initialized!"
    } else {
        Write-Log "Waiting for Canon camera connection..."
    }
} catch {
    Write-Log "Error loading digiCamControl DLL: $_"
}

while ($true) {
    if ($dm.SelectedCameraDevice) {
        try {
            Write-Log "Sending Live View heartbeat to $($dm.SelectedCameraDevice.DisplayName)..."
            $null = $dm.SelectedCameraDevice.GetLiveViewImage()
            Write-Log "SUCCESS [DLL]: Live View heartbeat sent."
        } catch {
            Write-Log "Refreshing camera connection..."
            try { $null = $dm.SelectedCameraDevice.StartLiveView() } catch {}
        }
        Write-Log "Next heartbeat in $IntervalMinutes minute(s)..."
        Start-Sleep -Seconds ($IntervalMinutes * 60)
    } else {
        try { $null = $dm.ConnectToCamera() } catch {}
        Start-Sleep -Seconds 5
    }
}
