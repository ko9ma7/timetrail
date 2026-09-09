@echo off
setlocal EnableExtensions
cd /d "%~dp0"

title TimeTrail GitHub Bootstrap v1.1.4

rem ============================================================
rem TimeTrail GitHub Bootstrap - Windows CMD wrapper
rem ASCII-only + CRLF by design for cmd.exe compatibility.
rem Leave OWNER/NAME empty to reuse an existing GitHub origin.
rem If no origin exists, NAME defaults to timetrail in PowerShell.
rem ============================================================
set "TT_REPO_OWNER="
set "TT_REPO_NAME="
set "TT_REPO_VISIBILITY=public"
set "TT_REPO_DESCRIPTION=Interactive historical map for exploring places, people and events through time."
set "TT_REPO_TOPICS=history,maplibre,javascript,openstreetmap,github-pages,education,timeline"
set "TT_INITIAL_TAG=v1.1.4"
set "TT_EXPECTED_BUILD=2026-09-09.7"

set "SCRIPT=%~dp0scripts\github-bootstrap.ps1"
set "LOG_FILE=%~dp0github-bootstrap.log"

echo ============================================================
echo TimeTrail GitHub Bootstrap v1.1.4
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
echo [RECOVERY] Do not run this file inside the ZIP preview.
echo [RECOVERY] Right-click the ZIP, choose Extract All, then run this CMD from the extracted project folder.
set "EXIT_CODE=2"
goto :finish

:missing_powershell
echo [ERROR] powershell.exe was not found.
echo [RECOVERY] Windows PowerShell is required. Open Windows Features or repair Windows PowerShell, then run again.
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
