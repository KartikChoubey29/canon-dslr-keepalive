# Canon DSLR Keep-Alive & Auto-Launch Script (Headless / Silent Backend)
# Detects Canon USB camera instantly and sends keep-alive signals via CLI without opening any desktop GUI app.

param (
    [int]$IntervalMinutes = 2,  # Defaulted to 2 minutes for debugging
    [string]$ServerUrl = "http://localhost:5513/?CMD=LiveViewWnd_Show",
    [string]$CmdAppPath = "C:\Program Files (x86)\digiCamControl\CameraControlCmd.exe",
    [string]$MainAppPath = "C:\Program Files (x86)\digiCamControl\CameraControl.exe"
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
    # Fast and accurate query for connected imaging/camera devices
    $devices = Get-PnpDevice -Class "WPD", "Camera", "Image" -Status "OK" -ErrorAction SilentlyContinue | 
               Where-Object { $_.InstanceId -like "*VID_04A9*" -or $_.FriendlyName -like "*Canon*" }
    return ($null -ne $devices)
}

Write-Log "=== Canon USB Auto-Detector & Keep-Alive Service Started (Headless Mode, Interval: $IntervalMinutes Min) ==="
Write-Log "Monitoring for Canon USB Connection..."

while ($true) {
    $isUsbConnected = Test-CanonUsbConnected

    if ($isUsbConnected) {
        Write-Log "Canon DSLR USB Connection Detected! Sending keep-alive heartbeat..."
        $sentSuccess = $false

        # 1. Try background HTTP server if digiCamControl is open
        $processRunning = Get-Process -Name "CameraControl", "DSLRCam" -ErrorAction SilentlyContinue
        if ($processRunning) {
            try {
                $response = Invoke-WebRequest -Uri $ServerUrl -Method Get -TimeoutSec 5 -UseBasicParsing
                if ($response.StatusCode -eq 200) {
                    Write-Log "SUCCESS [HTTP]: Sent keep-alive signal to running digiCamControl server."
                    $sentSuccess = $true
                }
            } catch {
                # HTTP request failed, fallback to standalone CLI
            }
        }

        # 2. Standalone Headless CLI Mode (Does NOT open any GUI app window!)
        if (-not $sentSuccess -and (Test-Path $CmdAppPath)) {
            try {
                Start-Process -FilePath $CmdAppPath -ArgumentList "/c LiveViewWnd_Show" -WindowStyle Hidden -Wait
                Write-Log "SUCCESS [Headless CLI]: Sent keep-alive signal directly to Canon DSLR."
                $sentSuccess = $true
            } catch {
                Write-Log "ERROR [CLI]: Failed to execute CLI command: $_"
            }
        }

        if (-not $sentSuccess) {
            Write-Log "WARNING: Could not send keep-alive signal. Ensure digiCamControl CLI tool is installed."
        }

        Write-Log "Next heartbeat in $IntervalMinutes minute(s)..."
        Start-Sleep -Seconds ($IntervalMinutes * 60)
    } else {
        # Camera not plugged in yet, check again every 5 seconds
        Start-Sleep -Seconds 5
    }
}
