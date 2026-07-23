# Canon DSLR Keep-Alive (Pure CLI Mode - 100% Popup Free & Headless)
# Auto-detects Canon camera USB connection and sends direct USB PTP heartbeat signals via digiCamControl CLI.
# No desktop GUI windows open. No driver popup dialogs.

param (
    [int]$IntervalMinutes = 2,  # Defaulted to 2 minutes for debugging
    [string]$CmdAppPath = "C:\Program Files (x86)\digiCamControl\CameraControlCmd.exe"
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
    # Query for connected imaging/camera devices
    $devices = Get-PnpDevice -Class "WPD", "Camera", "Image" -Status "OK" -ErrorAction SilentlyContinue | 
               Where-Object { $_.InstanceId -like "*VID_04A9*" -or $_.FriendlyName -like "*Canon*" }
    return ($null -ne $devices)
}

Write-Log "=== Canon USB Pure CLI Keep-Alive Service Started (Popup-Free Mode) ==="
Write-Log "Monitoring for Canon USB Connection..."

while ($true) {
    $isUsbConnected = Test-CanonUsbConnected

    if ($isUsbConnected) {
        Write-Log "Canon DSLR USB Connected! Sending background keep-alive heartbeat..."

        if (Test-Path $CmdAppPath) {
            try {
                # Executes pure CLI command directly to Canon camera over USB without opening any GUI window or popup
                $process = Start-Process -FilePath $CmdAppPath -ArgumentList "/nop" -WindowStyle Hidden -Wait -PassThru
                Write-Log "SUCCESS [CLI]: Sent USB PTP keep-alive heartbeat to Canon DSLR."
            } catch {
                Write-Log "ERROR [CLI]: Failed to execute CLI keep-alive: $_"
            }
        } else {
            Write-Log "ERROR: digiCamControl CLI tool not found at $CmdAppPath"
        }

        Write-Log "Next heartbeat in $IntervalMinutes minute(s)..."
        Start-Sleep -Seconds ($IntervalMinutes * 60)
    } else {
        # Camera not plugged in yet, check again every 5 seconds
        Start-Sleep -Seconds 5
    }
}
