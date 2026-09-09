@echo off
setlocal EnableExtensions
cd /d "%~dp0"

title TimeTrail GitHub Bootstrap

rem ============================================================
rem TimeTrail GitHub Bootstrap - Windows CMD wrapper
rem ASCII-only + CRLF for cmd.exe compatibility.
rem Build/version are read by PowerShell from package.json/index.html.
rem ============================================================
set "TT_REPO_OWNER="
set "TT_REPO_NAME="
set "TT_REPO_VISIBILITY=public"
set "TT_REPO_DESCRIPTION=Interactive historical map for exploring places, people and events through time."
set "TT_REPO_TOPICS=history,maplibre,javascript,openstreetmap,github-pages,education,timeline"

set "SCRIPT=%~dp0scripts\github-bootstrap.ps1"
set "LOG_FILE=%~dp0github-bootstrap.log"

echo ============================================================
echo TimeTrail GitHub Bootstrap
echo ============================================================
echo [CHECK] Project folder: %CD%
echo [CHECK] Log file: %LOG_FILE%
echo.

if not exist "%SCRIPT%" goto :missing_script
where powershell.exe >nul 2>nul
if errorlevel 1 goto :missing_powershell

echo [CHECK] Starting PowerShell deployment engine...
echo.
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT%"
set "EXIT_CODE=%ERRORLEVEL%"
goto :finish

:missing_script
echo [ERROR] scripts\github-bootstrap.ps1 was not found.
echo [RECOVERY] Extract the full ZIP first, then run this CMD from the extracted project folder.
set "EXIT_CODE=2"
goto :finish

:missing_powershell
echo [ERROR] powershell.exe was not found.
echo [RECOVERY] Windows PowerShell is required. Repair/install it, then run this CMD again.
set "EXIT_CODE=3"
goto :finish

:finish
echo.
echo ============================================================
if "%EXIT_CODE%"=="0" (
  echo [OK] Bootstrap finished successfully.
  echo [OK] See log: %LOG_FILE%
) else (
  echo [ERROR] Bootstrap failed with exit code %EXIT_CODE%.
  echo [ERROR] This window will stay open.
  echo [RECOVERY] Read the last ERROR line in: %LOG_FILE%
)
echo ============================================================
echo.
pause
exit /b %EXIT_CODE%
