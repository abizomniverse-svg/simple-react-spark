# Strict mode
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# Configuration
$DbUser = "root"
$DbPass = "admin@123"
$DbName = "achme"
$WorkspaceRoot = Split-Path -Parent $PSScriptRoot
$IsAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if ($IsAdmin) {
    $DeploymentRoot = "C:\Deployment\achme"
} else {
    $DeploymentRoot = Join-Path $WorkspaceRoot "Deployment\achme"
}
$BackupDir = Join-Path $DeploymentRoot "backups"
$LogFile = Join-Path $DeploymentRoot "logs\backup.log"
$RetentionDays = 30 # Number of days to keep backups

# Scan standard MySQL installation paths to find mysqldump.exe automatically
$MySqlDumpPath = ""
$StandardPaths = @(
    "mysqldump.exe", # If in environment PATH
    "C:\Program Files\MySQL\MySQL Server 8.4\bin\mysqldump.exe",
    "C:\Program Files\MySQL\MySQL Server 8.3\bin\mysqldump.exe",
    "C:\Program Files\MySQL\MySQL Server 8.2\bin\mysqldump.exe",
    "C:\Program Files\MySQL\MySQL Server 8.1\bin\mysqldump.exe",
    "C:\Program Files\MySQL\MySQL Server 8.0\bin\mysqldump.exe",
    "C:\Program Files\MySQL\MySQL Server 5.7\bin\mysqldump.exe",
    "C:\xampp\mysql\bin\mysqldump.exe"
)

foreach ($Path in $StandardPaths) {
    if ($Path -eq "mysqldump.exe") {
        $Check = Get-Command "mysqldump.exe" -ErrorAction SilentlyContinue
        if ($Check) {
            $MySqlDumpPath = "mysqldump.exe"
            break
        }
    } elseif (Test-Path -LiteralPath $Path) {
        $MySqlDumpPath = $Path
        break
    }
}

# Helper to write to console and log file
function Write-Log {
    param (
        [string]$Message,
        [string]$Level = "INFO"
    )
    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $LogLine = "[$Timestamp] [$Level] $Message"
    Write-Output $LogLine
    
    # Append to log file
    try {
        $LogLine | Out-File -FilePath $LogFile -Append -Encoding ascii -ErrorAction SilentlyContinue
    } catch {}
}

try {
    Write-Log "========================================"
    Write-Log "Starting automated database backup for database: $DbName..."

    # Ensure backup directory exists
    if (-not (Test-Path -LiteralPath $BackupDir)) {
        New-Item -ItemType Directory -Path $BackupDir -Force | Out-Null
        Write-Log "Created backup directory: $BackupDir"
    }

    # Verify mysqldump was found
    if ($MySqlDumpPath -eq "") {
        throw "Could not locate mysqldump.exe on this system. Please configure MySQL binaries in environment PATH or edit script."
    }
    Write-Log "Using mysqldump executable from: $MySqlDumpPath"

    # Prepare file names
    $DateStr = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
    $SqlFile = Join-Path -Path $BackupDir -ChildPath "${DbName}_backup_${DateStr}.sql"
    $ZipFile = Join-Path -Path $BackupDir -ChildPath "${DbName}_backup_${DateStr}.zip"

    # Execute mysqldump
    Write-Log "Running mysqldump..."
    $DumpCommand = "& `"$MySqlDumpPath`" --host=127.0.0.1 --port=3306 --user=`"$DbUser`" --password=`"$DbPass`" `"$DbName`""
    
    # Run and direct output to file
    Invoke-Expression "$DumpCommand" | Out-File -FilePath $SqlFile -Encoding utf8
    
    if (-not (Test-Path -LiteralPath $SqlFile) -or (Get-Item $SqlFile).Length -lt 100) {
         throw "mysqldump failed to write content to the backup file. File is missing or too small."
    }
    Write-Log "Database dump created at: $SqlFile"

    # Compress SQL dump into ZIP natively to save disk space
    Write-Log "Compressing dump file into ZIP archive..."
    Compress-Archive -Path $SqlFile -DestinationPath $ZipFile -Force
    Write-Log "ZIP archive created at: $ZipFile"

    # Delete uncompressed SQL file for security and storage optimization
    Remove-Item -Path $SqlFile -Force
    Write-Log "Deleted uncompressed SQL file."

    # Backup rotation (Retention cleanup)
    Write-Log "Checking for old backups to rotate (Retention limit: $RetentionDays days)..."
    $CutoffDate = (Get-Date).AddDays(-$RetentionDays)
    
    # Get all backup zip files in backup directory
    $Backups = Get-ChildItem -Path $BackupDir -Filter "${DbName}_backup_*.zip"
    $DeletedCount = 0

    foreach ($File in $Backups) {
        if ($File.LastWriteTime -lt $CutoffDate) {
            Remove-Item -Path $File.FullName -Force
            Write-Log "Deleted expired backup file: $($File.Name)" "WARN"
            $DeletedCount++
        }
    }
    
    Write-Log "Backup rotation complete. Deleted $DeletedCount expired backups."
    Write-Log "Backup process completed successfully!" "SUCCESS"
    exit 0
}
catch {
    Write-Log "Backup failed: $_" "ERROR"
    exit 1
}
