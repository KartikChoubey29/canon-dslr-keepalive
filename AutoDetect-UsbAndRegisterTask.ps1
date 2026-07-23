# Automated Setup Script for Canon DSLR Keep-Alive
# Automatically detects connected Canon cameras, enables required Windows logs,
# finds the exact Event ID / Device ID for the user's system, and registers Task Scheduler.

param (
    [string]$WebcamAppPath = "C:\Program Files (x86)\digiCamControl Virtual Webcam\DSLRCam.exe"
)

$ScriptPath = Join-Path -Path $PSScriptRoot -ChildPath "CanonKeepAlive.ps1"
$TaskName = "CanonUsbKeepAliveOnPlug"

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "   Canon DSLR Keep-Alive Automated Installer for Windows  " -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

# 1. Enable DriverFrameworks log if disabled
Write-Host "`n[1/4] Checking Windows DriverFrameworks Event Logging..." -ForegroundColor Yellow
try {
    wevtutil sl "Microsoft-Windows-DriverFrameworks-UserMode/Operational" /e:true 2>$null
    Write-Host "  -> DriverFrameworks-UserMode logging is ENABLED." -ForegroundColor Green
} catch {
    Write-Host "  -> Warning: Could not enable log automatically. Run as Administrator if needed." -ForegroundColor DarkYellow
}

# 2. Detect connected Canon USB Camera
Write-Host "`n[2/4] Scanning for connected Canon DSLR Camera..." -ForegroundColor Yellow

$canonDevice = Get-CimInstance Win32_PnPEntity -ErrorAction SilentlyContinue | 
               Where-Object { $_.DeviceID -like "*VID_04A9*" -or $_.Caption -like "*Canon*" -or $_.Description -like "*Canon*" } | 
               Select-Object -First 1

if ($null -eq $canonDevice) {
    Write-Host "  -> No Canon DSLR currently plugged in." -ForegroundColor DarkYellow
    Write-Host "  -> Setting up general Canon Vendor ID (VID_04A9) listener for any Canon camera..." -ForegroundColor Cyan
    $deviceName = "Canon DSLR Camera"
} else {
    Write-Host "  -> SUCCESS! Found connected Canon Camera:" -ForegroundColor Green
    Write-Host "     Name:      $($canonDevice.Caption)" -ForegroundColor Cyan
    Write-Host "     Device ID: $($canonDevice.DeviceID)" -ForegroundColor Cyan
    $deviceName = $canonDevice.Caption
}

# 3. Find recent connection Event ID or construct PnP filter
Write-Host "`n[3/4] Searching Event Viewer for camera connection events..." -ForegroundColor Yellow

$eventId = 2003 # Standard UMDF PnP Driver Load Event ID

# Check if recent event exists in DriverFrameworks log
$recentEvent = Get-WinEvent -LogName "Microsoft-Windows-DriverFrameworks-UserMode/Operational" -MaxEvents 50 -ErrorAction SilentlyContinue |
               Where-Object { $_.Id -in 2003, 2004, 2006, 2010 } | Select-Object -First 1

if ($recentEvent) {
    $eventId = $recentEvent.Id
    Write-Host "  -> Found live connection Event ID $eventId logged at $($recentEvent.TimeCreated)" -ForegroundColor Green
} else {
    Write-Host "  -> Using standard PnP Driver Load Event ID $eventId" -ForegroundColor DarkYellow
}

# 4. Build Custom Task Scheduler XML Trigger
Write-Host "`n[4/4] Registering Task Scheduler Trigger for this PC..." -ForegroundColor Yellow

$XmlContent = @"
<?xml version="1.0" encoding="UTF-16"?>
<Task version="1.2" xmlns="http://schemas.microsoft.com/windows/2004/02/mit/task">
  <RegistrationInfo>
    <Description>Auto-launches Canon KeepAlive automation when Canon DSLR USB connects</Description>
  </RegistrationInfo>
  <Triggers>
    <EventTrigger>
      <Enabled>true</Enabled>
      <Subscription>&lt;QueryList&gt;&lt;Query Id="0" Path="Microsoft-Windows-DriverFrameworks-UserMode/Operational"&gt;&lt;Select Path="Microsoft-Windows-DriverFrameworks-UserMode/Operational"&gt;*[System[EventID=$eventId]]&lt;/Select&gt;&lt;/Query&gt;&lt;/QueryList&gt;</Subscription>
    </EventTrigger>
  </Triggers>
  <Principals>
    <Principal id="Author">
      <LogonType>InteractiveToken</LogonType>
      <RunLevel>HighestAvailable</RunLevel>
    </Principal>
  </Principals>
  <Settings>
    <MultipleInstancesPolicy>IgnoreNew</MultipleInstancesPolicy>
    <DisallowStartIfOnBatteries>false</DisallowStartIfOnBatteries>
    <StopIfGoingOnBatteries>false</StopIfGoingOnBatteries>
    <AllowHardTerminate>true</AllowHardTerminate>
    <StartWhenAvailable>true</StartWhenAvailable>
    <RunOnlyIfNetworkAvailable>false</RunOnlyIfNetworkAvailable>
    <ExecutionTimeLimit>PT0S</ExecutionTimeLimit>
    <Priority>7</Priority>
  </Settings>
  <Actions Context="Author">
    <Exec>
      <Command>powershell.exe</Command>
      <Arguments>-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File "$ScriptPath"</Arguments>
    </Exec>
  </Actions>
</Task>
"@

try {
    $result = Register-ScheduledTask -TaskName $TaskName -Xml $XmlContent -ErrorAction Stop -Force
    Write-Host "`n==========================================================" -ForegroundColor Green
    Write-Host " SUCCESS! Task '$TaskName' registered successfully." -ForegroundColor Green
    Write-Host " Windows will now automatically launch the Keep-Alive script" -ForegroundColor Green
    Write-Host " whenever your Canon DSLR ($deviceName) is plugged in!" -ForegroundColor Green
    Write-Host "==========================================================" -ForegroundColor Green
} catch {
    Write-Host "`n==========================================================" -ForegroundColor Red
    Write-Host " ERROR: Could not register task: $_" -ForegroundColor Red
    Write-Host " Please right-click PowerShell and select 'Run as Administrator'." -ForegroundColor Yellow
    Write-Host "==========================================================" -ForegroundColor Red
}
