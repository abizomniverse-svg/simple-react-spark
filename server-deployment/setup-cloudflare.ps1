# Cloudflare Tunnel Auto-Setup Script
# Downloads cloudflared.exe and starts the tunnel with saved token

Set-StrictMode -Version Latest
$ErrorActionPreference = "Continue"

$WorkspaceRoot = Split-Path -Parent $PSScriptRoot

# Detect deployment root
$IsAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if ($IsAdmin) {
    $DeploymentRoot = "C:\Deployment\achme"
} else {
    $DeploymentRoot = Join-Path $WorkspaceRoot "Deployment\achme"
}

$CfTokenFile = Join-Path $WorkspaceRoot "cloudflared-token.txt"
$CfExePath = Join-Path $DeploymentRoot "cloudflared.exe"

Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "       ACHME CLOUDFLARE TUNNEL SETUP" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host ""

# Read token
if (-not (Test-Path -LiteralPath $CfTokenFile)) {
    Write-Host "[ERROR] No cloudflared-token.txt found." -ForegroundColor Red
    Write-Host "Please run startserver.bat and select option 3 first." -ForegroundColor Yellow
    pause
    exit 1
}

$CfToken = (Get-Content -Path $CfTokenFile -Raw).Trim()
if (-not $CfToken) {
    Write-Host "[ERROR] Token file is empty." -ForegroundColor Red
    pause
    exit 1
}

Write-Host "[OK] Token loaded from cloudflared-token.txt" -ForegroundColor Green

# Download cloudflared.exe if missing
if (-not (Test-Path -LiteralPath $CfExePath)) {
    Write-Host ""
    Write-Host "[INFO] Downloading cloudflared.exe..." -ForegroundColor Yellow
    
    # Create deployment directory if needed
    if (-not (Test-Path -LiteralPath $DeploymentRoot)) {
        New-Item -ItemType Directory -Path $DeploymentRoot -Force | Out-Null
    }
    
    try {
        $CfUrl = "https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-windows-amd64.exe"
        Invoke-WebRequest -Uri $CfUrl -OutFile $CfExePath -UseBasicParsing
        Write-Host "[OK] cloudflared.exe downloaded successfully." -ForegroundColor Green
    } catch {
        Write-Host "[ERROR] Failed to download cloudflared.exe: $_" -ForegroundColor Red
        Write-Host "Download manually from: https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/downloads/" -ForegroundColor Yellow
        Write-Host "Place it at: $CfExePath" -ForegroundColor Yellow
        pause
        exit 1
    }
} else {
    Write-Host "[OK] cloudflared.exe already exists." -ForegroundColor Green
}

Write-Host ""
Write-Host "[INFO] Starting Cloudflare Tunnel..." -ForegroundColor Cyan
Write-Host "[INFO] This window will show tunnel activity. Keep it open." -ForegroundColor Gray
Write-Host "[INFO] Press Ctrl+C to stop the tunnel." -ForegroundColor Gray
Write-Host ""
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host ""

# Start tunnel
& $CfExePath tunnel run --token $CfToken
