# Script to fix ANDROID_HOME environment variable
# Run this script as Administrator

Write-Host "Fixing ANDROID_HOME environment variable..." -ForegroundColor Yellow

$correctPath = "$env:LOCALAPPDATA\Android\Sdk"

if (Test-Path $correctPath) {
    Write-Host "Found Android SDK at: $correctPath" -ForegroundColor Green
    
    # Update Machine-level (system-wide) environment variable
    try {
        [System.Environment]::SetEnvironmentVariable('ANDROID_HOME', $correctPath, [System.EnvironmentVariableTarget]::Machine)
        [System.Environment]::SetEnvironmentVariable('ANDROID_SDK_ROOT', $correctPath, [System.EnvironmentVariableTarget]::Machine)
        Write-Host "Successfully updated ANDROID_HOME to: $correctPath" -ForegroundColor Green
        Write-Host ""
        Write-Host "Please restart your terminal/PowerShell window for changes to take effect." -ForegroundColor Yellow
        Write-Host "Then run 'flutter doctor' to verify the fix." -ForegroundColor Yellow
    }
    catch {
        Write-Host "Error: $_" -ForegroundColor Red
        Write-Host "Make sure you're running this script as Administrator!" -ForegroundColor Red
    }
}
else {
    Write-Host "Error: Android SDK not found at $correctPath" -ForegroundColor Red
    Write-Host "Please install Android SDK first." -ForegroundColor Red
}
