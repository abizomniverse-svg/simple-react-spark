# Strict mode
Set-StrictMode -Version Latest
$ErrorActionPreference = "Continue"

# Configuration
$WorkspaceRoot = Split-Path -Parent $PSScriptRoot

# Detect user privilege level
$IsAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if ($IsAdmin) {
    $DeploymentRoot = "C:\Deployment\achme"
    $NginxDir = "C:\nginx"
} else {
    $DeploymentRoot = Join-Path $WorkspaceRoot "Deployment\achme"
    $NginxDir = Join-Path $WorkspaceRoot "Deployment\nginx"
}

$SslDir = Join-Path $DeploymentRoot "ssl"
$TempDir = Join-Path $WorkspaceRoot "scratch\temp-installer"
$LogFile = Join-Path $DeploymentRoot "logs\auto-installer.log"
$FrontendBuildPath = Join-Path $WorkspaceRoot "frontend\build"

# Dynamically discover the active local LAN IPv4 address
function Get-LanIP {
    $ip = (Get-NetIPAddress -AddressFamily IPv4 -InterfaceAlias 'Wi-Fi', 'Ethernet' -ErrorAction SilentlyContinue | Where-Object { $_.IPAddress -notlike "169.254.*" } | Select-Object -First 1).IPAddress
    if (-not $ip) {
        $ip = (Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue | Where-Object { $_.IPAddress -notlike "127.*" -and $_.IPAddress -notlike "169.254.*" } | Select-Object -First 1).IPAddress
    }
    return $ip
}
$ServerLanIP = Get-LanIP
if (-not $ServerLanIP) { $ServerLanIP = "127.0.0.1" }

# Helpers
function Write-Log {
    param (
        [string]$Message,
        [string]$Level = "INFO"
    )
    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $LogLine = "[$Timestamp] [$Level] $Message"
    Write-Output $LogLine
    
    $LogDir = Split-Path -Path $LogFile
    if (-not (Test-Path -LiteralPath $LogDir)) {
        New-Item -ItemType Directory -Path $LogDir -Force | Out-Null
    }
    
    try {
        $LogLine | Out-File -FilePath $LogFile -Append -Encoding ascii -ErrorAction SilentlyContinue
    } catch {}
}

# Reload Environment PATH dynamically
function Update-SessionPath {
    Write-Log "Refreshing system environment variables for active session..."
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
}

