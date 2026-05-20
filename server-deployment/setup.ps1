# Strict mode
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# Configuration
$WorkspaceRoot = Split-Path -Parent $PSScriptRoot
$IsAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if ($IsAdmin) {
    $DeploymentRoot = "C:\Deployment\achme"
} else {
    $DeploymentRoot = Join-Path $WorkspaceRoot "Deployment\achme"
}

# Subdirectories list
$SubDirectories = @(
    "frontend",
    "backend",
    "ssl",
    "logs",
    "backups"
)

try {
    Write-Output "[INFO] Starting directory structure initialization..."
    Write-Output "[INFO] Deployment Root: $DeploymentRoot"
    
    # Ensure root directory exists
    if (-not (Test-Path -LiteralPath $DeploymentRoot)) {
        New-Item -ItemType Directory -Path $DeploymentRoot -Force | Out-Null
        Write-Output "[OK] Created root directory: $DeploymentRoot"
    } else {
        Write-Output "[INFO] Root directory already exists: $DeploymentRoot"
    }

    # Ensure all subdirectories exist
    foreach ($SubDir in $SubDirectories) {
        $FullPath = Join-Path -Path $DeploymentRoot -ChildPath $SubDir
        if (-not (Test-Path -LiteralPath $FullPath)) {
            New-Item -ItemType Directory -Path $FullPath -Force | Out-Null
            Write-Output "[OK] Created directory: $FullPath"
        } else {
            Write-Output "[INFO] Directory already exists: $FullPath"
        }
    }

    Write-Output "[OK] Directory structure initialization complete."
    exit 0
}
catch {
    Write-Output "[ERROR] Failed to initialize directory structure: $_"
    exit 1
}
