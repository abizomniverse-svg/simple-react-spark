# Windows Task Scheduler Auto-Start Setup
# Creates a scheduled task that launches the server on Windows boot

param(
    [switch]$Enable,
    [switch]$Disable
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$TaskName = "AchmeEnterpriseServer"
$WorkspaceRoot = Split-Path -Parent $PSScriptRoot
$StartScript = Join-Path $WorkspaceRoot "startserver.bat"

function Write-Status {
    param([string]$Message, [string]$Level = "INFO")
    $color = switch ($Level) {
        "OK" { "Green" }
        "WARN" { "Yellow" }
        "ERROR" { "Red" }
        default { "White" }
    }
    Write-Host "[$Level] $Message" -ForegroundColor $color
}

if ($Disable) {
    Write-Status "Disabling auto-start scheduled task..."
    
    try {
        Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false -ErrorAction SilentlyContinue
        Write-Status "Auto-start disabled successfully." "OK"
    } catch {
        Write-Status "Failed to disable auto-start: $_" "ERROR"
    }
    exit 0
}

if ($Enable) {
    Write-Status "Setting up Windows Task Scheduler auto-start..."
    
    # Check if task already exists
    $ExistingTask = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
    if ($ExistingTask) {
        Write-Status "Removing existing scheduled task..." "WARN"
        Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
    }
    
    # Create the scheduled task action
    $Action = New-ScheduledTaskAction `
        -Execute "cmd.exe" `
        -Argument "/c `"$StartScript`" >nul 2>&1" `
        -WorkingDirectory $WorkspaceRoot
    
    # Trigger: On system startup (with 30 second delay to let services initialize)
    $Trigger = New-ScheduledTaskTrigger `
        -AtStartup `
        -RandomDelay (New-TimeSpan -Minutes 1)
    
    # Settings: Run whether user is logged on or not, with highest privileges
    $Settings = New-ScheduledTaskSettingsSet `
        -AllowStartIfOnBatteries `
        -DontStopIfGoingOnBatteries `
        -StartWhenAvailable `
        -RestartCount 3 `
        -RestartInterval (New-TimeSpan -Minutes 5)
    
    # Register the task (requires admin)
    try {
        Register-ScheduledTask `
            -TaskName $TaskName `
            -Action $Action `
            -Trigger $Trigger `
            -Settings $Settings `
            -Description "Achme Enterprise Server - Auto-starts all services on Windows boot" `
            -RunLevel Highest `
            -User $env:USERNAME `
            -ErrorAction Stop
        
        Write-Status "Scheduled task '$TaskName' created successfully!" "OK"
        Write-Status "Server will auto-start 1 minute after Windows boots." "OK"
        Write-Status ""
        Write-Status "To verify: Open Task Scheduler -> Task Scheduler Library -> $TaskName" "OK"
    } catch {
        Write-Status "Failed to create scheduled task: $_" "ERROR"
        Write-Status "Please run startserver.bat as Administrator first." "WARN"
        exit 1
    }
    
    # Also create a Startup shortcut as fallback
    $StartupFolder = [System.IO.Path]::Combine($env:APPDATA, 'Microsoft\Windows\Start Menu\Programs\Startup')
    $ShortcutPath = Join-Path $StartupFolder "AchmeServerStartup.lnk"
    
    try {
        $WshShell = New-Object -ComObject WScript.Shell
        $Shortcut = $WshShell.CreateShortcut($ShortcutPath)
        $Shortcut.TargetPath = $StartScript
        $Shortcut.WorkingDirectory = $WorkspaceRoot
        $Shortcut.WindowStyle = 7  # Minimized
        $Shortcut.Description = "Achme Server Auto-Launch"
        $Shortcut.Save()
        Write-Status "Startup shortcut created as fallback." "OK"
    } catch {
        Write-Status "Could not create startup shortcut: $_" "WARN"
    }
    
    exit 0
}

# If no switch provided, show status
Write-Status "Usage:" "INFO"
Write-Status "  .\auto-start-scheduler.ps1 -Enable   (Enable auto-start)" "INFO"
Write-Status "  .\auto-start-scheduler.ps1 -Disable  (Disable auto-start)" "INFO"

# Check current status
$Task = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
if ($Task) {
    Write-Status "Auto-start is currently ENABLED." "OK"
    Write-Status "Task: $TaskName" "INFO"
    Write-Status "State: $($Task.State)" "INFO"
} else {
    Write-Status "Auto-start is currently DISABLED." "WARN"
}
