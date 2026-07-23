# Detailed reflection on DSLRCam.ViewModel.MainViewModel

Add-Type -Path "C:\Program Files (x86)\digiCamControl Virtual Webcam\Canon.Eos.Framework.dll" -ErrorAction SilentlyContinue
Add-Type -Path "C:\Program Files (x86)\digiCamControl Virtual Webcam\CameraControl.Devices.dll" -ErrorAction SilentlyContinue

$asm = [System.Reflection.Assembly]::LoadFrom("C:\Program Files (x86)\digiCamControl Virtual Webcam\DSLRCam.exe")
$type = $asm.GetType("DSLRCam.ViewModel.MainViewModel")

Write-Host "=== Fields in MainViewModel ==="
$type.GetFields([System.Reflection.BindingFlags]'Public,NonPublic,Instance,Static') | ForEach-Object {
    Write-Host "Field: $($_.Name) ($($_.FieldType.Name))"
}

Write-Host "`n=== Properties in MainViewModel ==="
$type.GetProperties() | ForEach-Object {
    Write-Host "Property: $($_.Name) ($($_.PropertyType.Name))"
}
