@echo off
title Achme Enterprise Server
setlocal enabledelayedexpansion

:: ============================================================
:: ACHME ENTERPRISE SERVER - MAIN MENU CONTROLLER
:: ============================================================
:: Local Domain: https://achme.com
:: LAN Access: https://192.168.0.149
:: ============================================================

cls
echo.
echo  ================================================================
echo.
echo     ACHME ENTERPRISE PRIVATE CLOUD SERVER
echo     =========================================
echo     Your PC is now a professional company server
echo     Local Domain:  https://achme.com
echo     LAN Access:    https://192.168.0.149
echo.
echo  ================================================================
echo.
echo   [1] START SERVER - Launch all services (Recommended)
echo   [2] STOP SERVER  - Gracefully shutdown all services
echo   [3] VIEW SERVER STATUS - Check all services
echo   [4] VIEW LOGS - Open server log files
echo   [0] EXIT
echo.
echo  ================================================================
echo.

choice /C 12340 /N /M "  Select option: "

if %errorlevel%==1 goto START
if %errorlevel%==2 goto STOP
if %errorlevel%==3 goto STATUS
if %errorlevel%==4 goto LOGS
if %errorlevel%==5 goto EXIT

:START
cls
echo.
echo  [INFO] Starting Achme Enterprise Server...
echo  [INFO] This will launch: MySQL + Nginx + PM2 Backend + DNS + Frontend
echo.
call "%~dp0START-ALL.bat"
echo.
echo  ================================================================
echo  [SUCCESS] SERVER IS LIVE
echo  ================================================================
echo.
echo   Local Access:  https://achme.com
echo   LAN Access:    https://192.168.0.149
echo   Backend API:   https://achme.com/api/*
echo.
echo   Open browser and navigate to https://achme.com
echo.
echo   Press any key to return to menu...
pause >nul
goto MENU

:STOP
cls
echo.
echo  [INFO] Stopping all Achme services...
echo.
call "%~dp0STOP-EVERYTHING.bat"
echo.
echo   Press any key to return to menu...
pause >nul
goto MENU

:STATUS
cls
echo.
echo  ================================================================
echo   ACHME SERVER STATUS
echo   =====================
echo.

:: Check MySQL
echo   MySQL Database (Port 3306):
powershell -Command "$tcp = New-Object System.Net.Sockets.TcpClient; try { $conn = $tcp.BeginConnect('127.0.0.1', 3306, $null, $null); $wait = $conn.AsyncWaitHandle.WaitOne(1000, $false); if ($wait) { Write-Host '     [OK] ONLINE' -ForegroundColor Green } else { Write-Host '     [OFF] OFFLINE' -ForegroundColor Red }; $tcp.Close() } catch { Write-Host '     [ERR] ERROR' -ForegroundColor Red }"
echo.

:: Check Nginx
echo   Nginx Proxy (Ports 80/443):
powershell -Command "$tcp = New-Object System.Net.Sockets.TcpClient; try { $conn = $tcp.BeginConnect('127.0.0.1', 443, $null, $null); $wait = $conn.AsyncWaitHandle.WaitOne(1000, $false); if ($wait) { Write-Host '     [OK] ONLINE' -ForegroundColor Green } else { Write-Host '     [OFF] OFFLINE' -ForegroundColor Red }; $tcp.Close() } catch { Write-Host '     [ERR] ERROR' -ForegroundColor Red }"
echo.

:: Check Backend
echo   Node Backend (Port 5000):
powershell -Command "$tcp = New-Object System.Net.Sockets.TcpClient; try { $conn = $tcp.BeginConnect('127.0.0.1', 5000, $null, $null); $wait = $conn.AsyncWaitHandle.WaitOne(1000, $false); if ($wait) { Write-Host '     [OK] ONLINE' -ForegroundColor Green } else { Write-Host '     [OFF] OFFLINE' -ForegroundColor Red }; $tcp.Close() } catch { Write-Host '     [ERR] ERROR' -ForegroundColor Red }"
echo.

:: Check PM2
echo   PM2 Process Manager:
where pm2 >nul 2>&1
if %errorLevel% equ 0 (
    pm2 list
) else (
    echo     [!] PM2 not installed
)
echo.

echo  ================================================================
echo.
echo   Press any key to return to menu...
pause >nul
goto MENU

:LOGS
cls
echo.
echo  [INFO] Opening log directory...
if exist "%~dp0Deployment\achme\logs" (
    explorer "%~dp0Deployment\achme\logs"
) else (
    echo  [!] Logs directory not found.
)
echo.
echo   Press any key to return to menu...
pause >nul
goto MENU

:MENU
goto MAIN

:EXIT
cls
echo.
echo  ================================================================
echo   Achme Enterprise Server Controller - Exiting
echo   Services will continue running in background.
echo   Use STOP-EVERYTHING.bat to stop all services.
echo  ================================================================
echo.
timeout /t 2 /nobreak >nul
exit /b

:MAIN
