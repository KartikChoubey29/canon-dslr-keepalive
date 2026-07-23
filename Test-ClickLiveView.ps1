# Test Script for UI Automation Click on "Start Live View" button in digiCamControl Virtual Webcam

Add-Type -AssemblyName UIAutomationClient
Add-Type -AssemblyName UIAutomationTypes

Write-Host "Searching for digiCamControl Virtual Webcam window..."

$root = [System.Windows.Automation.AutomationElement]::RootElement
$condition = New-Object System.Windows.Automation.PropertyCondition(
    [System.Windows.Automation.AutomationElement]::NameProperty,
    "digiCamControl Virtual Webcam Configuration"
)

$window = $root.FindFirst([System.Windows.Automation.TreeScope]::Children, $condition)

if ($null -eq $window) {
    $proc = Get-Process -Name "DSLRCam" -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($proc) {
        $procCondition = New-Object System.Windows.Automation.PropertyCondition(
            [System.Windows.Automation.AutomationElement]::ProcessIdProperty,
            $proc.Id
        )
        $window = $root.FindFirst([System.Windows.Automation.TreeScope]::Children, $procCondition)
    }
}

if ($window) {
    Write-Host "FOUND WINDOW: $($window.Current.Name)" -ForegroundColor Green
    
    $btnCondition = New-Object System.Windows.Automation.PropertyCondition(
        [System.Windows.Automation.AutomationElement]::NameProperty,
        "Start Live View"
    )
    $button = $window.FindFirst([System.Windows.Automation.TreeScope]::Subtree, $btnCondition)
    
    if ($button) {
        Write-Host "FOUND BUTTON: 'Start Live View'! Triggering Click pattern..." -ForegroundColor Green
        $invokePattern = $button.GetCurrentPattern([System.Windows.Automation.InvokePattern]::Pattern)
        $invokePattern.Invoke()
        Write-Host "SUCCESSFULLY CLICKED 'Start Live View' BUTTON!" -ForegroundColor Green
    } else {
        Write-Host "Listing all buttons in window:" -ForegroundColor Yellow
        $allButtonsCondition = New-Object System.Windows.Automation.PropertyCondition(
            [System.Windows.Automation.AutomationElement]::ControlTypeProperty,
            [System.Windows.Automation.ControlType]::Button
        )
        $allButtons = $window.FindAll([System.Windows.Automation.TreeScope]::Subtree, $allButtonsCondition)
        foreach ($b in $allButtons) {
            Write-Host " -> Button: '$($b.Current.Name)' (AutomationId: '$($b.Current.AutomationId)')"
        }
    }
} else {
    Write-Host "digiCamControl Virtual Webcam Configuration window is not open." -ForegroundColor Red
}
