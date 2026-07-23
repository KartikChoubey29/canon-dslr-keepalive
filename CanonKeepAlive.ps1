# Canon DSLR Keep-Alive & Direct Live-View Engine
# Loads DSLRCam.exe into PowerShell and calls MainViewModel.StartLiveView() directly in background.
# Sets working directory to Virtual Webcam folder to resolve vcam.dll driver dependency.

param (
    [int]$IntervalMinutes = 2,  # Defaulted to 2 minutes for debugging
    [string]$DslrCamPath = "C:\Program Files (x86)\digiCamControl Virtual Webcam\DSLRCam.exe"
)

$LogFile = Join-Path -Path $PSScriptRoot -ChildPath "keep_alive.log"
$global:vm = $null

function Write-Log {
    param ([string]$Message)
    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $LogMessage = "[$Timestamp] $Message"
    Write-Host $LogMessage
    Add-Content -Path $LogFile -Value $LogMessage -ErrorAction SilentlyContinue
}

function Test-CanonUsbConnected {
    $devices = Get-PnpDevice -Class "WPD", "Camera", "Image" -Status "OK" -ErrorAction SilentlyContinue | 
               Where-Object { $_.InstanceId -like "*VID_04A9*" -or $_.FriendlyName -like "*Canon*" }
    return ($null -ne $devices)
}

function Initialize-DirectLiveView {
    if (Test-Path $DslrCamPath) {
        try {
            # Set working directory to Virtual Webcam folder so vcam.dll driver is found
            $appDir = "C:\Program Files (x86)\digiCamControl Virtual Webcam"
            [System.IO.Directory]::SetCurrentDirectory($appDir)
            Set-Location $appDir

            Write-Log "Set Working Directory to $appDir"
            Write-Log "Loading Virtual Webcam assembly ($DslrCamPath)..."
            
            Add-Type -Path (Join-Path $appDir "Canon.Eos.Framework.dll") -ErrorAction SilentlyContinue
            Add-Type -Path (Join-Path $appDir "CameraControl.Devices.dll") -ErrorAction SilentlyContinue

            $asm = [System.Reflection.Assembly]::LoadFrom($DslrCamPath)
            $vmType = $asm.GetType("DSLRCam.ViewModel.MainViewModel")

            Write-Log "Instantiating MainViewModel directly in background process..."
            $global:vm = [System.Activator]::CreateInstance($vmType)

            Write-Log "Connecting to Canon DSLR via DeviceManager..."
            $null = $global:vm.DeviceManager.ConnectToCamera()
            Start-Sleep -Seconds 3

            if ($global:vm.CameraDevice) {
                Write-Log "SUCCESS: Connected to $($global:vm.CameraDevice.DisplayName)!"
                Write-Log "Invoking vm.StartLiveView() directly in background..."
                $global:vm.StartLiveView()
                Write-Log "SUCCESS: Live View mode and frame thread initialized!"
                return $true
            } else {
                Write-Log "Camera not connected to DeviceManager yet."
            }
        } catch {
            Write-Log "ERROR initializing MainViewModel: $_"
        }
    } else {
        Write-Log "ERROR: DSLRCam.exe not found at $DslrCamPath"
    }
    return $false
}

Write-Log "=== Canon Direct MainViewModel Keep-Alive Started (Headless Mode) ==="
Write-Log "Monitoring for Canon USB Connection..."

while ($true) {
    $isUsbConnected = Test-CanonUsbConnected

    if ($isUsbConnected) {
        if ($null -eq $global:vm -or $null -eq $global:vm.CameraDevice) {
            $null = Initialize-DirectLiveView
        } else {
            try {
                Write-Log "Sending Live View heartbeat to $($global:vm.CameraDevice.DisplayName)..."
                $global:vm.GetLiveView()
                Write-Log "SUCCESS [Direct VM]: Live View heartbeat sent."
            } catch {
                Write-Log "Refreshing Live View stream..."
                try { $global:vm.StartLiveView() } catch {}
            }
        }

        Write-Log "Next heartbeat in $IntervalMinutes minute(s)..."
        Start-Sleep -Seconds ($IntervalMinutes * 60)
    } else {
        $global:vm = $null
        Start-Sleep -Seconds 5
    }
}
