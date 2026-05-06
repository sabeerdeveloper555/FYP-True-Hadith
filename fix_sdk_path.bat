@echo off
REM Script to create a directory junction for Android SDK (fixes spaces in path issue)
REM Run this script as Administrator

echo Creating directory junction to fix Android SDK path issue...

set "ACTUAL_SDK=%LOCALAPPDATA%\Android\Sdk"
set "JUNCTION_PATH=C:\Android\Sdk"

if exist "%ACTUAL_SDK%" (
    echo Found Android SDK at: %ACTUAL_SDK%
    
    REM Remove existing junction if it exists
    if exist "%JUNCTION_PATH%" (
        echo Removing existing junction...
        rmdir "%JUNCTION_PATH%" 2>nul
    )
    
    REM Create C:\Android directory if it doesn't exist
    if not exist "C:\Android" (
        echo Creating directory: C:\Android
        mkdir "C:\Android" 2>nul
    )
    
    REM Create directory junction
    echo Creating junction from %JUNCTION_PATH% to %ACTUAL_SDK%...
    mklink /J "%JUNCTION_PATH%" "%ACTUAL_SDK%"
    
    if exist "%JUNCTION_PATH%" (
        echo Successfully created junction!
        echo.
        echo Updating Flutter configuration...
        flutter config --android-sdk "%JUNCTION_PATH%"
        echo.
        echo Success! The Android SDK path issue has been fixed.
        echo Run 'flutter doctor' to verify.
    ) else (
        echo Failed to create junction. Make sure you're running as Administrator!
    )
) else (
    echo Error: Android SDK not found at %ACTUAL_SDK%
)

pause
