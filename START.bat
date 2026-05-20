@echo off
setlocal enabledelayedexpansion

set "PROJECT_DIR=E:\OBSIDIAN\simple-react-spark"
set "BACKEND_DIR=%PROJECT_DIR%\backend"
set "FRONTEND_DIR=%PROJECT_DIR%\frontend"
set "SERVER_DIR=%PROJECT_DIR%\server-deployment"
set "LOG_DIR=%PROJECT_DIR%\logs"

cls
echo.
echo  ================================================================
echo.
echo        ACHME COMMUNICATION - SERVER STARTER
echo        =========================================
echo        Advanced Auto-Check ^| Auto-Fix ^| Auto-Start
echo.
echo  ================================================================
echo.
echo  [INFO] Starting full system check and auto-repair...
echo.

:: ============================================================
:: CREATE LOGS DIR
:: ============================================================
if not exist "%LOG_DIR%" mkdir "%LOG_DIR%"

:: ============================================================
:: 1. CHECK NODE.JS
:: ============================================================
echo  [1/8] Node.js...
node --version >nul 2>&1
if %errorlevel% neq 0 (
    echo  [FAIL] Node.js NOT installed!
    echo  [AUTO] Opening Node.js download page...
    start https://nodejs.org/
    echo.
    echo  Please install Node.js LTS, then run this script again.
    echo.
    pause
    exit /b 1
)
for /f "tokens=*" %%i in ('node --version') do set NODE_VER=%%i
echo  [OK] Node.js %NODE_VER%

:: ============================================================
:: 2. CHECK/INSTALL PM2
:: ============================================================
echo.
echo  [2/8] PM2 Process Manager...
where pm2 >nul 2>&1
if %errorlevel% neq 0 (
    echo  [AUTO] PM2 not found. Installing globally...
    call npm install -g pm2
    if %errorlevel% neq 0 (
        echo  [FAIL] PM2 install failed. Run as Administrator.
        pause
        exit /b 1
    )
    echo  [OK] PM2 installed
) else (
    echo  [OK] PM2 installed
)

:: ============================================================
:: 3. CHECK/INSTALL BACKEND DEPS
:: ============================================================
echo.
echo  [3/8] Backend Dependencies...
if not exist "%BACKEND_DIR%\node_modules\express" (
    echo  [AUTO] Installing backend dependencies...
    cd /d "%BACKEND_DIR%"
    set PUPPETEER_SKIP_DOWNLOAD=true
    call npm install
    set PUPPETEER_SKIP_DOWNLOAD=
    if exist "%BACKEND_DIR%\node_modules\express" (
        echo  [OK] Backend dependencies installed
    ) else (
        echo  [FAIL] Core deps missing after install
        pause
        exit /b 1
    )
) else (
    echo  [OK] Backend dependencies ready
)

:: ============================================================
:: 4. CHECK/INSTALL FRONTEND DEPS
:: ============================================================
echo.
echo  [4/8] Frontend Dependencies...
if not exist "%FRONTEND_DIR%\node_modules\.package-lock.json" (
    echo  [AUTO] Installing frontend dependencies...
    cd /d "%FRONTEND_DIR%"
    call npm install
    if exist "%FRONTEND_DIR%\node_modules\.package-lock.json" (
        echo  [OK] Frontend dependencies installed
    ) else (
        echo  [FAIL] Frontend deps missing after install
        pause
        exit /b 1
    )
) else (
    echo  [OK] Frontend dependencies ready
)

:: ============================================================
:: 5. CHECK/START MYSQL
:: ============================================================
echo.
echo  [5/8] MySQL Database...
tasklist /FI "IMAGENAME eq mysqld.exe" 2>NUL | find /I /N "mysqld.exe">NUL
if %errorLevel% neq 0 (
    echo  [WARN] MySQL not running. Trying to start...
    net start MySQL80 2>nul
    if %errorlevel%==0 (
        echo  [OK] MySQL80 service started
    ) else (
        net start MySQL 2>nul
        if %errorlevel%==0 (
            echo  [OK] MySQL service started
        ) else (
            echo  [WARN] Could not auto-start MySQL
            echo  [INFO] Start manually: Win+R ^> services.msc ^> find MySQL ^> Start
        )
    )
) else (
    echo  [OK] MySQL is running
)

:: Wait for MySQL to be ready
echo  [INFO] Verifying MySQL connection on port 3306...
timeout /t 2 /nobreak >nul
powershell -Command "$tcp = New-Object System.Net.Sockets.TcpClient; try { $tcp.Connect('127.0.0.1', 3306); Write-Host '  [OK] MySQL accepting connections on port 3306'; $tcp.Close() } catch { Write-Host '  [WARN] MySQL not accepting connections yet' }"

:: ============================================================
:: 6. START BACKEND (PM2)
:: ============================================================
echo.
echo  [6/8] Backend API...

