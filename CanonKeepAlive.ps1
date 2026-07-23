# Canon DSLR Keep-Alive & Auto-Launch Script
# Auto-detects Canon camera USB connection, launches Virtual Webcam/digiCamControl, and sends keep-alive signals.

param (
    [int]$IntervalMinutes = 15,
    [string]$ServerUrl = "http://localhost:5513/?CMD=LiveViewWnd_Show",
    [string]$WebcamAppPath = "C:\Program Files (x86)\digiCamControl Virtual Webcam\DSLRCam.exe"
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
    $devices = Get-CimInstance Win32_PnPEntity -ErrorAction SilentlyContinue | 
               Where-Object { $_.DeviceID -like "*VID_04A9*" -or $_.Caption -like "*Canon*" -or $_.Description -like "*Canon*" }
    return ($null -ne $devices)
}

function Ensure-AppRunning {
    $process = Get-Process -Name "CameraControl", "DSLRCam", "CameraControlRemoteCmd" -ErrorAction SilentlyContinue
    if (-not $process) {
        if (Test-Path $WebcamAppPath) {
            Write-Log "Canon Camera USB detected! Auto-launching Virtual Webcam ($WebcamAppPath)..."
            Start-Process -FilePath $WebcamAppPath
            Start-Sleep -Seconds 5
        } else {
            Write-Log "Virtual Webcam app not found at $WebcamAppPath. Please open digiCamControl manually."
        }
    }
}

Write-Log "=== Canon USB Auto-Detector & Keep-Alive Service Started ==="
Write-Log "Monitoring for Canon USB Connection..."

while ($true) {
    $isUsbConnected = Test-CanonUsbConnected
    $processRunning = Get-Process -Name "CameraControl", "DSLRCam", "CameraControlRemoteCmd" -ErrorAction SilentlyContinue

    if ($isUsbConnected -or $processRunning) {
        # Ensure digiCamControl or Virtual Webcam is open
        Ensure-AppRunning

        try {
            $response = Invoke-WebRequest -Uri $ServerUrl -Method Get -TimeoutSec 10 -UseBasicParsing
            if ($response.StatusCode -eq 200) {
                Write-Log "SUCCESS: Sent keep-alive signal to digiCamControl."
            } else {
                Write-Log "WARNING: Received status code $($response.StatusCode)"
            }
        } catch {
            Write-Log "ERROR: Could not reach digiCamControl API ($($_.Exception.Message)). Ensure Web Server is enabled in digiCamControl Settings."
        }

        # Sleep for the configured interval before sending next keep-alive
        Start-Sleep -Seconds ($IntervalMinutes * 60)
    } else {
        # Camera not plugged in yet, check again every 10 seconds silently
        Start-Sleep -Seconds 10
    }
}