# Kill only our specific backend processes (targeted, not blanket node kill)
function Stop-OurBackend {
    Write-Log "Stopping any existing Achme backend processes..."
    $BackendPath = Join-Path $DeploymentRoot "backend"
    $BackendPathNormalized = $BackendPath.Replace('\', '\\')
    
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
    $env:PUPPETEER_SKIP_DOWNLOAD = "true"

    Write-Log "========================================"
    Write-Log "STARTING ACHME ENTERPRISE AUTO-INSTALLATION SUITE"
    Write-Log "========================================"
    Write-Log "Detected Server LAN IP: $ServerLanIP"

    if ($IsAdmin) {
        Write-Log "Running with ADMINISTRATOR privileges. System services will be configured." "OK"
    } else {
        Write-Log "Running as STANDARD USER. Bypassing administrative services and routing to user-space background processes." "WARN"
    }

    if (-not (Test-Path -LiteralPath $TempDir)) {
        New-Item -ItemType Directory -Path $TempDir -Force | Out-Null
    }

    # 1. Setup folders
    Write-Log "Running directory structure setup..."
    powershell -ExecutionPolicy Bypass -File "$WorkspaceRoot\server-deployment\setup.ps1"

    # 2. Check Node.js
    $NodeCheck = Get-Command "node" -ErrorAction SilentlyContinue
    if (-not $NodeCheck) {
        if ($IsAdmin) {
            Write-Log "Node.js is NOT installed. Initiating silent installer download..." "WARN"
            $NodeMsi = Join-Path -Path $TempDir -ChildPath "node-install.msi"
            $NodeUrl = "https://nodejs.org/dist/v20.12.2/node-v20.12.2-x64.msi"
            
            Write-Log "Downloading Node.js (v20.12.2) from: $NodeUrl"
            Invoke-WebRequest -Uri $NodeUrl -OutFile $NodeMsi -UseBasicParsing
            
            Write-Log "Executing silent installation of Node.js..."
            $InstallProc = Start-Process msiexec.exe -ArgumentList "/i `"$NodeMsi`" /qn /norestart" -Wait -PassThru
            if ($InstallProc.ExitCode -eq 0) {
                Write-Log "Node.js installed successfully." "OK"
                Update-SessionPath
            } else {
                throw "Node.js silent installation failed with code: $($InstallProc.ExitCode)"
            }
        } else {
            throw "Node.js is NOT installed on this machine and cannot be installed silently in standard user mode. Please install Node.js (LTS) first and run this script again."
        }
    } else {
        Write-Log "Node.js is already installed: $(node -v)" "OK"
    }

    # 3. Check NSSM (Admin only)
    if ($IsAdmin) {
        $NssmCheck = Test-Path -LiteralPath "C:\Windows\System32\nssm.exe"
        if (-not $NssmCheck) {
            Write-Log "NSSM is NOT installed. Downloading..." "WARN"
            $NssmZip = Join-Path -Path $TempDir -ChildPath "nssm.zip"
            $NssmUrl = "https://nssm.cc/release/nssm-2.24.zip"
            
            Write-Log "Downloading NSSM from: $NssmUrl"
            Invoke-WebRequest -Uri $NssmUrl -OutFile $NssmZip -UseBasicParsing
            
            $ExtractPath = Join-Path -Path $TempDir -ChildPath "nssm-extract"
            Expand-Archive -Path $NssmZip -DestinationPath $ExtractPath -Force
            
            $NssmExePath = Join-Path -Path $ExtractPath -ChildPath "nssm-2.24\win64\nssm.exe"
            Copy-Item -Path $NssmExePath -Destination "C:\Windows\System32\nssm.exe" -Force
            
            Write-Log "NSSM successfully installed to C:\Windows\System32\nssm.exe." "OK"
        } else {
            Write-Log "NSSM is already installed." "OK"
        }
    } else {
        Write-Log "User Mode active. Skipping NSSM system service checks."
    }

    # 4. Check and Install Nginx
    $NginxCheck = Test-Path -LiteralPath (Join-Path $NginxDir "nginx.exe")
    if (-not $NginxCheck) {
        Write-Log "Nginx is NOT installed in $NginxDir. Downloading..." "WARN"
        $NginxZip = Join-Path -Path $TempDir -ChildPath "nginx.zip"
        $NginxUrl = "http://nginx.org/download/nginx-1.24.0.zip"
        
        Write-Log "Downloading Nginx from: $NginxUrl"
        Invoke-WebRequest -Uri $NginxUrl -OutFile $NginxZip -UseBasicParsing
        
        $NginxParentDir = Split-Path -Path $NginxDir
        Write-Log "Extracting Nginx to $NginxParentDir..."
        if (-not (Test-Path -LiteralPath $NginxParentDir)) {
            New-Item -ItemType Directory -Path $NginxParentDir -Force | Out-Null
        }
        Expand-Archive -Path $NginxZip -DestinationPath $NginxParentDir -Force
        
        $ExtractedFolder = Join-Path $NginxParentDir "nginx-1.24.0"
        Rename-Item -Path $ExtractedFolder -NewName (Split-Path -Leaf $NginxDir) -Force
        Write-Log "Nginx successfully installed in $NginxDir." "OK"
    } else {
        Write-Log "Nginx is already installed in $NginxDir." "OK"
    }

    # 5. Check Tailscale VPN
    $TailscaleCheck = Get-Service -Name "Tailscale" -ErrorAction SilentlyContinue
    if (-not $TailscaleCheck) {
        if ($IsAdmin) {
            Write-Log "Tailscale VPN is NOT installed. Downloading installer..." "WARN"
            $TsMsi = Join-Path -Path $TempDir -ChildPath "tailscale.msi"
            $TsUrl = "https://pkgs.tailscale.com/stable/tailscale-setup-latest.msi"
            
            Write-Log "Downloading Tailscale from: $TsUrl"
            Invoke-WebRequest -Uri $TsUrl -OutFile $TsMsi -UseBasicParsing
            
            Write-Log "Executing silent installation of Tailscale..."
            $TsProc = Start-Process msiexec.exe -ArgumentList "/i `"$TsMsi`" /qn /norestart" -Wait -PassThru
            if ($TsProc.ExitCode -eq 0) {
                Write-Log "Tailscale installed successfully." "OK"
            } else {
                Write-Log "Tailscale installation exited with code $($TsProc.ExitCode). Verify manually." "WARN"
            }
        } else {
            Write-Log "Tailscale is not installed. Standard users cannot install system VPNs silently. Please run Tailscale Client manually if remote VPN access is needed." "WARN"
        }
    } else {
        Write-Log "Tailscale VPN service is already installed." "OK"
    }

    # 6. Check and Install PM2
    Update-SessionPath
    $Pm2Check = Get-Command "pm2" -ErrorAction SilentlyContinue
    if (-not $Pm2Check) {
        Write-Log "PM2 is NOT installed. Installing globally via NPM..." "WARN"
        & npm install -g pm2 pm2-windows-startup 2>&1 | Out-String -Stream | ForEach-Object { Write-Log "NPM: $_" }
        
        if ($IsAdmin) {
            Write-Log "Configuring PM2 system startup..."
            Update-SessionPath
            & pm2-startup install 2>&1 | Out-String -Stream | ForEach-Object { Write-Log "PM2: $_" }
        }
        Write-Log "PM2 successfully installed globally." "OK"
    } else {
        Write-Log "PM2 is already installed." "OK"
    }

    # 7. Generate SSL Certificates
    Write-Log "Generating and securing SSL certificates..."
    powershell -ExecutionPolicy Bypass -File "$WorkspaceRoot\server-deployment\generate-certs.ps1"

    # 7b. Configure Hosts file (DNS resolution) with auto-elevation
    $HostsPath = "C:\Windows\System32\drivers\etc\hosts"
    $HostsEntries = @(
        "127.0.0.1 achme.com",
        "127.0.0.1 api.achme.com",
        "127.0.0.1 www.achme.com",
        "$ServerLanIP achme.com",
        "$ServerLanIP api.achme.com",
        "$ServerLanIP www.achme.com"
    )
    
    if ($IsAdmin) {
        Write-Log "Registering local domain entries in hosts file (LAN IP: $ServerLanIP)..."
        $HostsContent = Get-Content -Path $HostsPath -Raw -ErrorAction SilentlyContinue
        $Modified = $false
        foreach ($Entry in $HostsEntries) {
            $Domain = ($Entry -split '\s+')[1]
            if ($HostsContent -notmatch "(?m)^[^#]*\b$([regex]::Escape($Domain))\b") {
                Add-Content -Path $HostsPath -Value "`r`n$Entry" -Force
                Write-Log "Added DNS entry to hosts file: $Entry" "OK"
                $Modified = $true
            }
        }
        if (-not $Modified) {
            Write-Log "Hosts file DNS entries already exist." "OK"
        }
    } else {
        Write-Log "Standard User Mode: Checking hosts file for DNS resolution..."
        $HostsContent = Get-Content -Path $HostsPath -Raw -ErrorAction SilentlyContinue
        $Missing = @()
        foreach ($Entry in $HostsEntries) {
            $Domain = ($Entry -split '\s+')[1]
            if ($HostsContent -notmatch "(?m)^[^#]*\b$([regex]::Escape($Domain))\b") {
                $Missing += $Domain
            }
        }
        if ($Missing.Count -gt 0) {
            Write-Log "Hosts file is missing domains: $($Missing -join ', '). Attempting auto-elevation..." "WARN"
            
            # Try to elevate just for hosts file editing
            try {
                $HostsEditScript = @"
`$HostsPath = "C:\Windows\System32\drivers\etc\hosts"
`$Entries = @("$($HostsEntries -join '","')")
`$Content = Get-Content -Path `$HostsPath -Raw -ErrorAction SilentlyContinue
foreach (`$Entry in `$Entries) {
    `$Domain = (`$Entry -split '\s+')[1]
    if (`$Content -notmatch "(?m)^[^#]*\b`$([regex]::Escape(`$Domain))\b") {
        Add-Content -Path `$HostsPath -Value "`r`n`$Entry" -Force
    }
}
"@
                $TempScript = Join-Path $TempDir "edit-hosts.ps1"
                $HostsEditScript | Out-File -FilePath $TempScript -Encoding utf8 -Force
                
                $HostsProc = Start-Process -FilePath "powershell.exe" -ArgumentList "-ExecutionPolicy Bypass -File `"$TempScript`" -Verb RunAs" -Wait -PassThru -WindowStyle Hidden
                if ($HostsProc.ExitCode -eq 0) {
                    Write-Log "Hosts file updated via elevated prompt." "OK"
                } else {
                    Write-Log "Hosts elevation was declined. Please add manually to C:\Windows\System32\drivers\etc\hosts:" "WARN"
                    foreach ($Entry in $HostsEntries) {
                        Write-Log "  $Entry" "WARN"
                    }
                }
            } catch {
                Write-Log "Could not elevate for hosts file. Please add manually to C:\Windows\System32\drivers\etc\hosts:" "WARN"
                foreach ($Entry in $HostsEntries) {
                    Write-Log "  $Entry" "WARN"
                }
            }
        } else {
            Write-Log "Hosts file already contains local domain DNS entries." "OK"
        }
    }

    # 8. Compile and Deploy Application Assets
    Write-Log "Deploying application code..."

    # Frontend Auto-Build and copy
    Write-Log "Preparing frontend assets..."
    cd "$WorkspaceRoot\frontend"
    if (-not (Test-Path -LiteralPath "node_modules")) {
        Write-Log "Frontend node_modules not found. Installing frontend dependencies..."
        & npm install 2>&1 | Out-String -Stream | ForEach-Object { Write-Log "NPM-Frontend: $_" }
    }
    Write-Log "Compiling frontend assets for production..."
    & npm run build 2>&1 | Out-String -Stream | ForEach-Object { Write-Log "NPM-Build: $_" }

    Write-Log "Deploying built frontend assets to $DeploymentRoot\frontend..."
    $DestFrontend = Join-Path $DeploymentRoot "frontend"
    if (Test-Path -LiteralPath $FrontendBuildPath) {
        if (-not (Test-Path -LiteralPath $DestFrontend)) {
            New-Item -ItemType Directory -Path $DestFrontend -Force | Out-Null
        }
        Copy-Item -Path "$FrontendBuildPath\*" -Destination $DestFrontend -Recurse -Force
        Write-Log "Frontend assets copied." "OK"
    } else {
        Write-Log "Frontend compilation did not produce build folder. Verify errors." "ERROR"
    }

    # Backend Deployment & Node modules copy
    Write-Log "Deploying backend server to $DeploymentRoot\backend..."
    $BackendDest = Join-Path $DeploymentRoot "backend"
    
    if (-not (Test-Path -LiteralPath $BackendDest)) {
        New-Item -ItemType Directory -Path $BackendDest -Force | Out-Null
    }
    
    Get-ChildItem -Path "$WorkspaceRoot\backend" -Exclude "node_modules", "temp*" | ForEach-Object {
        Copy-Item -Path $_.FullName -Destination $BackendDest -Recurse -Force
    }
    Write-Log "Backend source code copied." "OK"

    # Production Node Modules Installation
    Write-Log "Installing production node dependencies in deployment folder..."
    cd $BackendDest
    & npm install --production 2>&1 | Out-String -Stream | ForEach-Object { Write-Log "NPM-Production: $_" }
    Write-Log "Production node modules loaded." "OK"

    # Copy and configure PM2 Ecosystem configuration with resolved paths
    $DeploymentRootJs = $DeploymentRoot.Replace('\', '\\')
    $EcosystemContent = Get-Content -Path "$WorkspaceRoot\server-deployment\ecosystem.config.js" -Raw
    $EcosystemContent = $EcosystemContent.Replace("C:\\Deployment\\achme", $DeploymentRootJs)
    $EcosystemContent | Out-File -FilePath "$DeploymentRoot\ecosystem.config.js" -Encoding ascii -Force
    Write-Log "PM2 Ecosystem configuration deployed with resolved paths." "OK"

    # Copy and configure Nginx Configuration with resolved paths
    $DeploymentRootNginx = $DeploymentRoot.Replace('\', '/')
    $NginxConfContent = Get-Content -Path "$WorkspaceRoot\server-deployment\nginx.conf" -Raw
    $NginxConfContent = $NginxConfContent.Replace("C:/Deployment/achme", $DeploymentRootNginx)
    
    $NginxConfDir = Join-Path $NginxDir "conf"
    if (-not (Test-Path -LiteralPath $NginxConfDir)) {
        New-Item -ItemType Directory -Path $NginxConfDir -Force | Out-Null
    }
    
    $NginxConfContent | Out-File -FilePath "$NginxConfDir\nginx.conf" -Encoding ascii -Force
    Write-Log "Nginx configuration deployed with resolved paths." "OK"

    # 9. Register and Start Nginx and PM2
    Write-Log "Registering and starting all systems..."

    if ($IsAdmin) {
        $NginxService = Get-Service -Name "Nginx" -ErrorAction SilentlyContinue
        if (-not $NginxService) {
            Write-Log "Registering Nginx as a Windows Service..."
            & nssm install Nginx (Join-Path $NginxDir "nginx.exe") 2>&1 | Out-String -Stream | ForEach-Object { Write-Log "NSSM: $_" }
            & nssm set Nginx AppDirectory $NginxDir
            & nssm set Nginx DisplayName "Achme Nginx Proxy"
            & nssm set Nginx Start SERVICE_AUTO_START
        }
        
        Write-Log "Starting Nginx service..."
        net stop Nginx >$null 2>&1
        net start Nginx
    } else {
        Write-Log "Standard User Mode: Checking for running Nginx processes..."
        $NginxProc = Get-Process -Name "nginx" -ErrorAction SilentlyContinue
        if ($NginxProc) {
            Write-Log "Stopping running Nginx background processes for reload..."
            Stop-Process -Name "nginx" -Force -ErrorAction SilentlyContinue
            Start-Sleep -Seconds 1
        }
        
        Write-Log "Starting Nginx as a standalone user background process..."
        Start-Process -FilePath (Join-Path $NginxDir "nginx.exe") -WorkingDirectory $NginxDir -WindowStyle Hidden
        Write-Log "Nginx background process started." "OK"
    }

    # --- CLOUDFLARE TUNNEL AUTO-INTEGRATION ---
    $CfTokenFile = Join-Path $WorkspaceRoot "cloudflared-token.txt"
    $HasCf = $false
    $CfToken = ""
    $CfExe = ""
    if (Test-Path -LiteralPath $CfTokenFile) {
        Write-Log "Cloudflare Tunnel configuration detected (cloudflared-token.txt)." "INFO"
        $CfToken = (Get-Content -Path $CfTokenFile -Raw).Trim()
        if ($CfToken) {
            $CfExePath = Join-Path $DeploymentRoot "cloudflared.exe"
            $CfCheck = Get-Command "cloudflared" -ErrorAction SilentlyContinue
            if ($CfCheck) {
                $CfExe = "cloudflared"
                $HasCf = $true
            } else {
                if (-not (Test-Path -LiteralPath $CfExePath)) {
                    Write-Log "Downloading Cloudflare Tunnel binary (cloudflared.exe)..." "WARN"
                    $CfUrl = "https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-windows-amd64.exe"
                    try {
                        Invoke-WebRequest -Uri $CfUrl -OutFile $CfExePath -UseBasicParsing
                        Write-Log "Cloudflare Tunnel downloaded successfully." "OK"
                        $CfExe = $CfExePath
                        $HasCf = $true
                    } catch {
                        Write-Log "Failed to download cloudflared.exe: $_" "ERROR"
                    }
                } else {
                    $CfExe = $CfExePath
                    $HasCf = $true
                }
            }
        }
    } else {
        Write-Log "No cloudflared-token.txt found. Skipping Cloudflare Tunnel auto-integration."
    }

    # --- WINDOWS STARTUP SHORTCUT ---
    $StartupFolder = [System.IO.Path]::Combine($env:APPDATA, 'Microsoft\Windows\Start Menu\Programs\Startup')
    $ShortcutPath = Join-Path $StartupFolder "AchmeServerStartup.lnk"
    Write-Log "Registering/Updating Achme Server Control Panel in Windows Startup..."
    try {
        $WshShell = New-Object -ComObject WScript.Shell
        $Shortcut = $WshShell.CreateShortcut($ShortcutPath)
        $Shortcut.TargetPath = Join-Path $WorkspaceRoot "startserver.bat"
        $Shortcut.WorkingDirectory = $WorkspaceRoot
        $Shortcut.IconLocation = "cmd.exe"
        $Shortcut.Description = "Achme Server Automatic Launch"
        $Shortcut.Save()
        Write-Log "Successfully created/updated Windows Startup shortcut: $ShortcutPath" "OK"
    } catch {
        Write-Log "Failed to create Windows Startup shortcut: $_" "WARN"
    }

    # --- PROCESS CONSOLE ORCHESTRATOR ---
    Write-Log "Initializing Multi-Console Terminal Orchestrator..."

    # Stop only our specific backend processes (targeted kill)
    Stop-OurBackend
    
    # Stop any existing cloudflared processes
    Stop-Process -Name "cloudflared" -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 1

    # Start backend via PM2 (fork mode, 1 instance)
    Write-Log "Starting backend via PM2..."
    $EcosystemPath = Join-Path $DeploymentRoot "ecosystem.config.js"
    & pm2 start $EcosystemPath 2>&1 | Out-String -Stream | ForEach-Object { Write-Log "PM2: $_" }
    & pm2 save 2>&1 | Out-String -Stream | ForEach-Object { Write-Log "PM2: $_" }
    Start-Sleep -Seconds 3

    # Define paths and log files
    $MonitorScript = Join-Path $WorkspaceRoot "server-deployment\live-monitor.ps1"
    $NginxLog = Join-Path $DeploymentRoot "logs\nginx-access.log"

    if (-not (Test-Path -LiteralPath $NginxLog)) {
        New-Item -ItemType File -Path $NginxLog -Force | Out-Null
    }

    # Build commands for each console tab
    $CmdMonitor = "powershell.exe -NoExit -ExecutionPolicy Bypass -File `"$MonitorScript`""
    $CmdNode = "powershell.exe -NoExit -Command `"cd '$BackendDest'; Write-Host '=== Achme Backend (PM2 Managed) ===' -ForegroundColor Cyan; pm2 logs achme-backend --lines 0 --nostream; pm2 logs achme-backend`""
    $CmdNginxLogs = "powershell.exe -NoExit -Command `"Write-Host '=== Nginx Access Logs ===' -ForegroundColor Cyan; Get-Content -Path '$NginxLog' -Wait -Tail 20`""

    # Detect Windows Terminal
    $WtCheck = Get-Command "wt" -ErrorAction SilentlyContinue
    if ($WtCheck) {
        Write-Log "Windows Terminal detected. Spawning multi-tab session..." "OK"
        
        $WtArgs = "-d `"$DeploymentRoot`" -t `"Achme Monitor`" $CmdMonitor"
        $WtArgs += " ; new-tab -d `"$DeploymentRoot`" -t `"Achme Backend`" $CmdNode"
        $WtArgs += " ; new-tab -d `"$DeploymentRoot`" -t `"Nginx Logs`" $CmdNginxLogs"
        if ($HasCf) {
            $CmdCf = "cmd.exe /k `"title Achme Cloudflare Tunnel & cd /d `"$DeploymentRoot`" & `"$CfExe`" tunnel run --token $CfToken`""
            $WtArgs += " ; new-tab -d `"$DeploymentRoot`" -t `"Cloudflare Tunnel`" $CmdCf"
        }
        
        Start-Process -FilePath "wt.exe" -ArgumentList $WtArgs
    } else {
        Write-Log "Windows Terminal not found. Spawning separate PowerShell windows..." "WARN"
        
        Start-Process -FilePath "powershell.exe" -ArgumentList "-NoExit -ExecutionPolicy Bypass -File `"$MonitorScript`""
        Start-Sleep -Milliseconds 300
        Start-Process -FilePath "powershell.exe" -ArgumentList "-NoExit -Command `"cd '$BackendDest'; Write-Host '=== Achme Backend (PM2) ===' -ForegroundColor Cyan; pm2 logs achme-backend`""
        Start-Sleep -Milliseconds 300
        Start-Process -FilePath "powershell.exe" -ArgumentList "-NoExit -Command `"Write-Host '=== Nginx Logs ===' -ForegroundColor Cyan; Get-Content -Path '$NginxLog' -Wait -Tail 20`""
        if ($HasCf) {
            Start-Sleep -Milliseconds 300
            Start-Process -FilePath "cmd.exe" -ArgumentList "/k `"title Achme Cloudflare Tunnel & cd /d `"$DeploymentRoot`" & `"$CfExe`" tunnel run --token $CfToken`""
        }
    }

    # Start Cloudflare Tunnel in background if configured (silent mode for auto-start)
    if ($HasCf) {
        Write-Log "Starting Cloudflare Tunnel in background..."
        Start-Process -FilePath $CfExe -ArgumentList "tunnel", "run", "--token", $CfToken -WindowStyle Hidden -WorkingDirectory $DeploymentRoot
        Write-Log "Cloudflare Tunnel started (hidden)." "OK"
    }

    # Wait for services to initialize
    Write-Log "Waiting for services to initialize..."
    Start-Sleep -Seconds 4

    # 10. Audit Ports and Live Status
    Write-Log "Verifying application status..."
    powershell -ExecutionPolicy Bypass -File "$WorkspaceRoot\server-deployment\startup-watchdog.ps1"

    # Clean Temp Files
    Remove-Item -Path $TempDir -Recurse -Force -ErrorAction SilentlyContinue
    Write-Log "Cleaned temporary installation folder."

    Write-Log "========================================"
    Write-Log "AUTO-INSTALLATION AND LAUNCH COMPLETED SUCCESSFULLY!" "SUCCESS"
    Write-Log "Access the application at: https://achme.com" "SUCCESS"
    Write-Log "========================================"
    exit 0
}
catch {
    Write-Log "Auto-Installation aborted due to error: $_" "ERROR"
    try {
        Remove-Item -Path $TempDir -Recurse -Force -ErrorAction SilentlyContinue
    } catch {}
    exit 1
}
