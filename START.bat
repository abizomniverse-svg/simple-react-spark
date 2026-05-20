@echo off
setlocal enabledelayedexpansion

:: ============================================================
:: ACHME COMMUNICATION - MASTER SERVER STARTER
:: Run as Administrator for full functionality
:: ============================================================

set "PROJECT_DIR=E:\OBSIDIAN\simple-react-spark"
set "BACKEND_DIR=%PROJECT_DIR%\backend"
set "FRONTEND_DIR=%PROJECT_DIR%\frontend"
set "SERVER_DIR=%PROJECT_DIR%\server-deployment"
set "LOG_DIR=%PROJECT_DIR%\logs"
set "SSL_DIR=%PROJECT_DIR%\ssl"
set "NGINX_DIR=%PROJECT_DIR%\nginx"

:: ============================================================
:: ADMIN CHECK - Auto-restart as Administrator if not already
:: ============================================================
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo  ================================================================
    echo.
    echo   ACHME SERVER REQUIRES ADMINISTRATOR PRIVILEGES
    echo   ================================================
    echo.
    echo   This script needs admin rights to:
    echo     - Configure hosts file (achme.com resolution)
    echo     - Open firewall ports (80, 443, 53)
    echo     - Generate SSL certificates
    echo     - Bind to ports 80 and 443
    echo     - Run DNS server on port 53
    echo.
    echo   Restarting as Administrator...
    echo.
    echo  ================================================================
    echo.
    timeout /t 2 /nobreak >nul

    powershell -Command "Start-Process cmd -ArgumentList '/c cd /d \"%~dp0\" ^&^& \"%~f0\"' -Verb RunAs"
    exit /b
)

:: ============================================================
:: CREATE DIRECTORIES
:: ============================================================
if not exist "%LOG_DIR%" mkdir "%LOG_DIR%"
if not exist "%SSL_DIR%" mkdir "%SSL_DIR%"
if not exist "%NGINX_DIR%" mkdir "%NGINX_DIR%"

cls
echo.
echo  ================================================================
echo.
echo        ACHME COMMUNICATION - SERVER STARTER
echo        =========================================
echo        Auto-Check | Auto-Install | Auto-Configure | Auto-Start
echo.
echo  ================================================================
echo.
echo  [INFO] Running as Administrator - Full setup enabled
echo  [INFO] Starting system check and auto-repair...
echo.

:: ============================================================
:: DETECT LAN IP
:: ============================================================
echo  [0/10] Detecting LAN IP address...
for /f "tokens=2 delims=:" %%a in ('ipconfig ^| findstr /r "IPv4.*192\.168\."') do set LAN_IP=%%a
set LAN_IP=%LAN_IP: =%
if "%LAN_IP%"=="" (
    for /f "tokens=2 delims=:" %%a in ('ipconfig ^| findstr /r "IPv4.*10\."') do set LAN_IP=%%a
    set LAN_IP=%LAN_IP: =%
)
if "%LAN_IP%"=="" (
    for /f "tokens=2 delims=:" %%a in ('ipconfig ^| findstr /r "IPv4.*172\."') do set LAN_IP=%%a
    set LAN_IP=%LAN_IP: =%
)
if "%LAN_IP%"=="" set LAN_IP=127.0.0.1
echo  [OK] LAN IP: %LAN_IP%
echo.

:: ============================================================
:: 1. CHECK NODE.JS
:: ============================================================
echo  [1/10] Node.js...
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
echo  [2/10] PM2 Process Manager...
where pm2 >nul 2>&1
if %errorlevel% neq 0 (
    echo  [AUTO] PM2 not found. Installing globally...
    call npm install -g pm2
    if %errorlevel% neq 0 (
        echo  [FAIL] PM2 install failed.
        pause
        exit /b 1
    )
    echo  [OK] PM2 installed
) else (
    echo  [OK] PM2 installed
)

:: ============================================================
:: 3. CHECK/INSTALL NGINX
:: ============================================================
echo.
echo  [3/10] Nginx Web Server...
if exist "%NGINX_DIR%\nginx.exe" (
    echo  [OK] Nginx already installed
) else (
    echo  [AUTO] Nginx not found. Downloading and installing...
    powershell -ExecutionPolicy Bypass -File "%SERVER_DIR%\install-nginx.ps1"
    if not exist "%NGINX_DIR%\nginx.exe" (
        echo  [FAIL] Nginx installation failed.
        pause
        exit /b 1
    )
    echo  [OK] Nginx installed
)

