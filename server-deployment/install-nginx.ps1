# install-nginx.ps1
# Auto-download and install Nginx for Windows
# Must be run from: E:\OBSIDIAN\simple-react-spark\server-deployment\

$ErrorActionPreference = "Stop"

$ProjectRoot = Split-Path -Parent $PSScriptRoot
$NginxDir = Join-Path $ProjectRoot "nginx"
$NginxZip = Join-Path $env:TEMP "nginx-windows.zip"

Write-Output "[INFO] Checking Nginx installation..."

if (Test-Path (Join-Path $NginxDir "nginx.exe")) {
    Write-Output "[OK] Nginx already installed at: $NginxDir"
    $nginxVersion = & (Join-Path $NginxDir "nginx.exe") -v 2>&1
    Write-Output "[INFO] $nginxVersion"
    exit 0
}

Write-Output "[AUTO] Nginx not found. Downloading..."

$nginxUrl = "https://nginx.org/download/nginx-1.28.0.zip"
Write-Output "[INFO] Downloading from: $nginxUrl"

try {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    Invoke-WebRequest -Uri $nginxUrl -OutFile $NginxZip -UseBasicParsing
    Write-Output "[OK] Download complete"
} catch {
    Write-Output "[ERROR] Failed to download Nginx: $_"
    Write-Output "[INFO] Please download manually from: https://nginx.org/en/download.html"
    Write-Output "[INFO] Extract to: $NginxDir"
    exit 1
}

Write-Output "[INFO] Extracting Nginx..."

if (Test-Path $NginxDir) {
    Remove-Item -Path $NginxDir -Recurse -Force
}

Expand-Archive -Path $NginxZip -DestinationPath $env:TEMP -Force

$extractedDir = Get-ChildItem -Path $env:TEMP -Filter "nginx-*" -Directory | Select-Object -First 1
if ($extractedDir) {
    Move-Item -Path $extractedDir.FullName -Destination $NginxDir -Force
    Write-Output "[OK] Nginx extracted to: $NginxDir"
} else {
    Write-Output "[ERROR] Could not find extracted Nginx directory"
    exit 1
}

Remove-Item -Path $NginxZip -Force -ErrorAction SilentlyContinue

$nginxVersion = & (Join-Path $NginxDir "nginx.exe") -v 2>&1 | Out-String
Write-Output "[OK] Nginx installed"
Write-Output "[INFO] Config file: $ProjectRoot\server-deployment\nginx.conf"
