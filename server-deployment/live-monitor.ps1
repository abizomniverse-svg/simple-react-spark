# Achme Enterprise Server Live Monitor Dashboard
# Runs continuously to poll service health and display system uptime status

Set-StrictMode -Version Latest
$ErrorActionPreference = "Continue"

$WorkspaceRoot = Split-Path -Parent $PSScriptRoot
$IsAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if ($IsAdmin) {
    $DeploymentRoot = "C:\Deployment\achme"
} else {
    $DeploymentRoot = Join-Path $WorkspaceRoot "Deployment\achme"
}

# Get LAN IP
$LanIP = "127.0.0.1"
try {
    $LanIP = (Get-NetIPAddress -AddressFamily IPv4 -InterfaceAlias 'Wi-Fi', 'Ethernet' -ErrorAction SilentlyContinue | Where-Object { $_.IPAddress -notlike "169.254.*" } | Select-Object -First 1).IPAddress
    if (-not $LanIP) {
        $LanIP = (Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue | Where-Object { $_.IPAddress -notlike "127.*" -and $_.IPAddress -notlike "169.254.*" } | Select-Object -First 1).IPAddress
    }
} catch {}
if (-not $LanIP) { $LanIP = "127.0.0.1" }

# Clear host and setup screen
Clear-Host
$host.UI.RawUI.WindowTitle = "Achme Server Live Status Monitor"

function Check-Port {
    param (
        [string]$IP,
        [int]$Port
    )
    try {
        $Tcp = New-Object System.Net.Sockets.TcpClient
        $Connect = $Tcp.BeginConnect($IP, $Port, $null, $null)
        $Wait = $Connect.AsyncWaitHandle.WaitOne(1000, $false)
        if ($Wait) {
            $Tcp.EndConnect($Connect)
            $Tcp.Close()
            return $true
        }
        $Tcp.Close()
        return $false
    } catch {
        return $false
    }
}

