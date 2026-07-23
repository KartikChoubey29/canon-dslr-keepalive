# Canon DSLR Keep-Alive & Auto-Launch Script (Silent Backend Mode)
# Auto-detects Canon camera USB connection, launches digiCamControl in hidden mode, and sends keep-alive signals.

param (
    [int]$IntervalMinutes = 2,  # Defaulted to 2 minutes for debugging
    [string]$ServerUrl = "http://localhost:5513/?CMD=LiveViewWnd_Show",
    [string]$MainAppPath = "C:\Program Files (x86)\digiCamControl\CameraControl.exe",
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
    $devices = Get-CimInstance Win32_PnPEntity -ErrorAction SilentlyContinue | 
               Where-Object { $_.DeviceID -like "*VID_04A9*" -or $_.Caption -like "*Canon*" -or $_.Description -like "*Canon*" }
    return ($null -ne $devices)
}

function Ensure-AppRunning {
    $process = Get-Process -Name "CameraControl", "DSLRCam", "CameraControlRemoteCmd" -ErrorAction SilentlyContinue
    if (-not $process) {
        if (Test-Path $MainAppPath) {
            Write-Log "Canon Camera USB detected! Auto-launching digiCamControl SILENTLY ($MainAppPath)..."
            # Launch hidden in backend without showing GUI window on screen
            Start-Process -FilePath $MainAppPath -WindowStyle Hidden
            Start-Sleep -Seconds 5
        } elseif (Test-Path $CmdAppPath) {
            Write-Log "Auto-launching digiCamControl CLI ($CmdAppPath)..."
            Start-Process -FilePath $CmdAppPath -ArgumentList "/server" -WindowStyle Hidden
            Start-Sleep -Seconds 5
        } else {
            Write-Log "digiCamControl application not found. Please launch digiCamControl manually."
        }
    }
}

Write-Log "=== Canon USB Auto-Detector & Keep-Alive Service Started (Debug Interval: $IntervalMinutes Min) ==="
Write-Log "Monitoring for Canon USB Connection..."

while ($true) {
    $isUsbConnected = Test-CanonUsbConnected
    $processRunning = Get-Process -Name "CameraControl", "DSLRCam", "CameraControlRemoteCmd" -ErrorAction SilentlyContinue

    if ($isUsbConnected -or $processRunning) {
        # Ensure digiCamControl is running in silent mode
        Ensure-AppRunning

        $sentSuccess = $false

        # 1. Try sending HTTP Keep-Alive signal
        try {
            $response = Invoke-WebRequest -Uri $ServerUrl -Method Get -TimeoutSec 5 -UseBasicParsing
            if ($response.StatusCode -eq 200) {
                Write-Log "SUCCESS [HTTP]: Sent keep-alive signal to digiCamControl server."
                $sentSuccess = $true
            }
        } catch {
            # HTTP server might be starting or disabled
        }

        # 2. Fallback / Direct CLI keep-alive signal via CameraControlCmd.exe
        if (-not $sentSuccess -and (Test-Path $CmdAppPath)) {
            try {
                Start-Process -FilePath $CmdAppPath -ArgumentList "/c LiveViewWnd_Show" -WindowStyle Hidden -Wait
                Write-Log "SUCCESS [CLI]: Triggered keep-alive via CameraControlCmd.exe."
                $sentSuccess = $true
            } catch {
                Write-Log "ERROR [CLI]: Failed to send CLI command: $_"
            }
        }

        if (-not $sentSuccess) {
            Write-Log "WARNING: Could not reach digiCamControl HTTP API or CLI. Ensure Web Server is enabled in Settings."
        }

        Write-Log "Next heartbeat in $IntervalMinutes minute(s)..."
        Start-Sleep -Seconds ($IntervalMinutes * 60)
    } else {
        # Camera not connected yet, check again every 10 seconds
        Start-Sleep -Seconds 10
    }
}
