# Strict mode
Set-StrictMode -Version Latest
$ErrorActionPreference = "Continue"

# Configuration
$WorkspaceRoot = Split-Path -Parent $PSScriptRoot
$IsAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if ($IsAdmin) {
    $DeploymentRoot = "C:\Deployment\achme"
    $NginxDir = "C:\nginx"
} else {
    $DeploymentRoot = Join-Path $WorkspaceRoot "Deployment\achme"
    $NginxDir = Join-Path $WorkspaceRoot "Deployment\nginx"
}
$LogFile = Join-Path $DeploymentRoot "logs\startup.log"
$MaxRetries = 5
$RetryIntervalSec = 5

# Helper to write to console and log file
function Write-Log {
    param (
        [string]$Message,
        [string]$Level = "INFO"
    )
    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $LogLine = "[$Timestamp] [$Level] $Message"
    Write-Output $LogLine
    
    try {
        $LogLine | Out-File -FilePath $LogFile -Append -Encoding ascii -ErrorAction SilentlyContinue
    } catch {}
}

# Helper to check if a service is running and start it
function Ensure-ServiceRunning {
    param (
        [string]$ServiceName
    )
    
    Write-Log "Checking Windows Service: $ServiceName..."
    $Service = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue
    
    if (-not $Service) {
        Write-Log "Service '$ServiceName' is not installed on this system." "WARN"
        return $false
    }
    
    if ($Service.Status -ne "Running") {
        if (-not $IsAdmin) {
            Write-Log "Service '$ServiceName' is not running and cannot be started without Administrator privileges." "WARN"
            return $false
        }
        Write-Log "Service '$ServiceName' is not running (Current: $($Service.Status)). Attempting to start..." "WARN"
        try {
            Start-Service -Name $ServiceName -ErrorAction Stop
            
            $Retry = 0
            while ($Retry -lt $MaxRetries) {
                Start-Sleep -Seconds $RetryIntervalSec
                $Service = Get-Service -Name $ServiceName
                if ($Service.Status -eq "Running") {
                    Write-Log "Service '$ServiceName' started successfully." "OK"
                    return $true
                }
                $Retry++
            }
            throw "Service failed to transition to Running state."
        } catch {
            Write-Log "Failed to start service '$ServiceName': $_" "ERROR"
            return $false
        }
    } else {
        Write-Log "Service '$ServiceName' is already running." "OK"
        return $true
    }
}

# Kill only our specific backend processes (targeted)
function Stop-OurBackend {
    $NodeProcs = Get-Process -Name "node" -ErrorAction SilentlyContinue
    foreach ($P in $NodeProcs) {
        try {
            $CmdLine = (Get-CimInstance Win32_Process -Filter "ProcessId = $($P.Id)" -ErrorAction SilentlyContinue).CommandLine
            if ($CmdLine -match "server\.js") {
                Write-Log "Stopping backend node process (PID: $($P.Id))..."
                Stop-Process -Id $P.Id -Force -ErrorAction SilentlyContinue
            }
        } catch {}
    }
    # Also stop PM2 achme-backend if running
    $Pm2Check = Get-Command "pm2" -ErrorAction SilentlyContinue
    if ($Pm2Check) {
        & pm2 delete achme-backend >$null 2>&1
    }
    Start-Sleep -Seconds 1
}

