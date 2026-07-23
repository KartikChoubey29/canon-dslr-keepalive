# Canon DSLR Live View Auto-Start & Keep-Alive Automation
# Launches Virtual Webcam, automatically clicks 'Start Live View' via MainWindowHandle to clear Canon PC screen,
# minimizes the app window to the taskbar, and sends periodic keep-alive heartbeats.

param (
    [int]$IntervalMinutes = 2,  # Defaulted to 2 minutes for debugging
    [string]$WebcamAppPath = "C:\Program Files (x86)\digiCamControl Virtual Webcam\DSLRCam.exe"
)

$LogFile = Join-Path -Path $PSScriptRoot -ChildPath "keep_alive.log"

# Load UI Automation and Win32 Window APIs
Add-Type -AssemblyName UIAutomationClient -ErrorAction SilentlyContinue
Add-Type -AssemblyName UIAutomationTypes -ErrorAction SilentlyContinue

Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
public class Win32Window {
    [DllImport("user32.dll")]
    public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
}
"@ -ErrorAction SilentlyContinue

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

function Click-StartLiveViewAndMinimize {
    try {
        $proc = Get-Process -Name "DSLRCam" -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($null -eq $proc -or $proc.MainWindowHandle -eq [IntPtr]::Zero) {
            Write-Log "DSLRCam window handle not ready yet."
            return $false
        }

        # Grabbing AutomationElement directly from the process MainWindowHandle (100% reliable)
        $window = [System.Windows.Automation.AutomationElement]::FromHandle($proc.MainWindowHandle)

        if ($window) {
            # Search for Button with Name 'Start Live View'
            $btnCondition = New-Object System.Windows.Automation.PropertyCondition(
                [System.Windows.Automation.AutomationElement]::NameProperty,
                "Start Live View"
            )
            $button = $window.FindFirst([System.Windows.Automation.TreeScope]::Subtree, $btnCondition)

            if ($button) {
                $invokePattern = $button.GetCurrentPattern([System.Windows.Automation.InvokePattern]::Pattern)
                $invokePattern.Invoke()
                Write-Log "SUCCESS [UI Automation]: Programmatically CLICKED 'Start Live View' button! Canon camera is live."
                
                Start-Sleep -Seconds 1
                [Win32Window]::ShowWindow($proc.MainWindowHandle, 6) # 6 = SW_MINIMIZE
                Write-Log "SUCCESS: Minimized Virtual Webcam window to taskbar."
                return $true
            } else {
                Write-Log "Found Virtual Webcam window, but 'Start Live View' button was not found or is already active."
            }
        }
    } catch {
        Write-Log "WARNING [UI Automation]: Could not click button: $_"
    }
    return $false
}

function Ensure-VirtualWebcamRunning {
    # Terminate any orphaned CLI utility processes holding Canon USB session
    Stop-Process -Name "CameraControlCmd", "CameraControlRemoteCmd" -Force -ErrorAction SilentlyContinue

    $proc = Get-Process -Name "DSLRCam" -ErrorAction SilentlyContinue
    if (-not $proc) {
        if (Test-Path $WebcamAppPath) {
            Write-Log "Canon USB connected! Auto-launching digiCamControl Virtual Webcam..."
            
            # Set working directory to Virtual Webcam folder so vcam.dll driver loads
            $appDir = "C:\Program Files (x86)\digiCamControl Virtual Webcam"
            [System.IO.Directory]::SetCurrentDirectory($appDir)
            Set-Location $appDir
            
            Start-Process -FilePath $WebcamAppPath
            Start-Sleep -Seconds 4
        } else {
            Write-Log "ERROR: Virtual Webcam app not found at $WebcamAppPath"
        }
    }
}

Write-Log "=== Canon Live View Auto-Start & Keep-Alive Service Started ==="
Write-Log "Monitoring for Canon USB Connection..."

while ($true) {
    $isUsbConnected = Test-CanonUsbConnected

    if ($isUsbConnected) {
        Ensure-VirtualWebcamRunning
        $null = Click-StartLiveViewAndMinimize

        Write-Log "Next heartbeat check in $IntervalMinutes minute(s)..."
        Start-Sleep -Seconds ($IntervalMinutes * 60)
    } else {
        Start-Sleep -Seconds 5
    }
}
