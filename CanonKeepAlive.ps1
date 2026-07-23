# Canon DSLR Keep-Alive & Auto Live-View Trigger
# Auto-detects Canon camera USB connection, launches Virtual Webcam, and automatically clicks 'Start Live View' button.

param (
    [int]$IntervalMinutes = 2,  # Defaulted to 2 minutes for debugging
    [string]$ServerUrl = "http://localhost:5513/?CMD=LiveViewWnd_Show",
    [string]$WebcamAppPath = "C:\Program Files (x86)\digiCamControl Virtual Webcam\DSLRCam.exe",
    [string]$CmdAppPath = "C:\Program Files (x86)\digiCamControl\CameraControlCmd.exe"
)

$LogFile = Join-Path -Path $PSScriptRoot -ChildPath "keep_alive.log"

# Load UI Automation Assemblies
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

function Click-StartLiveViewButton {
    try {
        $root = [System.Windows.Automation.AutomationElement]::RootElement
        $condition = New-Object System.Windows.Automation.PropertyCondition(
            [System.Windows.Automation.AutomationElement]::NameProperty,
            "digiCamControl Virtual Webcam Configuration"
        )

        $window = $root.FindFirst([System.Windows.Automation.TreeScope]::Children, $condition)

        if ($null -eq $window) {
            $proc = Get-Process -Name "DSLRCam" -ErrorAction SilentlyContinue | Select-Object -First 1
            if ($proc) {
                $procCondition = New-Object System.Windows.Automation.PropertyCondition(
                    [System.Windows.Automation.AutomationElement]::ProcessIdProperty,
                    $proc.Id
                )
                $window = $root.FindFirst([System.Windows.Automation.TreeScope]::Children, $procCondition)
            }
        }

        if ($window) {
            $btnCondition = New-Object System.Windows.Automation.PropertyCondition(
                [System.Windows.Automation.AutomationElement]::NameProperty,
                "Start Live View"
            )
            $button = $window.FindFirst([System.Windows.Automation.TreeScope]::Subtree, $btnCondition)

            if ($button) {
                $invokePattern = $button.GetCurrentPattern([System.Windows.Automation.InvokePattern]::Pattern)
                $invokePattern.Invoke()
                Write-Log "SUCCESS [UI Automation]: Automatically clicked 'Start Live View' button!"
                return $true
            } else {
                Write-Log "WARNING [UI Automation]: Found window but 'Start Live View' button was not found."
            }
        }
    } catch {
        Write-Log "WARNING [UI Automation]: Could not click button via UI Automation: $_"
    }
    return $false
}

function Ensure-VirtualWebcamRunning {
    $proc = Get-Process -Name "DSLRCam" -ErrorAction SilentlyContinue
    if (-not $proc) {
        if (Test-Path $WebcamAppPath) {
            Write-Log "Auto-launching digiCamControl Virtual Webcam ($WebcamAppPath)..."
            Start-Process -FilePath $WebcamAppPath
            Start-Sleep -Seconds 4
        }
    }
}

Write-Log "=== Canon USB Auto-Detector & Live View Keep-Alive Started (Interval: $IntervalMinutes Min) ==="
Write-Log "Monitoring for Canon USB Connection..."

while ($true) {
    $isUsbConnected = Test-CanonUsbConnected

    if ($isUsbConnected) {
        # Ensure Virtual Webcam application is running
        Ensure-VirtualWebcamRunning

        # Attempt UI Automation button click on 'Start Live View'
        $clicked = Click-StartLiveViewButton

        if (-not $clicked) {
            # Fallback heartbeat via CLI / HTTP
            if (Test-Path $CmdAppPath) {
                try {
                    Start-Process -FilePath $CmdAppPath -ArgumentList "/c LiveViewWnd_Show" -WindowStyle Hidden -Wait
                    Write-Log "SUCCESS [CLI]: Sent keep-alive heartbeat to Canon DSLR."
                } catch {
                    Write-Log "ERROR [CLI]: Failed to send heartbeat: $_"
                }
            }
        }

        Write-Log "Next heartbeat in $IntervalMinutes minute(s)..."
        Start-Sleep -Seconds ($IntervalMinutes * 60)
    } else {
        Start-Sleep -Seconds 5
    }
}
