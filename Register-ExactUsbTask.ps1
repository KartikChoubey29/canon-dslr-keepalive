# Register Task Scheduler task triggered specifically by Canon USB Connection Event (ID 2003)

$ScriptPath = Join-Path -Path $PSScriptRoot -ChildPath "CanonKeepAlive.ps1"
$TaskName = "CanonUsbKeepAliveOnPlug"

$XmlQuery = @"
<QueryList>
  <Query Id="0" Path="Microsoft-Windows-DriverFrameworks-UserMode/Operational">
    <Select Path="Microsoft-Windows-DriverFrameworks-UserMode/Operational">
      *[System[EventID=2003]] and *[UserData[UMDFHostDeviceRequest[InstanceId='USB\VID_04A9&amp;PID_32E9\5&amp;1E4730D7&amp;0&amp;3']]]
    </Select>
  </Query>
</QueryList>
"@

$Action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$ScriptPath`""
$Trigger = New-ScheduledTaskTrigger -CustomTrigger $XmlQuery

try {
    Register-ScheduledTask -TaskName $TaskName -Action $Action -Trigger $Trigger -Description "Auto-launches Canon KeepAlive automation when Canon DSLR USB connects" -User $env:USERNAME -Force
    Write-Host "SUCCESS: Custom USB Event Task '$TaskName' registered!" -ForegroundColor Green
    Write-Host "Windows will now launch the KeepAlive script the exact instant your Canon DSLR is plugged in." -ForegroundColor Cyan
} catch {
    Write-Host "ERROR: Could not register task: $_" -ForegroundColor Red
}
