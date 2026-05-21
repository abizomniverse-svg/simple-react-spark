@echo off
setlocal enabledelayedexpansion

set "PROJECT_DIR=E:\OBSIDIAN\simple-react-spark"
set "LOG_DIR=%PROJECT_DIR%\logs"

cls
echo.
echo  ================================================================
echo.
echo        ACHME COMMUNICATION - LIVE LOG VIEWER
echo        =========================================
echo.
echo  ================================================================
echo.
echo   Showing all logs in real-time.
echo   Services run in background - closing this window does NOT stop them.
echo.
echo   Press Ctrl+C to stop viewing logs.
echo.
echo  ================================================================
echo.

powershell -Command "Write-Host 'Reading recent logs...' -ForegroundColor Yellow; Write-Host ''; $files = @('%LOG_DIR%\backend-out.log', '%LOG_DIR%\backend-error.log', '%LOG_DIR%\frontend.log', '%LOG_DIR%\dns-server.log', '%LOG_DIR%\nginx-error.log', '%LOG_DIR%\nginx-access.log'); foreach ($f in $files) { if (Test-Path $f) { Write-Host ('=== [' + (Split-Path $f -Leaf) + '] Last 5 lines ===') -ForegroundColor Cyan; Get-Content $f -Tail 5 -ErrorAction SilentlyContinue; Write-Host '' } else { Write-Host ('=== [' + (Split-Path $f -Leaf) + '] No log yet ===') -ForegroundColor DarkGray; Write-Host '' } }; Write-Host '=== STREAMING ALL LOGS (Ctrl+C to exit) ===' -ForegroundColor Green; Write-Host ''; Get-Content '%LOG_DIR%\backend-out.log', '%LOG_DIR%\backend-error.log', '%LOG_DIR%\frontend.log', '%LOG_DIR%\dns-server.log', '%LOG_DIR%\nginx-error.log', '%LOG_DIR%\nginx-access.log' -Wait -ErrorAction SilentlyContinue 2>$null"
