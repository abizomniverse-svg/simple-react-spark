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
echo   Showing all logs in 4 tabs: Frontend | Backend | PM2 | Nginx
echo   Services run in background - closing this window does NOT stop them.
echo.
echo   Press Ctrl+C to stop viewing logs.
echo.
echo  ================================================================
echo.

powershell -Command "$ErrorActionPreference='SilentlyContinue'; Write-Host ''; Write-Host '=== RECENT LOGS ===' -ForegroundColor Yellow; Write-Host ''; $tabs = @(@('FRONTEND', '%LOG_DIR%\frontend.log'), @('BACKEND', '%LOG_DIR%\backend-out.log'), @('PM2 ERROR', '%LOG_DIR%\backend-error.log'), @('NGINX', '%LOG_DIR%\nginx-error.log'), @('DNS', '%LOG_DIR%\dns-server.log'), @('NGINX ACCESS', '%LOG_DIR%\nginx-access.log')); foreach ($tab in $tabs) { $name = $tab[0]; $file = $tab[1]; Write-Host ('--- [' + $name + '] Last 3 lines ---') -ForegroundColor Cyan; if (Test-Path $file) { Get-Content $file -Tail 3 } else { Write-Host '  (no log yet)' -ForegroundColor DarkGray }; Write-Host '' }; Write-Host '=== STREAMING ALL LOGS (Ctrl+C to exit) ===' -ForegroundColor Green; Write-Host ''; $files = @(); foreach ($tab in $tabs) { if (Test-Path $tab[1]) { $files += $tab[1] } }; if ($files.Count -gt 0) { Get-Content $files -Wait } else { Write-Host 'No log files found yet. Services may not have started.' -ForegroundColor Red }"
