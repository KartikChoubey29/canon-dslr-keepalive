# Inspect CameraControl.Devices.dll

Add-Type -Path "C:\Program Files (x86)\digiCamControl\Canon.Eos.Framework.dll" -ErrorAction SilentlyContinue
Add-Type -Path "C:\Program Files (x86)\digiCamControl\CameraControl.Devices.dll"

$t = [CameraControl.Devices.CameraDeviceManager]
Write-Host "Constructors for CameraDeviceManager:"
$t.GetConstructors() | ForEach-Object {
    Write-Host " -> Constructor params: " ($_.GetParameters() | Select-Object -ExpandProperty ParameterType)
}

Write-Host "`nPublic Methods:"
$t.GetMethods() | Where-Object { $_.IsPublic -and -not $_.IsSpecialName } | Select-Object Name | Format-Table -AutoSize
