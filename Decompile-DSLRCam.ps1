# Inspect methods inside DSLRCam.exe (digiCamControl Virtual Webcam)

Add-Type -Path "C:\Program Files (x86)\digiCamControl Virtual Webcam\Canon.Eos.Framework.dll" -ErrorAction SilentlyContinue
Add-Type -Path "C:\Program Files (x86)\digiCamControl Virtual Webcam\CameraControl.Devices.dll" -ErrorAction SilentlyContinue

$asm = [System.Reflection.Assembly]::LoadFrom("C:\Program Files (x86)\digiCamControl Virtual Webcam\DSLRCam.exe")

Write-Host "=== Classes and Methods in DSLRCam.exe ==="
$flags = [System.Reflection.BindingFlags]'Public,NonPublic,Instance,Static'
$types = $asm.GetTypes()
foreach ($t in $types) {
    Write-Host "`nClass: $($t.FullName)" -ForegroundColor Cyan
    $methods = $t.GetMethods($flags) | Where-Object { $_.DeclaringType.Name -eq $t.Name }
    foreach ($m in $methods) {
        Write-Host "   -> Method: $($m.Name)" -ForegroundColor Green
    }
}
