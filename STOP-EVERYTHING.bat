@echo off
title Achme Server - Stop All Services
setlocal enabledelayedexpansion

:: ============================================================
:: ACHME SERVER - STOP ALL SERVICES
:: Run this file to stop all services gracefully
:: ============================================================

cls
echo.
echo  ============================================
echo    ACHME SERVER - STOPPING ALL SERVICES
echo  ============================================
echo.

:: 1. Stop Nginx
echo  [1/5] Stopping Nginx...
tasklist /FI "IMAGENAME eq nginx.exe" 2>NUL | find /I /N "nginx.exe">NUL
if %errorLevel% equ 0 (
    cd /d "%~dp0Deployment\nginx"
    nginx.exe -s quit 2>nul
    timeout /t 2 /nobreak >nul
    tasklist /FI "IMAGENAME eq nginx.exe" 2>NUL | find /I /N "nginx.exe">NUL
    if %errorLevel% equ 0 (
        taskkill /F /IM nginx.exe >nul 2>&1
    )
    echo  [OK] Nginx stopped
) else (
    echo  [SKIP] Nginx not running
)
echo.

:: 2. Stop Backend (PM2)
echo  [2/5] Stopping Backend...
cd /d "%~dp0Deployment\achme"
pm2 stop achme-backend 2>nul
pm2 delete achme-backend 2>nul
echo  [OK] Backend stopped
echo.

:: 3. Stop DNS Server
echo  [3/5] Stopping DNS Server...
powershell -Command "Get-Process -Name 'node' -ErrorAction SilentlyContinue | ForEach-Object { $cmd = (Get-CimInstance Win32_Process -Filter 'ProcessId = ' + $_.Id).CommandLine; if ($cmd -match 'dns-server\.js') { Stop-Process -Id $_.Id -Force -ErrorAction SilentlyContinue } }"
echo  [OK] DNS Server stopped
echo.

:: 4. Stop Frontend
echo  [4/5] Stopping Frontend...
taskkill /FI "WINDOWTITLE eq Achme Frontend*" /F >nul 2>&1
echo  [OK] Frontend stopped
echo.

:: 5. Stop MySQL (optional - comment out to keep running)
echo  [5/5] Stopping MySQL...
net stop MySQL80 2>nul
if %errorlevel%==0 (
    echo  [OK] MySQL stopped
) else (
    echo  [SKIP] MySQL not running or already stopped
)
echo.

echo  ============================================
echo   ALL SERVICES STOPPED
echo  ============================================
echo.
echo   To restart, double-click: START-ALL.bat
echo.
pause
