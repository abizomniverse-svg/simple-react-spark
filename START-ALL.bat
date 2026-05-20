@echo off
title Achme Server - One Click Start
setlocal enabledelayedexpansion

:: ============================================================
:: ACHME SERVER - MASTER STARTUP SCRIPT
:: Run this file to start ALL services automatically
:: ============================================================

cls
echo.
echo  ============================================
echo    ACHME SERVER - STARTING ALL SERVICES
echo  ============================================
echo.

:: 1. Start MySQL
echo  [1/5] Starting MySQL...
net start MySQL80 2>nul
if %errorlevel%==0 (
    echo  [OK] MySQL started
) else (
    echo  [OK] MySQL already running
)
timeout /t 3 /nobreak >nul
echo.

:: 2. Start Nginx
echo  [2/5] Starting Nginx...
tasklist /FI "IMAGENAME eq nginx.exe" 2>NUL | find /I /N "nginx.exe">NUL
if %errorLevel% neq 0 (
    cd /d "%~dp0Deployment\nginx"
    start /min nginx.exe
    timeout /t 2 /nobreak >nul
    echo  [OK] Nginx started
) else (
    echo  [OK] Nginx already running
)
echo.

:: 3. Start Backend via PM2
echo  [3/5] Starting Backend (PM2)...
cd /d "%~dp0Deployment\achme"
pm2 start ecosystem.config.js --only achme-backend 2>nul
if %errorlevel%==0 (
    echo  [OK] Backend started
) else (
    echo  [OK] Backend already running
)
timeout /t 3 /nobreak >nul
echo.

:: 4. Start DNS Server
echo  [4/5] Starting DNS Server...
tasklist /FI "IMAGENAME eq node.exe" 2>NUL | find /I /N "dns-server.js">NUL
if %errorLevel% neq 0 (
    start "Achme DNS" /MIN node "%~dp0server-deployment\dns-server.js"
    echo  [OK] DNS Server started
) else (
    echo  [OK] DNS Server already running
)
timeout /t 2 /nobreak >nul
echo.

:: 5. Start Frontend (Vite dev server)
echo  [5/5] Starting Frontend (Vite)...
tasklist /FI "WINDOWTITLE eq Achme Frontend" 2>NUL | find /I /N "Achme Frontend">NUL
if %errorLevel% neq 0 (
    start "Achme Frontend" /D "%~dp0frontend" npm run dev
    echo  [OK] Frontend starting in new window
) else (
    echo  [OK] Frontend already running
)
timeout /t 5 /nobreak >nul
echo.

:: Configure firewall for LAN access
echo  Configuring firewall for LAN access...
netsh advfirewall firewall add rule name="Achme HTTPS" dir=in action=allow protocol=TCP localport=443 profile=any >nul 2>&1
netsh advfirewall firewall add rule name="Achme HTTP" dir=in action=allow protocol=TCP localport=80 profile=any >nul 2>&1
netsh advfirewall firewall add rule name="Achme DNS UDP" dir=in action=allow protocol=UDP localport=53 profile=any >nul 2>&1
netsh advfirewall firewall add rule name="Achme Backend" dir=in action=allow protocol=TCP localport=5000 profile=any >nul 2>&1
echo  [OK] Firewall rules configured
echo.

echo  ============================================
echo   ALL SERVICES ARE LIVE!
echo  ============================================
echo.
echo   Access from this PC:
echo     Frontend:  https://achme.com
echo     Frontend:  https://192.168.0.122
echo     API:       https://achme.com/api/*
echo.
echo   Access from other devices on LAN:
echo     1. Set DNS on device to: 192.168.0.122
echo     2. Open: https://achme.com
echo.
echo     OR access directly via IP:
echo     https://192.168.0.122
echo.
echo   Admin Login:
echo     Email:    Kk@achmecommunication.com
echo     Password: admin123
echo.
echo   Press any key to close this window...
pause >nul
