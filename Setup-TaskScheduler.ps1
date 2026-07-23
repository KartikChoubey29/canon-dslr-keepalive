# Register Canon Keep-Alive task in Windows Task Scheduler

$ScriptPath = Join-Path -Path $PSScriptRoot -ChildPath "CanonKeepAlive.ps1"
$TaskName = "CanonKeepAliveAutomation"

$Action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$ScriptPath`""
$Trigger = New-ScheduledTaskTrigger -AtLogOn

try {
    Register-ScheduledTask -TaskName $TaskName -Action $Action -Trigger $Trigger -Description "Keeps Canon DSLR active via digiCamControl" -User $env:USERNAME -Force
    Write-Host "SUCCESS: Task '$TaskName' registered!" -ForegroundColor Green
    Write-Host "It will run quietly in the background on startup." -ForegroundColor Cyan
} catch {
    Write-Host "ERROR: Failed to register task: $_" -ForegroundColor Red
}