:: Kill stale port 5000 process
for /f "tokens=5" %%a in ('netstat -ano ^| findstr ":5000 " ^| findstr "LISTENING"') do (
    echo  [AUTO] Killing stale process on port 5000 (PID: %%a)
    taskkill /F /PID %%a >nul 2>&1
)

cd /d "%PROJECT_DIR%"
pm2 delete achme-backend >nul 2>&1
pm2 start "%SERVER_DIR%\ecosystem.config.js" --only achme-backend --update-env >nul 2>&1
timeout /t 5 /nobreak >nul
pm2 save >nul 2>&1

:: Verify backend is online
pm2 list 2>nul | findstr "achme-backend" | findstr "online" >nul
if %errorlevel% equ 0 (
    echo  [OK] Backend started via PM2
) else (
    echo  [WARN] Backend not online. Checking logs...
    pm2 logs achme-backend --lines 5 --nostream 2>nul
    echo  [INFO] Trying direct start as fallback...
    cd /d "%BACKEND_DIR%"
    start "Achme Backend" /min node server.js
    timeout /t 3 /nobreak >nul
)

:: Verify backend API responds
echo  [INFO] Testing Backend API health...
timeout /t 2 /nobreak >nul
powershell -Command "try { $r = Invoke-WebRequest -Uri 'http://localhost:5000/api/health' -UseBasicParsing -TimeoutSec 5; Write-Host '  [OK] API responding: http://localhost:5000/api/health'; Write-Host ('  Response: ' + $r.Content) } catch { Write-Host '  [WARN] API not responding yet. It may need a few more seconds.' }"

:: ============================================================
:: 7. START DNS SERVER
:: ============================================================
echo.
echo  [7/8] DNS Server...
tasklist /FI "IMAGENAME eq node.exe" 2>NUL | find /I /N "dns-server.js">NUL
if %errorLevel% neq 0 (
    start /b /min node "%SERVER_DIR%\dns-server.js" > "%LOG_DIR%\dns-server.log" 2>&1
    timeout /t 2 /nobreak >nul
    echo  [OK] DNS Server started (port 53 or 5353)
) else (
    echo  [OK] DNS Server already running
)

:: ============================================================
:: 8. START FRONTEND (VITE)
:: ============================================================
echo.
echo  [8/8] Frontend (Vite)...

:: Kill stale port 5173 process
for /f "tokens=5" %%a in ('netstat -ano ^| findstr ":5173 " ^| findstr "LISTENING"') do (
    echo  [AUTO] Killing stale process on port 5173 (PID: %%a)
    taskkill /F /PID %%a >nul 2>&1
)

tasklist /FI "WINDOWTITLE eq Achme Frontend*" 2>NUL | find /I /N "Achme Frontend">NUL
if %errorLevel% neq 0 (
    cd /d "%FRONTEND_DIR%"
    start "Achme Frontend" /min cmd /c "title Achme Frontend ^&^& npm run dev > \"%LOG_DIR%\frontend.log\" 2>&1"
    timeout /t 5 /nobreak >nul
    echo  [OK] Frontend starting on port 5173
) else (
    echo  [OK] Frontend already running
)

:: ============================================================
:: GET LAN IP
:: ============================================================
for /f "tokens=2 delims=:" %%a in ('ipconfig ^| findstr /r "IPv4.*192\.168\."') do set LAN_IP=%%a
set LAN_IP=%LAN_IP: =%
if "%LAN_IP%"=="" (
    for /f "tokens=2 delims=:" %%a in ('ipconfig ^| findstr /r "IPv4.*10\."') do set LAN_IP=%%a
    set LAN_IP=%LAN_IP: =%
)
if "%LAN_IP%"=="" set LAN_IP=YOUR_PC_IP

:: ============================================================
:: WAIT FOR ALL SERVICES TO BE READY
:: ============================================================
echo.
echo  [INFO] Waiting for all services to stabilize...
timeout /t 5 /nobreak >nul

:: ============================================================
:: FINAL STATUS DISPLAY
:: ============================================================
cls
echo.
echo  ================================================================
echo.
echo        ACHME COMMUNICATION - ALL SERVICES RUNNING
echo        ============================================
echo.
echo  ================================================================
echo.
echo   SERVICE STATUS
echo   ================================================================
echo.

:: Backend
pm2 list 2>nul | findstr "achme-backend" >nul
if %errorlevel% equ 0 (
    echo   [OK] Backend API        Port 5000    http://localhost:5000
) else (
    echo   [!!] Backend API        Port 5000    FAILED - check logs
)

:: Frontend
tasklist /FI "WINDOWTITLE eq Achme Frontend*" 2>NUL | find /I /N "Achme Frontend">NUL
if %errorLevel% equ 0 (
    echo   [OK] Frontend (Vite)    Port 5173    http://localhost:5173
) else (
    echo   [!!] Frontend (Vite)    Port 5173    FAILED - check logs
)

