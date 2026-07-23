# Canon DSLR Live View Auto-Start & Keep-Alive Automation
# Automatically clicks 'Start Live View' in Virtual Webcam (DSLRCam.exe) to start live video streaming (FPS > 20),
# and sends background keep-alive heartbeats.

param (
    [int]$IntervalMinutes = 2,  # Defaulted to 2 minutes for debugging
    [string]$WebcamAppPath = "C:\Program Files (x86)\digiCamControl Virtual Webcam\DSLRCam.exe",
    [string]$CmdAppPath = "C:\Program Files (x86)\digiCamControl\CameraControlCmd.exe"
)

$LogFile = Join-Path -Path $PSScriptRoot -ChildPath "keep_alive.log"

# Load UI Automation assemblies
Add-Type -AssemblyName UIAutomationClient -ErrorAction SilentlyContinue
Add-Type -AssemblyName UIAutomationTypes -ErrorAction SilentlyContinue

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

function Trigger-StartLiveViewClick {
    try {
        $proc = Get-Process -Name "DSLRCam" -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($null -ne $proc -and $proc.MainWindowHandle -ne [IntPtr]::Zero) {
            $window = [System.Windows.Automation.AutomationElement]::FromHandle($proc.MainWindowHandle)
            if ($window) {
                $btnCondition = New-Object System.Windows.Automation.PropertyCondition(
                    [System.Windows.Automation.AutomationElement]::NameProperty,
                    "Start Live View"
                )
                $button = $window.FindFirst([System.Windows.Automation.TreeScope]::Subtree, $btnCondition)

                if ($button) {
                    $invokePattern = $button.GetCurrentPattern([System.Windows.Automation.InvokePattern]::Pattern)
                    $invokePattern.Invoke()
                    Write-Log "SUCCESS [UI Automation]: Programmatically CLICKED 'Start Live View' button in Virtual Webcam!"
                    return $true
                }
            }
        }
    } catch {
        Write-Log "WARNING [UI Automation]: Could not click button: $_"
    }
    return $false
}

function Ensure-VirtualWebcamRunning {
    $proc = Get-Process -Name "DSLRCam" -ErrorAction SilentlyContinue
    if (-not $proc) {
        if (Test-Path $WebcamAppPath) {
            Write-Log "Canon USB connected! Auto-launching digiCamControl Virtual Webcam..."
            
            # Set working directory to Virtual Webcam folder so driver loads cleanly
            $appDir = "C:\Program Files (x86)\digiCamControl Virtual Webcam"
            [System.IO.Directory]::SetCurrentDirectory($appDir)
            Set-Location $appDir
            
            Start-Process -FilePath $WebcamAppPath
            Start-Sleep -Seconds 4
        }
    }
}

Write-Log "=== Canon Live View Auto-Start & Keep-Alive Service Started (Interval: $IntervalMinutes Min) ==="
Write-Log "Monitoring for Canon USB Connection..."

while ($true) {
    $isUsbConnected = Test-CanonUsbConnected

    if ($isUsbConnected) {
        # Ensure Virtual Webcam app is open
        Ensure-VirtualWebcamRunning

        # Click "Start Live View" to trigger active video stream (FPS > 20)
        $clicked = Trigger-StartLiveViewClick

        # Send CLI heartbeat
        if (Test-Path $CmdAppPath) {
            try {
                Start-Process -FilePath $CmdAppPath -ArgumentList "/nop" -WindowStyle Hidden -Wait
                Write-Log "SUCCESS [CLI Heartbeat]: Sent PTP keep-alive signal to Canon DSLR."
            } catch {}
        }

        Write-Log "Next heartbeat check in $IntervalMinutes minute(s)..."
        Start-Sleep -Seconds ($IntervalMinutes * 60)
    } else {
        Start-Sleep -Seconds 5
    }
}
