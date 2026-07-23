# Direct MainViewModel Execution Script (No App Window)
# Instantiates DSLRCam.ViewModel.MainViewModel directly in PowerShell and invokes StartLiveView()

Add-Type -Path "C:\Program Files (x86)\digiCamControl Virtual Webcam\Canon.Eos.Framework.dll" -ErrorAction SilentlyContinue
Add-Type -Path "C:\Program Files (x86)\digiCamControl Virtual Webcam\CameraControl.Devices.dll" -ErrorAction SilentlyContinue

try {
    Write-Host "Loading DSLRCam.exe assembly..."
    $asm = [System.Reflection.Assembly]::LoadFrom("C:\Program Files (x86)\digiCamControl Virtual Webcam\DSLRCam.exe")
    $vmType = $asm.GetType("DSLRCam.ViewModel.MainViewModel")

    Write-Host "Instantiating MainViewModel directly in background..."
    $vm = [System.Activator]::CreateInstance($vmType)

    Write-Host "Connecting to Canon Camera via DeviceManager..."
    $dm = $vm.DeviceManager
    $dm.ConnectToCamera()
    Start-Sleep -Seconds 3

    if ($vm.CameraDevice) {
        Write-Host "CANON CAMERA CONNECTED: $($vm.CameraDevice.DisplayName)" -ForegroundColor Green
        Write-Host "Invoking StartLiveView() directly..." -ForegroundColor Green
        $vm.StartLiveView()
        Write-Host "SUCCESS: Live View started directly in background process!" -ForegroundColor Green
    } else {
        Write-Host "Camera not connected yet. Connected Devices: $($dm.ConnectedDevices.Count)" -ForegroundColor Yellow
    }
} catch {
    Write-Host "Error executing MainViewModel: $_" -ForegroundColor Red
}
