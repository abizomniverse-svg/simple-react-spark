# Achme Backend Auto-Recovery Monitor
# Runs as a background process that watches backend health and auto-restarts if needed

$ErrorActionPreference = "Continue"
$WorkspaceRoot = Split-Path -Parent $PSScriptRoot
$IsAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if ($IsAdmin) {
    $DeploymentRoot = "C:\Deployment\achme"
    $NginxDir = "C:\nginx"
} else {
    $DeploymentRoot = Join-Path $WorkspaceRoot "Deployment\achme"
    $NginxDir = Join-Path $WorkspaceRoot "Deployment\nginx"
}

$LogFile = Join-Path $DeploymentRoot "logs\backend-monitor.log"
$HealthUrl = "http://127.0.0.1:5000/health"
$MaxRestarts = 10
$RestartCount = 0
$CheckIntervalSec = 10

function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $LogLine = "[$Timestamp] [$Level] $Message"
    Write-Output $LogLine
    try {
        $LogDir = Split-Path -Path $LogFile
        if (-not (Test-Path $LogDir)) { New-Item -ItemType Directory -Path $LogDir -Force | Out-Null }
        $LogLine | Out-File -FilePath $LogFile -Append -Encoding utf8 -ErrorAction SilentlyContinue
    } catch {}
}

function Start-Backend {
    Write-Log "Starting backend via PM2..."
    $EcosystemPath = Join-Path $DeploymentRoot "ecosystem.config.js"
    if (Test-Path $EcosystemPath) {
        & pm2 start $EcosystemPath 2>&1 | Out-String -Stream | ForEach-Object { Write-Log "PM2: $_" }
        & pm2 save 2>&1 | Out-Null
    } else {
        Write-Log "Ecosystem config not found, starting directly..." "WARN"
        $env:NODE_ENV = "production"
        $env:PORT = "5000"
        $BackendDir = Join-Path $DeploymentRoot "backend"
        Start-Process -FilePath "node.exe" -ArgumentList "server.js" -WorkingDirectory $BackendDir -WindowStyle Hidden
    }
    Start-Sleep -Seconds 5
}

function Stop-Backend {
    $Pm2Check = Get-Command "pm2" -ErrorAction SilentlyContinue
    if ($Pm2Check) {
        & pm2 stop achme-backend 2>&1 | Out-Null
        & pm2 delete achme-backend 2>&1 | Out-Null
    }
    $NodeProcs = Get-Process -Name "node" -ErrorAction SilentlyContinue
    foreach ($P in $NodeProcs) {
        try {
            $CmdLine = (Get-CimInstance Win32_Process -Filter "ProcessId = $($P.Id)" -ErrorAction SilentlyContinue).CommandLine
            if ($CmdLine -match "server\.js") {
                Stop-Process -Id $P.Id -Force -ErrorAction SilentlyContinue
            }
        } catch {}
    }
    Start-Sleep -Seconds 2
}

function Resolve-PortConflict {
    $Listeners = netstat -ano | Select-String "0.0.0.0:5000 "
    if ($Listeners) {
        Write-Log "Port 5000 conflict detected! Resolving..." "WARN"
        foreach ($Line in $Listeners) {
            $Pid = ($Line -split '\s+')[-1]
            if ($Pid -and $Pid -ne $null) {
                try {
                    $Proc = Get-Process -Id $Pid -ErrorAction SilentlyContinue
                    if ($Proc) {
                        $CmdLine = (Get-CimInstance Win32_Process -Filter "ProcessId = $Pid" -ErrorAction SilentlyContinue).CommandLine
                        if ($CmdLine -notmatch "achme|server\.js|pm2") {
                            Write-Log "Killing non-achme process on port 5000 (PID: $Pid, $($Proc.Name))" "WARN"
                            Stop-Process -Id $Pid -Force -ErrorAction SilentlyContinue
                        }
                    }
                } catch {}
            }
        }
        Start-Sleep -Seconds 2
    }
}

function Check-Health {
    try {
        $Response = Invoke-WebRequest -Uri $HealthUrl -UseBasicParsing -TimeoutSec 5
        return ($Response.StatusCode -eq 200)
    } catch {
        return $false
    }
}

Write-Log "========================================"
Write-Log "Backend Auto-Recovery Monitor Started"
Write-Log "========================================"

while ($true) {
    if (Check-Health) {
        $RestartCount = 0
    } else {
        Write-Log "Backend health check FAILED! Attempting recovery..." "ERROR"
        Stop-Backend
        Resolve-PortConflict
        Start-Backend
        $RestartCount++

        if ($RestartCount -ge $MaxRestarts) {
            Write-Log "Max restart attempts ($MaxRestarts) reached. Waiting 60s before retry." "ERROR"
            Start-Sleep -Seconds 60
            $RestartCount = 0
        }
    }

    Start-Sleep -Seconds $CheckIntervalSec
}