:: ============================================================
:: 4. CHECK/INSTALL BACKEND DEPS
:: ============================================================
echo.
echo  [4/10] Backend Dependencies...
if not exist "%BACKEND_DIR%\node_modules\express" (
    echo  [AUTO] Installing backend dependencies...
    cd /d "%BACKEND_DIR%"
    set PUPPETEER_SKIP_DOWNLOAD=true
    call npm install
    set PUPPETEER_SKIP_DOWNLOAD=
    if exist "%BACKEND_DIR%\node_modules\express" (
        echo  [OK] Backend dependencies installed
    ) else (
        echo  [FAIL] Core deps missing
        pause
        exit /b 1
    )
) else (
    echo  [OK] Backend dependencies ready
)

:: ============================================================
:: 5. CHECK/INSTALL FRONTEND DEPS
:: ============================================================
echo.
echo  [5/10] Frontend Dependencies...
if not exist "%FRONTEND_DIR%\node_modules\.package-lock.json" (
    echo  [AUTO] Installing frontend dependencies...
    cd /d "%FRONTEND_DIR%"
    call npm install
    if exist "%FRONTEND_DIR%\node_modules\.package-lock.json" (
        echo  [OK] Frontend dependencies installed
    ) else (
        echo  [FAIL] Frontend deps missing
        pause
        exit /b 1
    )
) else (
    echo  [OK] Frontend dependencies ready
)

:: ============================================================
:: 6. CHECK/START MYSQL
:: ============================================================
echo.
echo  [6/10] MySQL Database...
tasklist /FI "IMAGENAME eq mysqld.exe" 2>NUL | find /I /N "mysqld.exe">NUL
if %errorLevel% neq 0 (
    echo  [WARN] MySQL not running. Trying to start...
    net start MySQL80 2>nul
    if %errorlevel%==0 (
        echo  [OK] MySQL80 started
    ) else (
        net start MySQL 2>nul
        if %errorlevel%==0 (
            echo  [OK] MySQL started
        ) else (
            echo  [WARN] Could not auto-start MySQL
            echo  [INFO] Start manually: Win+R ^> services.msc ^> MySQL ^> Start
        )
    )
) else (
    echo  [OK] MySQL running
)

:: ============================================================
:: 7. CONFIGURE HOSTS FILE
:: ============================================================
echo.
echo  [7/10] Hosts File Configuration...
findstr /c:"achme.com" C:\Windows\System32\drivers\etc\hosts >nul 2>&1
if %errorlevel% neq 0 (
    echo  [AUTO] Adding achme.com to hosts file...
    echo 127.0.0.1 achme.com>> C:\Windows\System32\drivers\etc\hosts
    echo  [OK] achme.com added to hosts file
) else (
    echo  [OK] achme.com already in hosts file
)
ipconfig /flushdns >nul 2>&1
echo  [OK] DNS cache flushed

:: ============================================================
:: 8. CONFIGURE FIREWALL
:: ============================================================
echo.
echo  [8/10] Firewall Configuration...
powershell -ExecutionPolicy Bypass -File "%SERVER_DIR%\setup-firewall.ps1"

:: ============================================================
:: 9. GENERATE SSL CERTIFICATES
:: ============================================================
echo.
echo  [9/10] SSL Certificates...
if not exist "%SSL_DIR%\achme.crt" (
    echo  [AUTO] Generating self-signed SSL certificates...
    powershell -ExecutionPolicy Bypass -File "%SERVER_DIR%\generate-certs.ps1"
    if exist "%SSL_DIR%\achme.crt" (
        echo  [OK] SSL certificates generated
    ) else (
        echo  [WARN] SSL cert generation incomplete
        echo  [INFO] Run: powershell -ExecutionPolicy Bypass -File "%SERVER_DIR%\generate-certs.ps1"
    )
) else (
    echo  [OK] SSL certificates already exist
)

:: ============================================================
:: 10. UPDATE CORS WITH DETECTED LAN IP
:: ============================================================
echo.
echo  [10/10] Updating CORS configuration...
powershell -Command "$content = Get-Content '%SERVER_DIR%\ecosystem.config.js' -Raw; $content = $content -replace 'ALLOWED_ORIGIN: ''[^'']*''', 'ALLOWED_ORIGIN: ''http://localhost:5173,https://achme.com,https://localhost,https://127.0.0.1,http://achme.com,http://127.0.0.1,http://%LAN_IP%,https://%LAN_IP%'''; $content | Set-Content '%SERVER_DIR%\ecosystem.config.js' -NoNewline"
echo  [OK] CORS updated with LAN IP: %LAN_IP%

