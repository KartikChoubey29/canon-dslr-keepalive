# Test Script using digiCamControl Standalone DLL (CameraControl.Devices.dll)

param (
    [string]$DllPath = "C:\Program Files (x86)\digiCamControl\CameraControl.Devices.dll"
)

try {
    Write-Host "Loading digiCamControl DLLs in 32-bit mode..."
    Add-Type -Path "C:\Program Files (x86)\digiCamControl\Canon.Eos.Framework.dll" -ErrorAction SilentlyContinue
    Add-Type -Path $DllPath
    
    $dm = New-Object CameraControl.Devices.CameraDeviceManager("")
    Write-Host "Connecting to Canon Camera via DLL..."
    $res = $dm.ConnectToCamera()
    Write-Host "ConnectToCamera result: $res"
    Start-Sleep -Seconds 3
    
    if ($dm.SelectedCameraDevice) {
        Write-Host "CAMERA DETECTED VIA DLL: $($dm.SelectedCameraDevice.DisplayName)" -ForegroundColor Green
        Write-Host "Invoking StartLiveView()..." -ForegroundColor Green
        $lv = $dm.SelectedCameraDevice.StartLiveView()
        Write-Host "Result of StartLiveView(): $lv" -ForegroundColor Green
    } else {
        Write-Host "Connected Devices Count: $($dm.ConnectedDevices.Count)" -ForegroundColor Yellow
        foreach ($dev in $dm.ConnectedDevices) {
            Write-Host " -> Found device: $($dev.DisplayName)"
        }
    }
} catch {
    Write-Host "Error using DLL: $_" -ForegroundColor Red
}