try {
    Write-Log "========================================"
    Write-Log "Initializing Achme Server Startup Watchdog..."

    # 1. Ensure MySQL is running
    $MySqlNames = @("MySQL80", "MySQL", "mysql")
    $MySqlStarted = $false
    foreach ($Name in $MySqlNames) {
        $Check = Get-Service -Name $Name -ErrorAction SilentlyContinue
        if ($Check) {
            $MySqlStarted = Ensure-ServiceRunning -ServiceName $Name
            break
        }
    }
    if (-not $MySqlStarted) {
        Write-Log "MySQL Service check complete, but no active MySQL service could be verified. If using Docker or custom database, verify port 3306." "WARN"
    }

    # 2. Ensure Tailscale is running
    Ensure-ServiceRunning -ServiceName "Tailscale" | Out-Null

    # 3. Perform Self-Healing Local Connection / Port Audit Health Checks
    Write-Log "Performing connection audits on required local ports..."

    # MySQL Port Audit (3306)
    try {
        $Tcp = New-Object System.Net.Sockets.TcpClient
        $Connect = $Tcp.BeginConnect("127.0.0.1", 3306, $null, $null)
        $Wait = $Connect.AsyncWaitHandle.WaitOne(2000, $false)
        if (-not $Wait) {
            Write-Log "Port 3306 (MySQL Database) is NOT responding (Timeout). Please verify MySQL database status." "ERROR"
        } else {
            $Tcp.EndConnect($Connect)
            Write-Log "Port 3306 (MySQL Database) is ACTIVE and responding." "OK"
        }
        $Tcp.Close()
    } catch {
        Write-Log "Port 3306 (MySQL Database) check failed: $_" "ERROR"
    }

    # Node Backend API Port Audit (5000)
    $BackendOk = $false
    try {
        $Tcp = New-Object System.Net.Sockets.TcpClient
        $Connect = $Tcp.BeginConnect("127.0.0.1", 5000, $null, $null)
        $Wait = $Connect.AsyncWaitHandle.WaitOne(2000, $false)
        if ($Wait) {
            $Tcp.EndConnect($Connect)
            Write-Log "Port 5000 (Node Backend API) is ACTIVE and responding." "OK"
            $BackendOk = $true
        }
        $Tcp.Close()
    } catch {}

    if (-not $BackendOk) {
        Write-Log "Port 5000 (Node Backend API) is NOT responding. Initiating backend self-healing..." "WARN"
        
        # Kill only our specific backend processes
        Stop-OurBackend

        # Attempt recovery via PM2
        $Pm2Check = Get-Command "pm2" -ErrorAction SilentlyContinue
        if ($Pm2Check) {
            try {
                Write-Log "Attempting recovery via 'pm2 resurrect'..."
                & pm2 resurrect 2>&1 | Out-String -Stream | ForEach-Object { Write-Log "PM2: $_" }
                Start-Sleep -Seconds 5
                
                $Tcp = New-Object System.Net.Sockets.TcpClient
                $Connect = $Tcp.BeginConnect("127.0.0.1", 5000, $null, $null)
                $Wait = $Connect.AsyncWaitHandle.WaitOne(2000, $false)
                if ($Wait) {
                    $Tcp.EndConnect($Connect)
                    Write-Log "Backend successfully recovered via PM2 resurrect." "OK"
                    $BackendOk = $true
                }
                $Tcp.Close()
            } catch {
                Write-Log "PM2 resurrect recovery failed: $_" "WARN"
            }
        }

        # Fallback: Direct PM2 start from ecosystem config
        if (-not $BackendOk) {
            try {
                $EcosystemPath = Join-Path $DeploymentRoot "ecosystem.config.js"
                if (Test-Path -LiteralPath $EcosystemPath) {
                    Write-Log "Attempting recovery via 'pm2 start ecosystem.config.js'..."
                    & pm2 start $EcosystemPath 2>&1 | Out-String -Stream | ForEach-Object { Write-Log "PM2: $_" }
                    & pm2 save 2>&1 | Out-String -Stream | ForEach-Object { Write-Log "PM2: $_" }
                    Start-Sleep -Seconds 5
                    
                    $Tcp = New-Object System.Net.Sockets.TcpClient
                    $Connect = $Tcp.BeginConnect("127.0.0.1", 5000, $null, $null)
                    $Wait = $Connect.AsyncWaitHandle.WaitOne(2000, $false)
                    if ($Wait) {
                        $Tcp.EndConnect($Connect)
                        Write-Log "Backend successfully recovered via PM2 ecosystem start." "OK"
                        $BackendOk = $true
                    }
                    $Tcp.Close()
                }
            } catch {
                Write-Log "PM2 ecosystem start recovery failed: $_" "WARN"
            }
        }

        # Last resort: Direct background Node.js
        if (-not $BackendOk) {
            Write-Log "PM2 recovery failed. Executing direct background Node.js recovery..." "WARN"
            $env:NODE_ENV = 'production'
            $env:PORT = 5000
            $env:ALLOWED_ORIGIN = 'https://achme.com'
            $env:DB_HOST = '127.0.0.1'
            $env:DB_PORT = 3306
            $env:DB_USER = 'root'
            $env:DB_PASS = 'admin@123'
            $env:DB_NAME = 'achme'
            $env:JWT_SECRET = '97418d0c15d57ade768586b8501e35d34e5a5277f2a0570b6d5b47ef93f5b33e88b80045c60efd77e6edcbb015dbe46cf6747ce1dd8f11361f3e426ddc677c9a'
            $env:SMTP_HOST = 'smtp.gmail.com'
            $env:SMTP_PORT = 587
            $env:EMAIL_USER = 'thanan757@gmail.com'
            $env:EMAIL_PASS = 'ghjv omqm hwji kerq'

            $BackendPath = Join-Path $DeploymentRoot "backend"
            Write-Log "Starting background node.exe server.js from $BackendPath..."
            Start-Process -FilePath "node.exe" -ArgumentList "server.js" -WorkingDirectory $BackendPath -WindowStyle Hidden
            
            Start-Sleep -Seconds 5
            try {
                $Tcp = New-Object System.Net.Sockets.TcpClient
                $Connect = $Tcp.BeginConnect("127.0.0.1", 5000, $null, $null)
                $Wait = $Connect.AsyncWaitHandle.WaitOne(2000, $false)
                if ($Wait) {
                    $Tcp.EndConnect($Connect)
                    Write-Log "Backend successfully recovered via direct background node.exe." "OK"
                    $BackendOk = $true
                }
                $Tcp.Close()
            } catch {
                Write-Log "Backend port 5000 check failed after direct node recovery: $_" "ERROR"
            }
        }
    }

    # Nginx Port Audit (80 & 443)
    $NginxOk = $false
    try {
        $Tcp80 = New-Object System.Net.Sockets.TcpClient
        $Connect80 = $Tcp80.BeginConnect("127.0.0.1", 80, $null, $null)
        $Wait80 = $Connect80.AsyncWaitHandle.WaitOne(1000, $false)
        if ($Wait80) {
            $Tcp80.EndConnect($Connect80)
            $NginxOk = $true
        }
        $Tcp80.Close()
    } catch {}

    try {
        $Tcp443 = New-Object System.Net.Sockets.TcpClient
        $Connect443 = $Tcp443.BeginConnect("127.0.0.1", 443, $null, $null)
        $Wait443 = $Connect443.AsyncWaitHandle.WaitOne(1000, $false)
        if ($Wait443) {
            $Tcp443.EndConnect($Connect443)
            $NginxOk = $true
        }
        $Tcp443.Close()
    } catch {}

    if ($NginxOk) {
        Write-Log "Ports 80/443 (Nginx Reverse Proxy) are ACTIVE and responding." "OK"
    } else {
        Write-Log "Ports 80/443 (Nginx Reverse Proxy) are NOT responding. Initiating Nginx self-healing..." "WARN"
        
        $NginxProcs = Get-Process -Name "nginx" -ErrorAction SilentlyContinue
        if ($NginxProcs) {
            Write-Log "Stopping lingering nginx background processes..."
            Stop-Process -Name "nginx" -Force -ErrorAction SilentlyContinue
            Start-Sleep -Seconds 1
        }

        if ($IsAdmin) {
            Write-Log "Attempting to restart Nginx Windows Service..."
            net stop Nginx >$null 2>&1
            net start Nginx >$null 2>&1
        } else {
            Write-Log "Starting Nginx standalone background process..."
            Start-Process -FilePath (Join-Path $NginxDir "nginx.exe") -WorkingDirectory $NginxDir -WindowStyle Hidden
        }

        Start-Sleep -Seconds 2
        
        $NginxOkFinal = $false
        try {
            $Tcp80 = New-Object System.Net.Sockets.TcpClient
            $Connect80 = $Tcp80.BeginConnect("127.0.0.1", 80, $null, $null)
            $Wait80 = $Connect80.AsyncWaitHandle.WaitOne(1500, $false)
            if ($Wait80) {
                $Tcp80.EndConnect($Connect80)
                $NginxOkFinal = $true
            }
            $Tcp80.Close()
        } catch {}

        if ($NginxOkFinal) {
            Write-Log "Nginx successfully recovered and running." "OK"
        } else {
            Write-Log "Nginx failed to start. Port 80/443 still closed. Check Nginx configuration and error logs." "ERROR"
        }
    }

    # 3b. DNS Port Audit (UDP 53)
    $DnsOk = $false
    $DnsEndpoint = Get-NetUDPEndpoint -LocalPort 53 -ErrorAction SilentlyContinue
    if ($DnsEndpoint) {
        Write-Log "Port 53 (Achme Local DNS Server) is ACTIVE and responding." "OK"
        $DnsOk = $true
    }

    if (-not $DnsOk) {
        Write-Log "Port 53 (Achme Local DNS Server) is NOT active. Initiating DNS self-healing..." "WARN"
        
        # Kill lingering dns-server process
        $DnsProcs = Get-CimInstance Win32_Process -Filter "Name = 'node.exe' AND CommandLine LIKE '%dns-server.js%'" -ErrorAction SilentlyContinue
        if (-not $DnsProcs) {
            $DnsProcs = Get-WmiObject Win32_Process -Filter "Name = 'node.exe' AND CommandLine LIKE '%dns-server.js%'" -ErrorAction SilentlyContinue
        }
        if ($DnsProcs) {
            foreach ($P in $DnsProcs) {
                Write-Log "Killing lingering DNS server process (PID: $($P.ProcessId))..." -Level "WARN"
                Stop-Process -Id $P.ProcessId -Force -ErrorAction SilentlyContinue
            }
            Start-Sleep -Seconds 1
        }

        # Recover DNS server
        Write-Log "Starting background DNS server node.exe server-deployment/dns-server.js..."
        Start-Process -FilePath "node.exe" -ArgumentList "server-deployment/dns-server.js" -WorkingDirectory $WorkspaceRoot -WindowStyle Hidden
        Start-Sleep -Seconds 2

        # Verify DNS server status again
        $DnsEndpoint = Get-NetUDPEndpoint -LocalPort 53 -ErrorAction SilentlyContinue
        if ($DnsEndpoint) {
            Write-Log "DNS Server successfully recovered and running." "OK"
        } else {
            Write-Log "DNS Server failed to start on Port 53. Please check if another process is binding to UDP 53." "ERROR"
        }
    }

    # 4. Cloudflare Tunnel Health Check + Auto-Start
    $CfProc = Get-Process -Name "cloudflared" -ErrorAction SilentlyContinue
    if ($CfProc) {
        Write-Log "Cloudflare Tunnel (cloudflared) is running and active in the background." "OK"
    } else {
        # Check if tunnel is configured but not running - auto-start it
        $CfTokenFile = Join-Path $WorkspaceRoot "cloudflared-token.txt"
        if (Test-Path -LiteralPath $CfTokenFile) {
            $CfToken = (Get-Content -Path $CfTokenFile -Raw).Trim()
            if ($CfToken) {
                Write-Log "Cloudflare Tunnel configured but not running. Auto-starting..." "WARN"
                $CfExePath = Join-Path $DeploymentRoot "cloudflared.exe"
                if (Test-Path -LiteralPath $CfExePath) {
                    Start-Process -FilePath $CfExePath -ArgumentList "tunnel", "run", "--token", $CfToken -WindowStyle Hidden -WorkingDirectory $DeploymentRoot
                    Start-Sleep -Seconds 3
                    $CfProc2 = Get-Process -Name "cloudflared" -ErrorAction SilentlyContinue
                    if ($CfProc2) {
                        Write-Log "Cloudflare Tunnel auto-started successfully." "OK"
                    } else {
                        Write-Log "Cloudflare Tunnel auto-start failed. Check token validity." "ERROR"
                    }
                } else {
                    Write-Log "cloudflared.exe not found at $CfExePath. Download it or run setup." "WARN"
                }
            }
        }
    }

    # 5. DHCP LAN IP Shift Detection and Auto-Healing
    Write-Log "Checking for active LAN IP shifts..."
    $CurrentActiveIp = "127.0.0.1"
    try {
        $CurrentActiveIp = (Get-NetIPAddress -AddressFamily IPv4 -InterfaceAlias 'Wi-Fi', 'Ethernet' -ErrorAction SilentlyContinue | Select-Object -First 1).IPAddress
        if (-not $CurrentActiveIp) {
            $CurrentActiveIp = (Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue | Where-Object { $_.IPAddress -notlike "127.*" -and $_.IPAddress -notlike "169.254.*" } | Select-Object -First 1).IPAddress
        }
    } catch {}
    if (-not $CurrentActiveIp) { $CurrentActiveIp = "127.0.0.1" }

    Write-Log "Active LAN IP detected: $CurrentActiveIp"
    
    $SslDir = Join-Path $DeploymentRoot "ssl"
    $LastIpFile = Join-Path $SslDir "last_ip.txt"
    $LastIp = ""
    if (Test-Path -LiteralPath $LastIpFile) {
        $LastIp = (Get-Content -Path $LastIpFile -Raw -ErrorAction SilentlyContinue).Trim()
    }

    if ($LastIp -ne $CurrentActiveIp -and $CurrentActiveIp -ne "127.0.0.1") {
        Write-Log "DHCP LAN IP Shift Detected! Shifted from '$LastIp' to '$CurrentActiveIp'." "WARN"
        Write-Log "Initiating dynamic certificate regeneration and Nginx/DNS reload..." "WARN"

        # Regenerate certs with the new LAN IP included in SAN
        try {
            powershell -ExecutionPolicy Bypass -File "$WorkspaceRoot\server-deployment\generate-certs.ps1"
            $CurrentActiveIp | Out-File -FilePath $LastIpFile -NoNewline -Encoding ascii -Force
            Write-Log "Successfully regenerated dynamic SSL certificate with new LAN IP SAN." "OK"
        } catch {
            Write-Log "Failed to regenerate dynamic SSL certificate: $_" "ERROR"
        }

        # Reload Nginx to pick up new certificates
        if ($IsAdmin) {
            Write-Log "Reloading Nginx Windows Service..."
            net stop Nginx >$null 2>&1
            net start Nginx >$null 2>&1
        } else {
            Write-Log "Reloading Nginx background processes..."
            Stop-Process -Name "nginx" -Force -ErrorAction SilentlyContinue
            Start-Sleep -Seconds 1
            Start-Process -FilePath (Join-Path $NginxDir "nginx.exe") -WorkingDirectory $NginxDir -WindowStyle Hidden
        }

        # Restart DNS server to pick up the new IP
        $DnsProcs = Get-CimInstance Win32_Process -Filter "Name = 'node.exe' AND CommandLine LIKE '%dns-server.js%'" -ErrorAction SilentlyContinue
        if (-not $DnsProcs) {
            $DnsProcs = Get-WmiObject Win32_Process -Filter "Name = 'node.exe' AND CommandLine LIKE '%dns-server.js%'" -ErrorAction SilentlyContinue
        }
        if ($DnsProcs) {
            foreach ($P in $DnsProcs) {
                Stop-Process -Id $P.ProcessId -Force -ErrorAction SilentlyContinue
            }
        }
        Start-Process -FilePath "node.exe" -ArgumentList "server-deployment/dns-server.js" -WorkingDirectory $WorkspaceRoot -WindowStyle Hidden
        
        Write-Log "Dynamic DNS and SSL reload completed successfully." "SUCCESS"
    } else {
        Write-Log "Active LAN IP has not shifted. Certificate SAN list remains valid." "OK"
        # Ensure the file exists for future boots
        if ($CurrentActiveIp -ne "127.0.0.1") {
            $CurrentActiveIp | Out-File -FilePath $LastIpFile -NoNewline -Encoding ascii -Force
        }
    }

    Write-Log "Startup Watchdog execution completed successfully!" "SUCCESS"
    exit 0
}
catch {
    Write-Log "Startup Watchdog encountered an unexpected error: $_" "ERROR"
    exit 1
}