# Main polling loop
try {
    while ($true) {
        Clear-Host
        $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        
        Write-Host "============================================================" -ForegroundColor Cyan
        Write-Host "           ACHME ENTERPRISE SERVER LIVE MONITOR" -ForegroundColor Cyan -Bold
        Write-Host "============================================================" -ForegroundColor Cyan
        Write-Host "  Current Time:  $Timestamp" -ForegroundColor White
        Write-Host "  Server LAN IP: $LanIP" -ForegroundColor Yellow
        Write-Host "  Privilege:     $(if ($IsAdmin) { 'ADMINISTRATOR (Service Mode)' } else { 'STANDARD USER (Session Mode)' })" -ForegroundColor Gray
        Write-Host "  Local URL:     https://achme.com" -ForegroundColor DarkYellow
        Write-Host "  Backend API:   https://api.achme.com" -ForegroundColor DarkYellow
        Write-Host "============================================================" -ForegroundColor Cyan
        Write-Host ""
        
        # 1. Audit MySQL Database (Port 3306)
        $MySqlActive = Check-Port -IP "127.0.0.1" -Port 3306
        if ($MySqlActive) {
            Write-Host "  [OK] " -NoNewline -ForegroundColor Green
            Write-Host "Port 3306 (MySQL Database)      -> " -NoNewline -ForegroundColor White
            Write-Host "ACTIVE (Responding)" -ForegroundColor Green
        } else {
            Write-Host "  [ERR] " -NoNewline -ForegroundColor Red
            Write-Host "Port 3306 (MySQL Database)      -> " -NoNewline -ForegroundColor White
            Write-Host "OFFLINE (Connection Refused)" -ForegroundColor Red
        }

        # 2. Audit Node Backend API (Port 5000)
        $BackendActive = Check-Port -IP "127.0.0.1" -Port 5000
        if ($BackendActive) {
            Write-Host "  [OK] " -NoNewline -ForegroundColor Green
            Write-Host "Port 5000 (Node Backend API)    -> " -NoNewline -ForegroundColor White
            Write-Host "ACTIVE (Responding)" -ForegroundColor Green
        } else {
            Write-Host "  [ERR] " -NoNewline -ForegroundColor Red
            Write-Host "Port 5000 (Node Backend API)    -> " -NoNewline -ForegroundColor White
            Write-Host "OFFLINE (Not Responding)" -ForegroundColor Red
        }

        # 3. Audit Nginx Proxy (Port 80/443)
        $HttpActive = Check-Port -IP "127.0.0.1" -Port 80
        $HttpsActive = Check-Port -IP "127.0.0.1" -Port 443
        if ($HttpActive -or $HttpsActive) {
            Write-Host "  [OK] " -NoNewline -ForegroundColor Green
            Write-Host "Ports 80/443 (Nginx Web Proxy)  -> " -NoNewline -ForegroundColor White
            Write-Host "ACTIVE (Responding)" -ForegroundColor Green
        } else {
            Write-Host "  [ERR] " -NoNewline -ForegroundColor Red
            Write-Host "Ports 80/443 (Nginx Web Proxy)  -> " -NoNewline -ForegroundColor White
            Write-Host "OFFLINE (Proxy Down)" -ForegroundColor Red
        }

        # 4. Audit DNS Server
        $DnsActive = Check-Port -IP "127.0.0.1" -Port 53
        if (-not $DnsActive) {
            $DnsActive = Check-Port -IP "127.0.0.1" -Port 5353
        }
        if ($DnsActive) {
            Write-Host "  [OK] " -NoNewline -ForegroundColor Green
            Write-Host "DNS Server (achme.com)          -> " -NoNewline -ForegroundColor White
            Write-Host "ACTIVE (Resolving)" -ForegroundColor Green
        } else {
            if ($IsAdmin) {
                Write-Host "  [ERR] " -NoNewline -ForegroundColor Red
                Write-Host "DNS Server (achme.com)          -> " -NoNewline -ForegroundColor White
                Write-Host "OFFLINE (Not Running)" -ForegroundColor Red
            } else {
                Write-Host "  [INF] " -NoNewline -ForegroundColor Blue
                Write-Host "DNS Server (achme.com)          -> " -NoNewline -ForegroundColor White
                Write-Host "SKIPPED (Admin required for port 53)" -ForegroundColor Blue
            }
        }

        # 5. Audit Cloudflare Tunnel
        $CfProc = Get-Process -Name "cloudflared" -ErrorAction SilentlyContinue
        if ($CfProc) {
            Write-Host "  [OK] " -NoNewline -ForegroundColor Green
            Write-Host "Cloudflare Tunnel (cloudflared) -> " -NoNewline -ForegroundColor White
            Write-Host "RUNNING (Public Access Active)" -ForegroundColor Green
        } else {
            $CfTokenFile = Join-Path $WorkspaceRoot "cloudflared-token.txt"
            if (Test-Path -LiteralPath $CfTokenFile) {
                Write-Host "  [ERR] " -NoNewline -ForegroundColor Red
                Write-Host "Cloudflare Tunnel (cloudflared) -> " -NoNewline -ForegroundColor White
                Write-Host "OFFLINE (Token set but not running)" -ForegroundColor Red
            } else {
                Write-Host "  [INF] " -NoNewline -ForegroundColor Blue
                Write-Host "Cloudflare Tunnel (cloudflared) -> " -NoNewline -ForegroundColor White
                Write-Host "SKIPPED (No token configured)" -ForegroundColor Blue
            }
        }

        Write-Host ""
        Write-Host "------------------------------------------------------------" -ForegroundColor Gray
        Write-Host "  System is self-monitoring. To exit this dashboard:" -ForegroundColor Gray
        Write-Host "  Press [Ctrl + C] or close this window." -ForegroundColor Gray
        Write-Host "  All background services will remain running." -ForegroundColor Gray
        Write-Host "------------------------------------------------------------" -ForegroundColor Gray
        Write-Host "============================================================" -ForegroundColor Cyan
        
        Start-Sleep -Seconds 5
    }
}
catch {
    Write-Host "Monitor ended: $_" -ForegroundColor Yellow
}
