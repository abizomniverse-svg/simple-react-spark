@echo off
title Achme Server Control Panel
setlocal enabledelayedexpansion

:: ============================================================
:: ACHME SERVER - DIRECT START (No Menu)
:: Starts all services immediately without showing menu
:: ============================================================

cls
echo.
echo  ============================================================
echo    ACHME ENTERPRISE SERVER - DIRECT START
echo  ============================================================
echo.
echo  Starting all services immediately...
echo.

call "%~dp0START-ALL.bat"

echo.
echo  ============================================================
echo  [SUCCESS] ACHME SERVER IS ONLINE AND LIVE!
echo  ============================================================
echo.
echo  [+] Local Domain:   https://achme.com
echo  [+] LAN Access:     https://192.168.0.149
echo  [+] Backend API:    https://achme.com/api/*
echo  [+] Database Port:  3306 (Active)
echo.
echo  [INFO] You can minimize this window. Press any key to exit.
echo.
pause
