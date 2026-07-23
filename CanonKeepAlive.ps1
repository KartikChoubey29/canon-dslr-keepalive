# Canon DSLR Live View Auto-Start & Keep-Alive Automation (100% Background Process)
# Loads Virtual Webcam logic directly into PowerShell and starts the live view feed.
# NO GUI application is opened.

param (
    [int]$IntervalMinutes = 2
)

$LogFile = Join-Path -Path $PSScriptRoot -ChildPath "keep_alive.log"

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

Write-Log "=== Canon Headless Virtual Webcam & Keep-Alive Service Started ==="
Write-Log "Monitoring for Canon USB Connection..."

$global:vm = $null

while ($true) {
    $isUsbConnected = Test-CanonUsbConnected

    if ($isUsbConnected) {
        if ($null -eq $global:vm) {
            Write-Log "Canon USB connected! Initializing background Virtual Webcam feed..."
            
            # Kill orphaned CLI processes
            Stop-Process -Name "CameraControlCmd", "CameraControlRemoteCmd" -Force -ErrorAction SilentlyContinue

            # Ensure DSLRCam GUI isn't running so we don't conflict
            Stop-Process -Name "DSLRCam" -Force -ErrorAction SilentlyContinue

            $appDir = "C:\Program Files (x86)\digiCamControl Virtual Webcam"
            if (Test-Path $appDir) {
                try {
                    # Crucial: Set Working Directory to Virtual Webcam folder so vcam.dll driver is found!
                    [System.IO.Directory]::SetCurrentDirectory($appDir)
                    Set-Location $appDir
                    Write-Log "Working directory set to $appDir"

                    Add-Type -Path (Join-Path $appDir "Canon.Eos.Framework.dll") -ErrorAction SilentlyContinue
                    Add-Type -Path (Join-Path $appDir "CameraControl.Devices.dll") -ErrorAction SilentlyContinue

                    $asm = [System.Reflection.Assembly]::LoadFrom((Join-Path $appDir "DSLRCam.exe"))
                    $vmType = $asm.GetType("DSLRCam.ViewModel.MainViewModel")

                    Write-Log "Instantiating MainViewModel directly in background process..."
                    $global:vm = [System.Activator]::CreateInstance($vmType)

                    Write-Log "Connecting to Canon DSLR..."
                    $global:vm.DeviceManager.ConnectToCamera() | Out-Null
                    Start-Sleep -Seconds 3

                    if ($global:vm.CameraDevice) {
                        Write-Log "SUCCESS: Connected to $($global:vm.CameraDevice.DisplayName)!"
                        Write-Log "Invoking StartLiveView() directly in background..."
                        $global:vm.StartLiveView()
                        Write-Log "SUCCESS: Virtual Webcam feed is now active!"
                    } else {
                        Write-Log "Camera not connected to DeviceManager yet."
                        $global:vm = $null
                    }
                } catch {
                    Write-Log "ERROR initializing MainViewModel in background: $_"
                    $global:vm = $null
                }
            } else {
                Write-Log "Virtual Webcam directory not found: $appDir"
            }
        } else {
            # Already running, just send a heartbeat log
            Write-Log "Virtual webcam is actively running in the background. Next check in $IntervalMinutes minute(s)..."
        }
        
        Start-Sleep -Seconds ($IntervalMinutes * 60)
    } else {
        if ($null -ne $global:vm) {
            Write-Log "Camera disconnected. Stopping background feed."
            try { $global:vm.StopLiveView() } catch {}
            $global:vm = $null
        }
        Start-Sleep -Seconds 5
    }
}