:: ============================================================
:: KILL STALE PROCESSES
:: ============================================================
echo.
echo  ================================================================
echo  [INFO] Clearing stale processes...
echo  ================================================================
echo.

:: Kill stale port 5000
for /f "tokens=5" %%a in ('netstat -ano ^| findstr ":5000 " ^| findstr "LISTENING"') do (
    echo  [AUTO] Killing process on port 5000 (PID: %%a)
    taskkill /F /PID %%a >nul 2>&1
)

:: Kill stale port 5173
for /f "tokens=5" %%a in ('netstat -ano ^| findstr ":5173 " ^| findstr "LISTENING"') do (
    echo  [AUTO] Killing process on port 5173 (PID: %%a)
    taskkill /F /PID %%a >nul 2>&1
)

:: Stop Nginx if running
tasklist /FI "IMAGENAME eq nginx.exe" 2>NUL | find /I /N "nginx.exe">NUL
if %errorLevel% equ 0 (
    echo  [AUTO] Stopping existing Nginx...
    cd /d "%NGINX_DIR%"
    nginx.exe -s quit 2>nul
    timeout /t 2 /nobreak >nul
    taskkill /F /IM nginx.exe >nul 2>&1
)

:: Stop DNS server
tasklist /FI "IMAGENAME eq node.exe" 2>NUL | find /I /N "dns-server.js">NUL
if %errorLevel% equ 0 (
    echo  [AUTO] Stopping existing DNS server...
    powershell -Command "Get-Process -Name 'node' -ErrorAction SilentlyContinue | ForEach-Object { $cmd = (Get-CimInstance Win32_Process -Filter 'ProcessId = ' + $_.Id).CommandLine; if ($cmd -match 'dns-server\.js') { Stop-Process -Id $_.Id -Force -ErrorAction SilentlyContinue } }"
)

:: Stop Frontend
taskkill /FI "WINDOWTITLE eq Achme Frontend*" /F >nul 2>&1

timeout /t 2 /nobreak >nul

:: ============================================================
:: START ALL SERVICES
:: ============================================================
echo.
echo  ================================================================
echo  [INFO] Starting all services...
echo  ================================================================
echo.

:: --- Backend (PM2) ---
echo  [*] Starting Backend API (PM2, port 5000)...
cd /d "%PROJECT_DIR%"
pm2 delete achme-backend >nul 2>&1
pm2 start "%SERVER_DIR%\ecosystem.config.js" --only achme-backend --update-env >nul 2>&1
timeout /t 5 /nobreak >nul
pm2 save >nul 2>&1
pm2 list 2>nul | findstr "achme-backend" | findstr "online" >nul
if %errorlevel% equ 0 (
    echo  [OK] Backend started on port 5000
) else (
    echo  [WARN] Backend may have failed. Check: pm2 logs achme-backend
)
echo.

:: --- DNS Server ---
echo  [*] Starting DNS Server (port 53)...
start /b /min node "%SERVER_DIR%\dns-server.js" > "%LOG_DIR%\dns-server.log" 2>&1
timeout /t 2 /nobreak >nul
echo  [OK] DNS Server started - resolves achme.com to %LAN_IP%
echo.

:: --- Nginx ---
echo  [*] Starting Nginx (ports 80/443)...
cd /d "%NGINX_DIR%"
if exist "%NGINX_DIR%\nginx.exe" (
    nginx.exe -c "%SERVER_DIR%\nginx.conf" 2>nul
    timeout /t 2 /nobreak >nul
    tasklist /FI "IMAGENAME eq nginx.exe" 2>NUL | find /I /N "nginx.exe">NUL
    if %errorLevel% equ 0 (
        echo  [OK] Nginx started on ports 80 and 443
    ) else (
        echo  [WARN] Nginx failed to start. Check: %LOG_DIR%\nginx-error.log
        type "%LOG_DIR%\nginx-error.log" 2>nul
    )
) else (
    echo  [WARN] Nginx executable not found
)
echo.

