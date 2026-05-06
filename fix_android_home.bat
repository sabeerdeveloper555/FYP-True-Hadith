@echo off
REM Script to fix ANDROID_HOME environment variable
REM Run this script as Administrator

echo Fixing ANDROID_HOME environment variable...

set "CORRECT_PATH=%LOCALAPPDATA%\Android\Sdk"

if exist "%CORRECT_PATH%" (
    echo Found Android SDK at: %CORRECT_PATH%
    
    REM Update Machine-level (system-wide) environment variable
    setx ANDROID_HOME "%CORRECT_PATH%" /M
    setx ANDROID_SDK_ROOT "%CORRECT_PATH%" /M
    
    echo.
    echo Successfully updated ANDROID_HOME to: %CORRECT_PATH%
    echo.
    echo Please restart your terminal/PowerShell window for changes to take effect.
    echo Then run 'flutter doctor' to verify the fix.
) else (
    echo Error: Android SDK not found at %CORRECT_PATH%
    echo Please install Android SDK first.
)

pause