:: MySQL
tasklist /FI "IMAGENAME eq mysqld.exe" 2>NUL | find /I /N "mysqld.exe">NUL
if %errorLevel% equ 0 (
    echo   [OK] MySQL Database     Port 3306    127.0.0.1:3306
) else (
    echo   [!!] MySQL Database     Port 3306    NOT RUNNING
)

:: DNS
tasklist /FI "IMAGENAME eq node.exe" 2>NUL | find /I /N "dns-server.js">NUL
if %errorLevel% equ 0 (
    echo   [OK] DNS Server         Port 53/5353 achme.com ^> %LAN_IP%
) else (
    echo   [!!] DNS Server         Port 53/5353 NOT RUNNING
)

echo.
echo  ================================================================
echo.
echo   ACCESS URLS
echo   ================================================================
echo.
echo   LOCAL ACCESS (this PC):
echo     Frontend:       http://localhost:5173
echo     Backend API:    http://localhost:5000/api/health
echo     Admin Login:    http://localhost:5173/login
echo.
echo   LAN ACCESS (other devices):
echo     Frontend:       http://%LAN_IP%:5173
echo     Backend API:    http://%LAN_IP%:5000/api/health
echo.
echo   Your PC IP: %LAN_IP%
echo.
echo  ================================================================
echo.
echo   ADMIN CREDENTIALS
echo   ================================================================
echo     Email:    Kk@achmecommunication.com
echo     Password: admin123
echo.
echo  ================================================================
echo.
echo   DATABASE
echo   ================================================================
echo     Host:     127.0.0.1
echo     Port:     3306
echo     User:     root
echo     Pass:     admin@123
echo     DB:       achme
echo.
echo  ================================================================
echo.
echo   API ENDPOINTS
echo   ================================================================
echo     GET  /api/health          - Health check
echo     POST /api/auth/login      - Login
echo     GET  /api/client          - List clients
echo     POST /api/client          - Create client
echo     GET  /api/invoice         - List invoices
echo     POST /api/invoice         - Create invoice
echo     GET  /api/quotations      - List quotations
echo     GET  /api/Telecalls       - Telecalling
echo     GET  /api/Walkins         - Walk-ins
echo     GET  /api/task            - Tasks
echo     GET  /api/payments        - Payments
echo     GET  /api/estimate        - Estimates
echo     GET  /api/contract        - Contracts
echo     GET  /api/amc             - AMC records
echo     GET  /api/reports         - Reports
echo     WS   /socket.io/          - Real-time chat
echo.
echo  ================================================================
echo.
echo   LOG FILES
echo   ================================================================
echo     Backend:    %LOG_DIR%\backend-out.log
echo     Backend:    %LOG_DIR%\backend-error.log
echo     Frontend:   %LOG_DIR%\frontend.log
echo     DNS:        %LOG_DIR%\dns-server.log
echo.
echo  ================================================================
echo.
echo   USEFUL COMMANDS
echo   ================================================================
echo     pm2 list                    - Show all PM2 processes
echo     pm2 logs achme-backend      - Live backend logs
echo     pm2 restart achme-backend   - Restart backend
echo     pm2 monit                   - Monitor dashboard
echo.
echo     netstat -ano ^| findstr :5000  - Check port 5000
echo     netstat -ano ^| findstr :5173  - Check port 5173
echo.
echo  ================================================================
echo.
echo   Services run in BACKGROUND. Closing this window does NOT stop them.
echo   Services stop ONLY when PC shuts down.
echo.
echo   Press Ctrl+C to stop live logs (services keep running).
echo.
echo  ================================================================
echo.

:: ============================================================
:: LIVE LOG VIEWER
:: ============================================================
echo  --- LIVE LOGS (Backend + Frontend + DNS) ---
echo.

powershell -Command "Write-Host 'Reading recent logs...' -ForegroundColor Yellow; Start-Sleep -Seconds 1; $files = @('%LOG_DIR%\backend-out.log', '%LOG_DIR%\frontend.log', '%LOG_DIR%\dns-server.log'); foreach ($f in $files) { if (Test-Path $f) { Write-Host ('[' + (Split-Path $f -Leaf) + ']') -ForegroundColor Cyan; Get-Content $f -Tail 3 -ErrorAction SilentlyContinue; Write-Host '' } }; Write-Host '--- Streaming new entries (Ctrl+C to exit, services keep running) ---' -ForegroundColor Green; Write-Host ''; Get-Content '%LOG_DIR%\backend-out.log', '%LOG_DIR%\frontend.log', '%LOG_DIR%\dns-server.log' -Wait -ErrorAction SilentlyContinue 2>$null"