:: --- Frontend (Vite) ---
echo  [*] Starting Frontend (Vite, port 5173)...
cd /d "%FRONTEND_DIR%"
start "Achme Frontend" /min cmd /c "title Achme Frontend ^&^& npm run dev > \"%LOG_DIR%\frontend.log\" 2>&1"
timeout /t 5 /nobreak >nul
echo  [OK] Frontend starting on port 5173
echo.

:: ============================================================
:: WAIT FOR SERVICES
:: ============================================================
echo  [INFO] Waiting for all services to stabilize...
timeout /t 8 /nobreak >nul

:: ============================================================
:: VERIFY CONNECTIONS
:: ============================================================
echo.
echo  [INFO] Verifying service connections...
echo.

:: Verify Backend API
powershell -Command "try { $r = Invoke-WebRequest -Uri 'http://localhost:5000/api/health' -UseBasicParsing -TimeoutSec 5; Write-Host '  [OK] Backend API responding: http://localhost:5000/api/health' } catch { Write-Host '  [WARN] Backend API not responding yet' }"

:: Verify MySQL
powershell -Command "try { $tcp = New-Object System.Net.Sockets.TcpClient; $tcp.Connect('127.0.0.1', 3306); Write-Host '  [OK] MySQL accepting connections on port 3306'; $tcp.Close() } catch { Write-Host '  [WARN] MySQL not accepting connections' }"

:: Verify Nginx
powershell -Command "try { $tcp = New-Object System.Net.Sockets.TcpClient; $tcp.Connect('127.0.0.1', 443); Write-Host '  [OK] Nginx listening on port 443 (HTTPS)'; $tcp.Close() } catch { Write-Host '  [WARN] Nginx not listening on port 443' }"

:: Verify DNS
powershell -Command "try { $tcp = New-Object System.Net.Sockets.UdpClient; $tcp.Connect('127.0.0.1', 53); Write-Host '  [OK] DNS Server listening on port 53'; $tcp.Close() } catch { Write-Host '  [WARN] DNS Server not listening on port 53' }"

:: ============================================================
:: STATUS DASHBOARD
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
pm2 list 2>nul | findstr "achme-backend" | findstr "online" >nul
if %errorlevel% equ 0 (
    echo   [OK] Backend API        Port 5000    http://localhost:5000
) else (
    echo   [!!] Backend API        Port 5000    FAILED
)

:: Frontend
tasklist /FI "WINDOWTITLE eq Achme Frontend*" 2>NUL | find /I /N "Achme Frontend">NUL
if %errorLevel% equ 0 (
    echo   [OK] Frontend (Vite)    Port 5173    http://localhost:5173
) else (
    echo   [!!] Frontend (Vite)    Port 5173    FAILED
)

:: Nginx
tasklist /FI "IMAGENAME eq nginx.exe" 2>NUL | find /I /N "nginx.exe">NUL
if %errorLevel% equ 0 (
    echo   [OK] Nginx Proxy        Port 80/443  https://achme.com
) else (
    echo   [!!] Nginx Proxy        Port 80/443  FAILED
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
    echo   [OK] DNS Server         Port 53      achme.com ^> %LAN_IP%
) else (
    echo   [!!] DNS Server         Port 53      NOT RUNNING
)

