@echo off
title Achme Server Shutdown
setlocal enabledelayedexpansion

:: ============================================================
:: ACHME SERVER - DIRECT STOP (No Menu)
:: Stops all services immediately without showing menu
:: ============================================================

cls
echo.
echo  ============================================================
echo    ACHME SERVER - DIRECT STOP
echo  ============================================================
echo.
echo  Stopping all services immediately...
echo.

call "%~dp0STOP-EVERYTHING.bat"

echo.
echo  ============================================================
echo  [SUCCESS] ALL ACHME SERVICES HAVE BEEN STOPPED
echo  ============================================================
echo.
echo  To restart, double-click: START-ALL.bat
echo.
pause
