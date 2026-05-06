# Script to create a directory junction for Android SDK (fixes spaces in path issue)
# Run this script as Administrator

Write-Host "Creating directory junction to fix Android SDK path issue..." -ForegroundColor Yellow

$actualSdkPath = "$env:LOCALAPPDATA\Android\Sdk"
$junctionPath = "C:\Android\Sdk"

if (Test-Path $actualSdkPath) {
    Write-Host "Found Android SDK at: $actualSdkPath" -ForegroundColor Green
    
    # Check if junction already exists
    if (Test-Path $junctionPath) {
        Write-Host "Junction already exists at: $junctionPath" -ForegroundColor Yellow
        Write-Host "Removing existing junction..." -ForegroundColor Yellow
        Remove-Item $junctionPath -Force -ErrorAction SilentlyContinue
    }
    
    # Create C:\Android directory if it doesn't exist
    $androidDir = "C:\Android"
    if (-not (Test-Path $androidDir)) {
        Write-Host "Creating directory: $androidDir" -ForegroundColor Yellow
        New-Item -ItemType Directory -Path $androidDir -Force | Out-Null
    }
    
    # Create directory junction (requires admin)
    try {
        Write-Host "Creating junction from $junctionPath to $actualSdkPath..." -ForegroundColor Yellow
        cmd /c mklink /J "$junctionPath" "$actualSdkPath"
        
        if (Test-Path $junctionPath) {
            Write-Host "Successfully created junction!" -ForegroundColor Green
            
            # Update Flutter config
            Write-Host "Updating Flutter configuration..." -ForegroundColor Yellow
            flutter config --android-sdk $junctionPath
            
            Write-Host ""
            Write-Host "Success! The Android SDK path issue has been fixed." -ForegroundColor Green
            Write-Host "Run 'flutter doctor' to verify." -ForegroundColor Yellow
        }
        else {
            Write-Host "Failed to create junction. Make sure you're running as Administrator!" -ForegroundColor Red
        }
    }
    catch {
        Write-Host "Error: $_" -ForegroundColor Red
        Write-Host "Make sure you're running this script as Administrator!" -ForegroundColor Red
    }
}
else {
    Write-Host "Error: Android SDK not found at $actualSdkPath" -ForegroundColor Red
}