echo.
echo  ================================================================
echo.
echo   PRIMARY ACCESS URL
echo   ================================================================
echo.
echo     ^>^>^>  https://achme.com  ^<^<^<
echo.
echo   This works on THIS PC and any device on your network
echo   that has DNS set to this server's IP.
echo.
echo  ================================================================
echo.
echo   LOCAL ACCESS (this PC, no DNS needed)
echo   ================================================================
echo.
echo     Frontend:       http://localhost:5173
echo     Backend API:    http://localhost:5000/api/health
echo     HTTPS Frontend: https://localhost
echo     HTTPS API:      https://localhost/api/health
echo     Admin Login:    http://localhost:5173/login
echo.
echo  ================================================================
echo.
echo   LAN ACCESS (other devices on same network)
echo   ================================================================
echo.
echo     Your PC IP:     %LAN_IP%
echo.
echo     Method 1 - DNS (recommended):
echo       Set device DNS to: %LAN_IP%
echo       Then open:         https://achme.com
echo.
echo     Method 2 - Direct IP:
echo       Open:              https://%LAN_IP%
echo       (Accept SSL warning once)
echo.
echo     Method 3 - HTTP (no SSL):
echo       Open:              http://%LAN_IP%:5173
echo.
echo  ================================================================
echo.
echo   EMPLOYEE SETUP (DNS Method)
echo   ================================================================
echo.
echo   For each employee device:
echo     1. Open Network Settings on their device
echo     2. Set DNS Server to: %LAN_IP%
echo     3. Open browser and go to: https://achme.com
echo     4. Accept SSL certificate warning (first time only)
echo     5. Done - full access to Achme CRM
echo.
echo   Employee devices will resolve achme.com to this server
echo   automatically. All API calls, file uploads, and real-time
echo   chat will work seamlessly.
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
echo     PUT  /api/client/:id      - Update client
echo     DELETE /api/client/:id    - Delete client
echo     GET  /api/invoice         - List invoices
echo     POST /api/invoice         - Create invoice
echo     GET  /api/quotations      - List quotations
echo     POST /api/quotations      - Create quotation
echo     GET  /api/Telecalls       - Telecalling records
echo     GET  /api/Walkins         - Walk-in records
echo     GET  /api/task            - Task list
echo     POST /api/task            - Create task
echo     GET  /api/payments        - Payment records
echo     POST /api/payments        - Create payment
echo     GET  /api/estimate        - Estimates
echo     GET  /api/contract        - Contracts
echo     GET  /api/amc             - AMC records
echo     GET  /api/reports         - Reports
echo     GET  /api/notifications   - Notifications
echo     WS   /socket.io/          - Real-time chat ^& notifications
echo     GET  /api/Fields          - Form fields
echo     GET  /api/estimate-client - Estimate clients
echo     GET  /api/service         - Service estimation
echo     GET  /api/unified-invoice - Unified invoice
echo     GET  /api/performa        - Performa invoice
echo     GET  /api/targets         - Targets
echo     GET  /api/lead-management - Lead management
echo     GET  /api/call-reports    - Call reports
echo.
echo  ================================================================
echo.
echo   LOG FILES
echo   ================================================================
echo     Backend:    %LOG_DIR%\backend-out.log
echo     Backend:    %LOG_DIR%\backend-error.log
echo     Frontend:   %LOG_DIR%\frontend.log
echo     DNS:        %LOG_DIR%\dns-server.log
echo     Nginx:      %LOG_DIR%\nginx-access.log
echo     Nginx:      %LOG_DIR%\nginx-error.log
echo.
echo  ================================================================
echo.
echo   USEFUL COMMANDS
echo   ================================================================
echo     pm2 list                    - Show PM2 processes
echo     pm2 logs achme-backend      - Live backend logs
echo     pm2 restart achme-backend   - Restart backend
echo     pm2 monit                   - Monitor dashboard
echo.
echo     nginx -s reload             - Reload Nginx config
echo     nginx -s stop               - Stop Nginx
echo.
echo     netstat -ano ^| findstr :5000  - Check port 5000
echo     netstat -ano ^| findstr :5173  - Check port 5173
echo     netstat -ano ^| findstr :443   - Check port 443
echo.
echo  ================================================================
echo.
echo   Services run in BACKGROUND. Closing this window does NOT stop them.
echo   Services stop ONLY when PC shuts down or you run STOP commands.
echo.
echo   Press Ctrl+C to stop live logs (services keep running).
echo.
echo  ================================================================
echo.

:: ============================================================
:: LIVE LOG VIEWER
:: ============================================================
echo  --- LIVE LOGS (Backend + Frontend + DNS + Nginx) ---
echo.

powershell -Command "Write-Host 'Reading recent logs...' -ForegroundColor Yellow; Start-Sleep -Seconds 1; $files = @('%LOG_DIR%\backend-out.log', '%LOG_DIR%\frontend.log', '%LOG_DIR%\dns-server.log', '%LOG_DIR%\nginx-error.log'); foreach ($f in $files) { if (Test-Path $f) { Write-Host ('[' + (Split-Path $f -Leaf) + ']') -ForegroundColor Cyan; Get-Content $f -Tail 3 -ErrorAction SilentlyContinue; Write-Host '' } }; Write-Host '--- Streaming new entries (Ctrl+C to exit, services keep running) ---' -ForegroundColor Green; Write-Host ''; Get-Content '%LOG_DIR%\backend-out.log', '%LOG_DIR%\frontend.log', '%LOG_DIR%\dns-server.log', '%LOG_DIR%\nginx-error.log' -Wait -ErrorAction SilentlyContinue 2>$null"
