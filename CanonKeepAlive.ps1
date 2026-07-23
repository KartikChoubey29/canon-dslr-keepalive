# Canon DSLR Pure Background Keep-Alive Service (100% Headless)
# Works with Canon camera physical switch set to MOVIE MODE (🎥).
# Sends periodic USB PTP heartbeat signals directly to Canon camera without opening any GUI app windows.

param (
    [int]$IntervalMinutes = 15,
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
    $devices = Get-PnpDevice -Class "WPD", "Camera", "Image" -Status "OK" -ErrorAction SilentlyContinue | 
               Where-Object { $_.InstanceId -like "*VID_04A9*" -or $_.FriendlyName -like "*Canon*" }
    return ($null -ne $devices)
}

Write-Log "=== Canon Pure Headless Keep-Alive Started (Interval: $IntervalMinutes Min) ==="
Write-Log "Monitoring for Canon USB Connection..."

while ($true) {
    $isUsbConnected = Test-CanonUsbConnected

    if ($isUsbConnected) {
        Write-Log "Canon DSLR USB Connected! Sending background USB keep-alive heartbeat..."

        if (Test-Path $CmdAppPath) {
            try {
                # Executes pure CLI command directly to Canon camera over USB without opening any GUI window
                $process = Start-Process -FilePath $CmdAppPath -ArgumentList "/nop" -WindowStyle Hidden -Wait -PassThru
                Write-Log "SUCCESS [Pure CLI]: Sent USB PTP keep-alive heartbeat to Canon DSLR."
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
