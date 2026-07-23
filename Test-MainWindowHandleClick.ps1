# Test clicking Start Live View via MainWindowHandle

Add-Type -AssemblyName UIAutomationClient
Add-Type -AssemblyName UIAutomationTypes

Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
public class Win32Window {
    [DllImport("user32.dll")]
    public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
}
"@ -ErrorAction SilentlyContinue

$proc = Get-Process -Name "DSLRCam" -ErrorAction SilentlyContinue | Select-Object -First 1

if ($proc) {
    Write-Host "Found DSLRCam Process (ID: $($proc.Id), Handle: $($proc.MainWindowHandle))" -ForegroundColor Green
    
    $window = [System.Windows.Automation.AutomationElement]::FromHandle($proc.MainWindowHandle)
    if ($window) {
        Write-Host "AutomationElement from Handle: $($window.Current.Name)" -ForegroundColor Green
        
        $btnCondition = New-Object System.Windows.Automation.PropertyCondition(
            [System.Windows.Automation.AutomationElement]::NameProperty,
            "Start Live View"
        )
        $button = $window.FindFirst([System.Windows.Automation.TreeScope]::Subtree, $btnCondition)
        
        if ($button) {
            Write-Host "FOUND 'Start Live View' BUTTON! Invoking Click..." -ForegroundColor Green
            $invokePattern = $button.GetCurrentPattern([System.Windows.Automation.InvokePattern]::Pattern)
            $invokePattern.Invoke()
            Write-Host "SUCCESS! Clicked 'Start Live View' button!" -ForegroundColor Green
            
            Start-Sleep -Seconds 1
            [Win32Window]::ShowWindow($proc.MainWindowHandle, 6)
            Write-Host "Minimized window to taskbar." -ForegroundColor Green
        } else {
            Write-Host "Could not find 'Start Live View' button inside window." -ForegroundColor Red
        }
    }
} else {
    Write-Host "DSLRCam.exe is not running right now. Open DSLRCam.exe first to test." -ForegroundColor Red
}
