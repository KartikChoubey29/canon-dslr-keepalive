# Canon DSLR Keep-Alive & Auto-LiveView Trigger (Headless Mode)
# Auto-detects Canon camera USB connection, switches camera into Live View mode on startup, and sends periodic keep-alive signals.

param (
    [int]$IntervalMinutes = 2,  # Defaulted to 2 minutes for debugging
    [string]$ServerUrl = "http://localhost:5513/?CMD=LiveViewWnd_Show",
    [string]$CmdAppPath = "C:\Program Files (x86)\digiCamControl\CameraControlCmd.exe"
)

$LogFile = Join-Path -Path $PSScriptRoot -ChildPath "keep_alive.log"
$isFirstTrigger = $true

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

function Trigger-LiveViewMode {
    param ([string]$CmdPath)
    Write-Log "--------------------------------------------------------"
    Write-Log "🎬 TRIGGERING CANON DSLR INTO LIVE VIEW MODE..."
    
    # 1. Check HTTP server if digiCamControl is open
    try {
        $response = Invoke-WebRequest -Uri "http://localhost:5513/?CMD=LiveViewWnd_Show" -Method Get -TimeoutSec 3 -UseBasicParsing
        if ($response.StatusCode -eq 200) {
            Write-Log "SUCCESS [HTTP]: Live View mode triggered via web server."
            return $true
        }
    } catch {}

    # 2. Trigger Live View via Headless CLI
    if (Test-Path $CmdPath) {
        try {
            Start-Process -FilePath $CmdPath -ArgumentList "/c LiveViewWnd_Show" -WindowStyle Hidden -Wait
            Start-Process -FilePath $CmdPath -ArgumentList "/c Cmd_LiveView" -WindowStyle Hidden -Wait
            Write-Log "SUCCESS [Headless CLI]: Live View mode signal sent to Canon DSLR."
            return $true
        } catch {
            Write-Log "ERROR [CLI]: Failed to send Live View command: $_"
        }
    }
    return $false
}

Write-Log "=== Canon USB Auto-Detector & Live View Keep-Alive Started (Interval: $IntervalMinutes Min) ==="
Write-Log "Monitoring for Canon USB Connection..."

while ($true) {
    $isUsbConnected = Test-CanonUsbConnected

    if ($isUsbConnected) {
        # Trigger initial Live View mode when camera is first detected
        if ($isFirstTrigger) {
            Write-Log "Canon DSLR USB Connection Detected!"
            $null = Trigger-LiveViewMode -CmdPath $CmdAppPath
            $isFirstTrigger = $false
            Write-Log "--------------------------------------------------------"
        } else {
            Write-Log "Sending periodic keep-alive heartbeat..."
            $sentSuccess = $false

            # Try HTTP API first
            $processRunning = Get-Process -Name "CameraControl", "DSLRCam" -ErrorAction SilentlyContinue
            if ($processRunning) {
                try {
                    $response = Invoke-WebRequest -Uri $ServerUrl -Method Get -TimeoutSec 5 -UseBasicParsing
                    if ($response.StatusCode -eq 200) {
                        Write-Log "SUCCESS [HTTP]: Sent keep-alive heartbeat."
                        $sentSuccess = $true
                    }
                } catch {}
            }

            # Try Headless CLI
            if (-not $sentSuccess -and (Test-Path $CmdAppPath)) {
                try {
                    Start-Process -FilePath $CmdAppPath -ArgumentList "/c LiveViewWnd_Show" -WindowStyle Hidden -Wait
                    Write-Log "SUCCESS [Headless CLI]: Sent keep-alive heartbeat to Canon DSLR."
                    $sentSuccess = $true
                } catch {
                    Write-Log "ERROR [CLI]: Failed to send heartbeat: $_"
                }
            }

            if (-not $sentSuccess) {
                Write-Log "WARNING: Could not send keep-alive heartbeat."
            }
        }

        Write-Log "Next heartbeat in $IntervalMinutes minute(s)..."
        Start-Sleep -Seconds ($IntervalMinutes * 60)
    } else {
        # Reset first trigger state when camera is disconnected
        $isFirstTrigger = $true
        Start-Sleep -Seconds 5
    }
}
